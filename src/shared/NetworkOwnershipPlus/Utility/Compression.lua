--!strict
--!native
--!optimize 2

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

type BaseValues = number | Vector3 | boolean | string
type ValuesLayout = {[string]: BaseValues}
export type SupportedValuesLayout = {[string]: SupportedValues}

export type ValueWrapper = () -> (BaseValues)
export type SupportedValues = BaseValues & ValueWrapper
export type Packer = {
	Pack: (Values: SupportedValuesLayout, PreviousValues: SupportedValuesLayout?) -> buffer,
	Unpack: (Stream: buffer, Destination: ValuesLayout) -> ()
}

export type CompressionType = {
	Size: number,
	Basic: boolean,
}

local NAN = 0/0
local TRUE = 0b1
local FALSE = 0b0

local FLOAT = 4
local INTEGER = 4
local EPSILON = 1E-5

local STRING = string.rep(string.char(255), 16)
local INF_VECTOR = Vector3.one * math.huge

local COMPRESSION_TYPES = {
	Byte = {
		Size = 1,
		Basic = true,
	},

	UnsignedByte = {
		Size = 1,
		Basic = true,
	},

	Short = {
		Size = 2,
		Basic = true,
	},

	UnsignedShort = {
		Size = 2,
		Basic = true,
	},

	Integer = {
		Size = INTEGER,
		Basic = true,
	},

	UnsignedInteger = {
		Size = INTEGER,
		Basic = true,
	},

	Float = {
		Size = FLOAT,
		Basic = true,
	},

	Double = {
		Size = 8,
		Basic = true,
	},

	Vector = {
		Size = FLOAT * 3,
		Basic = false,
	},

	String = {
		Size = 0,
		Basic = true,
	},

	Boolean = {
		Size = 0,
		Basic = true,
	},
}

---- Constants ----

local Utility = {
	Types = COMPRESSION_TYPES
}

---- Variables ----

---- Private Functions ----

local function GetVLQSize(Length: number): number
	return math.ceil(math.log(Length + 1, 8))
end

local function GetSubstituteType(Value: BaseValues): BaseValues
	if type(Value) == "string" then
		return STRING
	elseif type(Value) == "boolean" then
		return not Value
	elseif type(Value) == "vector" then
		return INF_VECTOR
	end

	return NAN
end

local function WriteBitsToBuffer(Buffer: buffer, Offset: number, Bits: number, Count: number)
	--> Fast path: only writing 1 byte
	if Count == 1 then
		buffer.writeu8(Buffer, Offset, Bits)
		return
	end

	for Byte = 0, (Count - 1) do
		local Value = bit32.extract(Bits, Byte * 8, 8)
		buffer.writeu8(Buffer, Offset + Byte, Value)
	end
end

local function ReadBitsFromBuffer(Buffer: buffer, Offset: number, Count: number): number
	--> Fast path: only reading 1 byte
	if Count == 1 then
		return buffer.readu8(Buffer, Offset)
	end

	local Bits = 0
	for Cursor = 0, (Count - 1) do
		local Value = buffer.readu8(Buffer, Offset + Cursor)
		Bits += bit32.lshift(Value, Cursor * 8) 
	end

	return Bits
end

---- Public Functions ----

function Utility.Always(Value: BaseValues): () -> (BaseValues)
	return function()
		return Value
	end
end

function Utility.new(Layout: {[string]: CompressionType})--: Packer
	--> Validation
	do
		local Total = 0
		local Keys: {[string]: boolean} = {}

		for Key, Value in Layout do
			assert(type(Key) == "string", "Layout can only have string keys.")
			assert(type(Value) == "table", "Layout can only have compression type values.")
			assert(Keys[Key] == nil, "Layout cannot have duplicate keys.")

			Total += 1
			Keys[Key] = true
		end

		assert(Total > 0, "Layout cannot be empty.")
		assert(Total <= 53, "Packer cannot pack more than 53 types, consider using multiple packers.")
	end

	--> Convert dictionary to array
	local Keys: {string} = {}
	local Types: {CompressionType} = {}
	local Indices: {[string]: number} = {}

	for Key in Layout do
		table.insert(Keys, Key)
	end

	table.sort(Keys, function(A, B)
		return #A < #B
	end)

	for Index, Key in Keys do
		Indices[Key] = Index
		table.insert(Types, Layout[Key])
	end

	--> Booleans & strings
	local Booleans: {number} = {}
	for Index, Type in Types do
		if Type == COMPRESSION_TYPES.Boolean then
			table.insert(Booleans, Index)
		end
	end

	--> Buffer size calculation
	local DeltaBytes = GetVLQSize(#Keys)
	local BooleanBytes = GetVLQSize(#Booleans) 

	local Bytes = (DeltaBytes + BooleanBytes)
	for _, Type in Types do
		Bytes += Type.Size
	end

	--> Buffer (reuse)
	local InternalBuffer = buffer.create(900)

	return {
		Pack = function(Input: SupportedValuesLayout, PreviousInput: SupportedValuesLayout?): buffer
			local Values: {BaseValues} = table.create(#Keys)
			local PreviousValues: {BaseValues} = table.create(#Keys)

			--> Convert dictionary to array
			for Key, Value in Input do
				local Index = Indices[Key]

				--> Unknown key, alert the user!
				if not Index then
					error(`Unknown key "{Key}" in dictionary passed to Packer.Pack!\n{debug.traceback()}`)
				end

				local BaseValue = type(Value) == "function" and Value() or Value
				local BasePreviousValue = PreviousInput and PreviousInput[Key] or GetSubstituteType(BaseValue)

				if type(BasePreviousValue) == "function" then
					BasePreviousValue = GetSubstituteType(BasePreviousValue())
				end

				Values[Index] = BaseValue
				PreviousValues[Index] = BasePreviousValue
			end

			--> Compression
			local DeltaBits = 0
			local BooleanBits = 0

			local TypeCursor = DeltaBytes --> Offset type cursor by delta bytes
			local DeltaCursor = 0
			local BooleanCursor = 0

			--> Main logic
			for Index, Value in Values do
				local Type = Types[Index]
				local Previous = PreviousValues[Index]
				local HasValueChanged = (Value ~= Previous)

				if type(Value) ~= type(Previous) then
					error(`Value type mismatch during compression at #{Index}, {type(Value)} is not {type(Previous)}.`)
				end

				if HasValueChanged then
					--> Write values to buffer if they changed
					if Type == COMPRESSION_TYPES.Byte then
						buffer.writei8(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.UnsignedByte then
						buffer.writeu8(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.Short then
						buffer.writei16(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.UnsignedShort then
						buffer.writeu16(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.Integer then
						buffer.writei32(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.UnsignedInteger then
						buffer.writeu32(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.Float then
						buffer.writef32(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.Double then
						buffer.writef64(InternalBuffer, TypeCursor, Value :: number)
					elseif Type == COMPRESSION_TYPES.Vector then
						--> Bit pack vector axis delta
						local Vector = Value :: Vector3
						local PreviousVector = Previous :: Vector3

						local XBit = (math.abs(Vector.X - PreviousVector.X) > EPSILON) and TRUE or FALSE
						local YBit = (math.abs(Vector.Y - PreviousVector.Y) > EPSILON) and TRUE or FALSE
						local ZBit = (math.abs(Vector.Z - PreviousVector.Z) > EPSILON) and TRUE or FALSE
						local AxisBits = (bit32.lshift(XBit, 0) + bit32.lshift(YBit, 1) + bit32.lshift(ZBit, 2))

						--> Insert changed axes
						if XBit == TRUE then 
							buffer.writef32(InternalBuffer, TypeCursor, Vector.X)
							TypeCursor += FLOAT
						end

						if YBit == TRUE then 
							buffer.writef32(InternalBuffer, TypeCursor, Vector.Y)
							TypeCursor += FLOAT
						end

						if ZBit == TRUE then 
							buffer.writef32(InternalBuffer, TypeCursor, Vector.Z)
							TypeCursor += FLOAT
						end

						--> Update delta bits
						DeltaBits += bit32.lshift(AxisBits, DeltaCursor)
						DeltaCursor += 3
					elseif Type == COMPRESSION_TYPES.Boolean then
						BooleanBits += bit32.lshift(Value and TRUE or FALSE, BooleanCursor)
						BooleanCursor += 1
					elseif Type == COMPRESSION_TYPES.String then
						local String = Value :: string
						local Length = #String

						--> Write string to buffer ([u32 Length][string String])
						buffer.writeu32(InternalBuffer, TypeCursor, Length)
						buffer.writestring(InternalBuffer, TypeCursor + INTEGER, String, Length)
						TypeCursor += (INTEGER + Length)
					end

					--> Offset type cursor for basic values
					if Type.Basic then
						TypeCursor += Type.Size
					end
				else
					if Type == COMPRESSION_TYPES.Vector then
						DeltaBits += bit32.lshift(0b000, DeltaCursor)
						DeltaCursor += 3
					end
				end

				--> Update delta of basic values
				if Type.Basic then
					DeltaBits += bit32.lshift(HasValueChanged and TRUE or FALSE, DeltaCursor)
					DeltaCursor += 1
				end
			end

			--> Write delta bits
			WriteBitsToBuffer(InternalBuffer, 0, DeltaBits, DeltaBytes)

			--> Write booleans
			local BooleansSize = GetVLQSize(BooleanCursor)
			if BooleanCursor ~= 0 then
				WriteBitsToBuffer(InternalBuffer, TypeCursor, BooleanBits, BooleansSize)
			end

			--> Create buffer of exact size
			local Size = (TypeCursor + BooleansSize)
			local Buffer = buffer.create(Size)

			--> Move internal buffer contents to result buffer & clear used bytes from internal buffer
			buffer.copy(Buffer, 0, InternalBuffer, 0, Size)
			buffer.fill(InternalBuffer, 0, 0, Size)

			return Buffer
		end,

		Unpack = function(Stream: buffer, Destination: ValuesLayout)
			local Values: {BaseValues} = table.create(#Types, NAN)
			local Booleans: {number} = {}

			--> Extract delta bits
			local Deltas: {number} = {}

			do
				--> Extract bits from buffer
				local Cursor = 0
				local Bits = ReadBitsFromBuffer(Stream, 0, DeltaBytes)

				--> Convert bits to array
				for Index, Type in Types do
					if Type == COMPRESSION_TYPES.Vector then
						Deltas[Index] = bit32.extract(Bits, Cursor, 3)
						Cursor += 3
					end

					if Type.Basic then
						Deltas[Index] = bit32.extract(Bits, Cursor, 1)
						Cursor += 1
					end
				end
			end

			--> Cursors
			local TypeCursor = DeltaBytes

			--> Extract values
			for Index, Type in Types do
				local Value: BaseValues;
				local Delta = Deltas[Index]

				--> Skip over unchanged values
				if Delta == FALSE then
					continue
				end

				if Type == COMPRESSION_TYPES.Boolean then
					table.insert(Booleans, Index)
					continue
				elseif Type == COMPRESSION_TYPES.Byte then
					Value = buffer.readi8(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.UnsignedByte then
					Value = buffer.readu8(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.Short then
					Value = buffer.readi16(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.UnsignedShort then
					Value = buffer.readu16(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.Integer then
					Value = buffer.readi32(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.UnsignedInteger then
					Value = buffer.readu32(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.Float then
					Value = buffer.readf32(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.Double then
					Value = buffer.readf64(Stream, TypeCursor)
				elseif Type == COMPRESSION_TYPES.Vector then
					local XBit = bit32.extract(Delta, 0, 1)
					local YBit = bit32.extract(Delta, 1, 1)
					local ZBit = bit32.extract(Delta, 2, 1)

					--> Fill empty vector axes with null
					local X, Y, Z = NAN, NAN, NAN

					--> Read vector axes
					if XBit == TRUE then
						X = buffer.readf32(Stream, TypeCursor)
						TypeCursor += FLOAT
					end

					if YBit == TRUE then
						Y = buffer.readf32(Stream, TypeCursor)
						TypeCursor += FLOAT
					end                    

					if ZBit == TRUE then
						Z = buffer.readf32(Stream, TypeCursor)
						TypeCursor += FLOAT
					end

					Value = Vector3.new(X, Y, Z)
				elseif Type == COMPRESSION_TYPES.String then
					local Length = buffer.readu32(Stream, TypeCursor)
					Value = buffer.readstring(Stream, TypeCursor + INTEGER, Length)
					TypeCursor += (INTEGER + Length)
				end

				if Type.Basic then
					TypeCursor += Type.Size
				end

				Values[Index] = Value
			end

			--> Extract booleans
			if #Booleans ~= 0 then
				--> Extract bits from buffer
				local Bits = ReadBitsFromBuffer(Stream, TypeCursor, GetVLQSize(#Booleans))
				for Index, ValuesIndex in Booleans do
					Values[ValuesIndex] = (bit32.extract(Bits, Index - 1, 1) == TRUE)
				end 
			end		

			--> Reconcile with destination
			for Index, Key in Keys do
				local Value = Values[Index]
				local Previous: any = Destination[Key]

				--> If key doesn't exist then just use latest value
				if not Previous then
					Destination[Key] = Value
					continue
				end

				--> Skip unchanged values
				if Value == Previous then
					continue
				end

				if type(Value) == "vector" then
					Value = Vector3.new(
						Value.X ~= Value.X and Previous.X or Value.X,
						Value.Y ~= Value.Y and Previous.Y or Value.Y,
						Value.Z ~= Value.Z and Previous.Z or Value.Z
					)
				else
					Value = if Value ~= Value then Previous else Value
				end

				Destination[Key] = Value
			end
		end
	}
end

---- Initialization ----

---- Connections ----

return Utility
