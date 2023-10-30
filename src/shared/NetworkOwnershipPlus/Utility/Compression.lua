--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

local Package = script.Parent.Parent
local Enums = require(Package.Enums)

---- Settings ----

type BaseValues = number | Vector3
export type ValueWrapper = () -> (BaseValues)
export type SupportedValues = BaseValues & ValueWrapper

local TRUE = 0b1
local FALSE = 0b0
local NAN = 0/0
local NAN_VECTOR = Vector3.new(NAN, NAN, NAN)

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

function toBits(num,bits)
    -- returns a table of bits, most significant first.
    bits = bits or math.max(1, select(2, math.frexp(num)))
    local t = {} -- will contain the bits        
    for b = bits, 1, -1 do
        t[b] = math.fmod(num, 2)
        num = math.floor((num - t[b]) / 2)
    end
    return "0b" .. table.concat(t)
end

local function GetSubstituteType(Value: BaseValues): BaseValues
    return type(Value) == "number" and NAN or NAN_VECTOR
end

local function GetDeltaFormat(Size: number): string
    if Size <= 8 then
        return Enums.CompressionTypes.UnsignedByte
    elseif Size <= 16 then
        return Enums.CompressionTypes.UnsignedShort
    end
    
    return Enums.CompressionTypes.UnsignedInteger
end

---- Public Functions ----

function Utility.AlwaysSend(Value: SupportedValues): () -> (SupportedValues)
    return function()
        return Value
    end
end

function Utility.ReconcileWithDeltaTable(DeltaTable: {BaseValues}, BaseTable: {BaseValues})
    for Index, BaseValue in BaseTable do
        local DeltaValue = DeltaTable[Index]
        if type(BaseValue) == "number" then
            DeltaValue = DeltaValue ~= DeltaValue and BaseValue or DeltaValue
        elseif type(DeltaValue) == "vector" then
            if DeltaValue == BaseValue then
                DeltaValue = BaseValue
            elseif DeltaValue ~= DeltaValue then
                DeltaValue = Vector3.new(
                    DeltaValue.X ~= DeltaValue.X and BaseValue.X or DeltaValue.X,
                    DeltaValue.Y ~= DeltaValue.Y and BaseValue.Y or DeltaValue.Y,
                    DeltaValue.Z ~= DeltaValue.Z and BaseValue.Z or DeltaValue.Z
                ) 
            end
        end

        BaseTable[Index] = DeltaValue
    end
end

function Utility.CreateCompressionTable(Types: {string})
    local Format = table.concat(Types)
    local RawTypes = Types
    local DeltaFormat = GetDeltaFormat(#Format)
    local DeltaFormatOffset = (1 + string.packsize(DeltaFormat))
    Types = string.split(Format, "")

    return {
        Size = string.packsize(DeltaFormat .. Format),

        Compress = function(Values: {SupportedValues}, PreviousValues: {BaseValues}): (string, number)
            local Stream = ""
            local StreamFormat = ""
            local ChangedValues: {BaseValues} = table.create(#Values)

            --> Remove wrappers
            for Index, Value in Values do
                if type(Value) == "function" then
                    local Raw = Value()
                    Values[Index] = Raw
                    if PreviousValues then
                        PreviousValues[Index] = GetSubstituteType(Raw)
                    end 
                end
            end

            --> Create fake delta values
            if not PreviousValues then
                PreviousValues = table.create(#Values)
                for Index, Value in Values do
                    (PreviousValues :: any)[Index] = GetSubstituteType(Value)
                end
            end

            --> Delta compression
            local DeltaBits = 0
            local TypeCursor = 0
            local DeltaCursor = 0

            for Index, RawCurrent in Values do
                local Current: BaseValues = RawCurrent
                local Previous = PreviousValues[Index]
                local HasValueChanged = (Current ~= Previous)

                if type(Current) == "vector" then
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
                    local XBit = (Current.X ~= (Previous :: Vector3).X) and TRUE or FALSE
                    local YBit = (Current.Y ~= (Previous :: Vector3).Y) and TRUE or FALSE
                    local ZBit = (Current.Z ~= (Previous :: Vector3).Z) and TRUE or FALSE

                    VectorBits += bit32.lshift(XBit, 0)
                    VectorBits += bit32.lshift(YBit, 1)
                    VectorBits += bit32.lshift(ZBit, 2)

                    --> Insert changed axes
                    if XBit == TRUE then 
                        table.insert(ChangedValues, Current.X) 
                    end
                    
                    if YBit == TRUE then 
                        table.insert(ChangedValues, Current.Y) 
                    end

                    if ZBit == TRUE then 
                        table.insert(ChangedValues, Current.Z) 
                    end

                    --> Add to delta bits & update format
                    DeltaBits += bit32.lshift(VectorBits, DeltaCursor)
                    DeltaCursor += 3
                    StreamFormat ..= string.rep(Enums.CompressionTypes.Float, (XBit + YBit + ZBit))
                else
                    DeltaBits += bit32.lshift(HasValueChanged and TRUE or FALSE, DeltaCursor)
                    TypeCursor += 1
                    DeltaCursor += 1

                    if HasValueChanged then 
                        StreamFormat ..= Types[TypeCursor]
                        table.insert(ChangedValues, Current)
                    end
                end
            end

            --> Build stream
            Stream = string.pack(DeltaFormat .. StreamFormat, DeltaBits, table.unpack(ChangedValues))

            return Stream, string.packsize(DeltaFormat .. StreamFormat)
        end,

        Decompress = function(Stream: string): ({BaseValues}, number)
            local StreamFormat = ""

            local Values: {BaseValues} = table.create(#Types, NAN)
            local ValueIndices: {number} = {}
            local VectorIndices: {number} = {}
            
            --> Construct stream format from delta compressed portion
            local Offset = 0
            local StreamIndex = 0

            local DeltaBits = string.unpack(DeltaFormat, Stream)
            local DeltaCursor = 0

            for Index, Type in RawTypes do
                --> Add vector offsets
                local ValueIndex = Index + Offset

                if Type == Enums.CompressionTypes.Vector then
                    local XBit = bit32.extract(DeltaBits, DeltaCursor, 1)
                    local YBit = bit32.extract(DeltaBits, DeltaCursor + 1, 1)
                    local ZBit = bit32.extract(DeltaBits, DeltaCursor + 2, 1)
                    local Size = (XBit + YBit + ZBit)

                    --> Fill empty vector axes with null
                    if XBit == TRUE then
                        StreamIndex += 1
                        ValueIndices[StreamIndex] = ValueIndex
                    end

                    if YBit == TRUE then
                        StreamIndex += 1
                        ValueIndices[StreamIndex] = ValueIndex + 1
                    end                    

                    if ZBit == TRUE then
                        StreamIndex += 1
                        ValueIndices[StreamIndex] = ValueIndex + 2
                    end

                    Offset += 2
                    table.insert(VectorIndices, ValueIndex)
                    StreamFormat ..= string.rep(Enums.CompressionTypes.Float, Size)
                elseif bit32.extract(DeltaBits, DeltaCursor, 1) == TRUE then
                    StreamIndex += 1
                    StreamFormat ..= Type
                    ValueIndices[StreamIndex] = ValueIndex
                end

                DeltaCursor += #Type
            end

            --> Unpack the compressed stream, read with X bytes offset (first X bytes are used by the delta compression)
            local UnpackedValues = {string.unpack(StreamFormat, Stream, DeltaFormatOffset)}

            --> Remove the extra value returned by string.unpack
            UnpackedValues[#UnpackedValues] = nil

            for Index, Value in UnpackedValues do
                Values[ValueIndices[Index]] = Value
            end

            --> Reconstruct vectors
            for Index = #VectorIndices, 1, -1 do
                local ReadIndex = VectorIndices[Index]
                Values[ReadIndex] = Vector3.new(
                    Values[ReadIndex] :: number,
                    table.remove(Values, ReadIndex + 1) :: number,
                    table.remove(Values, ReadIndex + 1) :: number
                )          
            end

            return Values, string.packsize(DeltaFormat .. StreamFormat)
        end
    }
end

---- Initialization ----

---- Connections ----

return Utility
