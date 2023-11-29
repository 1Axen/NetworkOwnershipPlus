--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

local Math = require(script.Parent.Math)

---- Settings ----

type BaseValues = number | Vector3 | boolean | string
type ValuesLayout = {[string]: BaseValues}
export type SupportedValuesLayout = {[string]: SupportedValues}

export type ValueWrapper = () -> (BaseValues)
export type SupportedValues = BaseValues & ValueWrapper
export type CompressionTable = {
    Size: number,
    Compress: (Values: SupportedValuesLayout, DeltaValues: SupportedValuesLayout?) -> string,
    Decompress: (Stream: string) -> (ValuesLayout)
}

local TRUE = 0b1
local FALSE = 0b0
local NAN = 0/0
local INF_VECTOR = Vector3.one * math.huge
local STRING = string.rep(string.char(255), 16)

local COMPRESSION_TYPES = {
    Byte = "b",
    Float = "f",
    Short = "h",
    Double = "d",
    Number = "n",
    Vector = "fff",
    String = "z",
    Integer = "j",
    Boolean = "P",
    UnsignedByte = "B",
    UnsignedShort = "H",
    UnsignedInteger = "J"
}

local VARIABLE_SIZE_INTEGER = "I%d"

local UNFORMATTABLE_TYPES = {
    COMPRESSION_TYPES.String,
    COMPRESSION_TYPES.Boolean,
}

---- Constants ----

local Utility = {
    Types = COMPRESSION_TYPES
}

---- Variables ----

---- Private Functions ----

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

local function GetVariableLengthFormat(Size: number): string
    if Size == 0 then
        return ""
    end

    local Bytes = math.ceil(Size / 8)
    return string.format(VARIABLE_SIZE_INTEGER, Bytes)
end

---- Public Functions ----

function Utility.Always(Value: BaseValues): () -> (BaseValues)
    return function()
        return Value
    end
end

function Utility.ReconcileWithDeltaTable(DeltaTable: {BaseValues}, BaseTable: {BaseValues})
    for Index, BaseValue in BaseTable do
        local DeltaValue = DeltaTable[Index]
        if type(DeltaValue) == "vector" then
            --> Annoying type casting
            local BaseValue: Vector3 = BaseValue :: Vector3

            if DeltaValue == BaseValue then
                DeltaValue = BaseValue
            elseif DeltaValue ~= DeltaValue then
                DeltaValue = Vector3.new(
                    DeltaValue.X ~= DeltaValue.X and BaseValue.X or DeltaValue.X,
                    DeltaValue.Y ~= DeltaValue.Y and BaseValue.Y or DeltaValue.Y,
                    DeltaValue.Z ~= DeltaValue.Z and BaseValue.Z or DeltaValue.Z
                ) 
            end
        else
            DeltaValue = if DeltaValue ~= DeltaValue then BaseValue else DeltaValue
        end

        BaseTable[Index] = DeltaValue
    end
end

function Utility.CreateCompressionTable(Layout: {[string]: string}): CompressionTable
    --> Validation
    do
        local Keys: {[string]: boolean} = {}
        for Key, Value in Layout do
            assert(type(Key) == "string", "Layout can only have string keys.")
            assert(type(Value) == "string", "Layout can only have string values.")
            --assert(COMPRESSION_TYPES[Value] ~= nil, "Value is not a recognized compression type.")

            if Keys[Key] then
                error("Dictionary has duplicate keys!")
            end

            Keys[Key] = true
        end
    end

    --> Convert dictionary to array
    local Keys = {}
    local Values = {}
    local Indices = {}

    for Key in Layout do
        table.insert(Keys, Key)
    end

    table.sort(Keys, function(A, B)
        return #A < #B
    end)

    for Index, Key in Keys do
        Indices[Key] = Index
        Values[Index] = Layout[Key]
    end

    --> Packing
    local Format = table.concat(Values)
    local Types: {string} = string.split(Format, "")

    --> Delta compression format & read offset
    local DeltaFormat = GetVariableLengthFormat(#Format)
    local DeltaFormatOffset = (1 + string.packsize(DeltaFormat))

    --> Boolean values format & read offset
    local Booleans: {number} = {}
    for Index, Type in Types do
        if Type == COMPRESSION_TYPES.Boolean then
            table.insert(Booleans, Index)
        end
    end

    --> Remove unformattable types
    for _, Type in UNFORMATTABLE_TYPES do
        Format = string.gsub(Format, Type, "")    
    end

    return {
        Size = string.packsize(DeltaFormat .. GetVariableLengthFormat(#Booleans) .. Format),

        Compress = function(Input: SupportedValuesLayout, PreviousInput: SupportedValuesLayout?): (string)
            local Stream = ""
            local StreamFormat = ""

            local NewValues: {BaseValues} = table.create(#Keys)
            local ChangedValues: {BaseValues} = table.create(#Keys)
            local PreviousValues: {BaseValues} = table.create(#Keys)

            --> Convert dictionary to array
            for Key, Value in Input do
                local Index = Indices[Key]

                --> Unknown key, alert the user!
                if not Index then
                    warn(`Unknown key "{Key}" in dictionary passed to CompressionTable.Compress!\n{debug.traceback()}`)
                    continue
                end

                local BaseValue = type(Value) == "function" and Value() or Value
                local BasePreviousValue = PreviousInput and PreviousInput[Key] or GetSubstituteType(BaseValue)
                
                if type(BasePreviousValue) == "function" then
                    BasePreviousValue = GetSubstituteType(BasePreviousValue())
                end

                NewValues[Index] = BaseValue
                PreviousValues[Index] = BasePreviousValue
            end

            --> Compression
            local DeltaBits = 0
            local BooleanBits = 0

            local TypeCursor = 0
            local DeltaCursor = 0
            local BooleanCursor = 0

            for Index, New in NewValues do
                local Previous = PreviousValues[Index]
                local HasValueChanged = (New ~= Previous)

                if type(New) ~= type(Previous) then
                    error(`Value type mismatch during compression at #{Index}, {type(New)} is not {type(Previous)}`)
                end

                if type(New) == "vector" then
                    --> Move type cursor 3 places forward since a vector is 3 floats
                    TypeCursor += 3

                    --> Avoid checking all axes if the vector didn't change
                    if not HasValueChanged then
                        DeltaBits += bit32.lshift(0b000, DeltaCursor)
                        DeltaCursor += 3
                        continue
                    end

                    --> Bit pack vector axis delta
                    local VectorBits = 0

                    local XBit = (math.abs(New.X - (Previous :: Vector3).X) > Math.EPSILON) and TRUE or FALSE
                    local YBit = (math.abs(New.Y - (Previous :: Vector3).Y) > Math.EPSILON) and TRUE or FALSE
                    local ZBit = (math.abs(New.Z - (Previous :: Vector3).Z) > Math.EPSILON) and TRUE or FALSE

                    VectorBits += bit32.lshift(XBit, 0)
                    VectorBits += bit32.lshift(YBit, 1)
                    VectorBits += bit32.lshift(ZBit, 2)

                    --> Insert changed axes
                    if XBit == TRUE then 
                        table.insert(ChangedValues, New.X) 
                    end
                    
                    if YBit == TRUE then 
                        table.insert(ChangedValues, New.Y) 
                    end

                    if ZBit == TRUE then 
                        table.insert(ChangedValues, New.Z) 
                    end

                    --> Add to delta bits & update format
                    DeltaBits += bit32.lshift(VectorBits, DeltaCursor)
                    DeltaCursor += 3
                    StreamFormat ..= string.rep(COMPRESSION_TYPES.Float, (XBit + YBit + ZBit))
                else
                    DeltaBits += bit32.lshift(HasValueChanged and TRUE or FALSE, DeltaCursor)
                    TypeCursor += 1
                    DeltaCursor += 1

                    if not HasValueChanged then 
                        continue
                    end

                    if type(New) == "boolean" then
                        BooleanBits += bit32.lshift(New and TRUE or FALSE, BooleanCursor)
                        BooleanCursor += 1
                    else
                        table.insert(ChangedValues, New)
                        StreamFormat ..= Types[TypeCursor]
                    end
                end
            end

            --> Build stream
            if BooleanCursor > 0 then
                StreamFormat = (DeltaFormat .. GetVariableLengthFormat(BooleanCursor) .. StreamFormat)
                Stream = string.pack(StreamFormat, DeltaBits, BooleanBits, table.unpack(ChangedValues))
            else
                StreamFormat = DeltaFormat .. StreamFormat
                Stream = string.pack(StreamFormat, DeltaBits, table.unpack(ChangedValues))
            end

            return Stream
        end,

        Decompress = function(Stream: string): (ValuesLayout)
            local StreamFormat = ""
            local BooleanFormat = ""
            local BooleanFormatOffset = 0

            local NewValues: {BaseValues} = table.create(#Types, NAN)
            local ValueIndices: {number} = {}
            local VectorIndices: {number} = {}
            local BooleanIndices: {number} = {}
            
            --> Construct stream format from delta compressed portion
            local Offset = 0
            
            local DeltaBits = string.unpack(DeltaFormat, Stream)
            local DeltaCursor = 0

            for Index, Type in Values do
                --> Add vector offsets
                local ValueIndex = Index + Offset

                if Type == COMPRESSION_TYPES.Vector then
                    local XBit = bit32.extract(DeltaBits, DeltaCursor, 1)
                    local YBit = bit32.extract(DeltaBits, DeltaCursor + 1, 1)
                    local ZBit = bit32.extract(DeltaBits, DeltaCursor + 2, 1)
                    local Size = (XBit + YBit + ZBit)

                    --> Fill empty vector axes with null
                    if XBit == TRUE then
                        table.insert(ValueIndices, ValueIndex)
                    end

                    if YBit == TRUE then
                        table.insert(ValueIndices, ValueIndex + 1)
                    end                    

                    if ZBit == TRUE then
                        table.insert(ValueIndices, ValueIndex + 2)
                    end

                    Offset += 2
                    table.insert(VectorIndices, ValueIndex)
                    StreamFormat ..= string.rep(COMPRESSION_TYPES.Float, Size)
                elseif bit32.extract(DeltaBits, DeltaCursor, 1) == TRUE then
                    if Type == COMPRESSION_TYPES.Boolean then
                        table.insert(BooleanIndices, ValueIndex)
                    else
                        StreamFormat ..= Type
                        table.insert(ValueIndices, ValueIndex)
                    end
                end

                DeltaCursor += #Type
            end

            --> Offset stream unpack if booleans were packed
            if #BooleanIndices > 0 then
                BooleanFormat = GetVariableLengthFormat(#BooleanIndices)
                BooleanFormatOffset = string.packsize(BooleanFormat)
            end

            --> Unpack the compressed stream, read with X bytes offset (first X bytes are used by the delta compression, the next X are used for booleans)
            local UnpackedValues = {string.unpack(StreamFormat, Stream, DeltaFormatOffset + BooleanFormatOffset)}

            --> Remove the extra value returned by string.unpack
            UnpackedValues[#UnpackedValues] = nil
        
            --> Fill values with unpacked values
            for Index, Value in UnpackedValues do
                NewValues[ValueIndices[Index]] = Value
            end

            --> Fill values with booleans
            if #BooleanIndices > 0 then
                local BooleanBits = string.unpack(BooleanFormat, Stream, DeltaFormatOffset)
                for Index, ValuesIndex in BooleanIndices do
                    local Boolean = bit32.extract(BooleanBits, Index - 1, 1)
                    NewValues[ValuesIndex] = (Boolean == TRUE)
                end
            end

            --> Reconstruct vectors
            for Index = #VectorIndices, 1, -1 do
                local ReadIndex = VectorIndices[Index]
                NewValues[ReadIndex] = Vector3.new(
                    NewValues[ReadIndex] :: number,
                    table.remove(NewValues :: {BaseValues}, ReadIndex + 1) :: number,
                    table.remove(NewValues :: {BaseValues}, ReadIndex + 1) :: number
                )          
            end

            --> Reconstruct dictionary
            local Dictionary: {[string]: BaseValues} = {}
            for Index, Key in Keys do
                Dictionary[Key] = NewValues[Index]
            end
            
            return Dictionary
        end
    }
end

---- Initialization ----

---- Connections ----

return Utility
