--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

type BaseValues = number | Vector3 | boolean | string
export type ValueWrapper = () -> (BaseValues)
export type SupportedValues = BaseValues & ValueWrapper

local TRUE = 0b1
local FALSE = 0b0
local NAN = 0/0
local NAN_VECTOR = Vector3.new(NAN, NAN, NAN)
local EMPTY_STRING = ""

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

local UNFORMATTABLE_TYPES = {
    COMPRESSION_TYPES.String,
    COMPRESSION_TYPES.Boolean,
}

---- Constants ----

local Utility = {
    CompressionTypes = COMPRESSION_TYPES
}

---- Variables ----

---- Private Functions ----

local function GetSubstituteType(Value: BaseValues): BaseValues
    return type(Value) == "number" and NAN or NAN_VECTOR
end

local function GetVariableLengthFormat(Size: number): string
    if Size == 0 then
        return EMPTY_STRING
    elseif Size <= 8 then
        return COMPRESSION_TYPES.UnsignedByte
    elseif Size <= 16 then
        return COMPRESSION_TYPES.UnsignedShort
    end
    
    return COMPRESSION_TYPES.UnsignedInteger
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

function Utility.CreateCompressionTable(Types: {string}, Dictionary: {string}?)
    --> Validation
    if #Types == 0 then
        error("Types is empty!")
    end

    if Dictionary then
        if #Types ~= #Dictionary then
            error("Types and Dictionary have to be the same length!")
        end
        
        local Keys: {[string]: boolean} = {}
        for _, Key in Dictionary do
            if type(Key) ~= "string" then
                error("Dicitonary can only contain strings!")
            end

            if Keys[Key] then
                error("Dictionary has duplicate keys!")
            end

            Keys[Key] = true
        end
    end

    --> Constant state
    local DictionaryToIndex: {[string]: number} = {}
    if Dictionary then
        for Index, Key in Dictionary do
            DictionaryToIndex[Key] = Index
        end
    end
    
    local Format = table.concat(Types)
    local RawTypes: {string} = Types
    Types = string.split(Format, "")

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

        Compress = function(Values: {[string | number]: SupportedValues}, PreviousValues: {[string | number]: BaseValues}): (string)
            local Stream = ""
            local StreamFormat = ""
            local ChangedValues: {BaseValues} = table.create(#Values)

                        --> Convert to array if it's a dictionary
            --> NOTE: You can pass either an array or dictionary and as long as they have the same layout they should work
            if Dictionary and (#Values == 0) then
                --> Avoid mutating user input                
                local ValuesArray = table.create(#Dictionary)
                local PreviousValuesArray = PreviousValues and table.create(#Dictionary)

                --> Change keys to indexes
                for Key, Value in Values :: {[string]: SupportedValues} do
                    local Index = DictionaryToIndex[Key]

                    --> Unknown key, alert the user!
                    if not Index then
                        warn(`Unknown key "{Key}" in dictionary passed to CompressionTable.Compress!`)
                        continue
                    end

                    ValuesArray[Index] = Value

                    --> Also convert previous values dictionary
                    if PreviousValuesArray then
                        PreviousValuesArray[Index] = PreviousValues[Key]
                    end
                end

                Values = ValuesArray
                PreviousValues = PreviousValuesArray
            end

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

            --> Compression
            local DeltaBits = 0
            local BooleanBits = 0

            local TypeCursor = 0
            local DeltaCursor = 0
            local BooleanCursor = 0

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
                    StreamFormat ..= string.rep(COMPRESSION_TYPES.Float, (XBit + YBit + ZBit))
                else
                    DeltaBits += bit32.lshift(HasValueChanged and TRUE or FALSE, DeltaCursor)
                    TypeCursor += 1
                    DeltaCursor += 1

                    if HasValueChanged then 
                        --> Boolean compression
                        if type(Current) == "boolean" then
                            BooleanBits += bit32.lshift(Current and TRUE or FALSE, BooleanCursor)
                            BooleanCursor += 1
                        --> Standard value compression
                        else
                            StreamFormat ..= Types[TypeCursor]
                            table.insert(ChangedValues, Current)
                        end
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

        Decompress = function(Stream: string): ({[string | number]: BaseValues})
            local StreamFormat = ""
            local BooleanFormat = ""
            local BooleanFormatOffset = 0

            local Values: {[string | number]: BaseValues} = table.create(#Types, NAN)
            local ValueIndices: {number} = {}
            local VectorIndices: {number} = {}
            local BooleanIndices: {number} = {}
            
            --> Construct stream format from delta compressed portion
            local Offset = 0
            
            local DeltaBits = string.unpack(DeltaFormat, Stream)
            local DeltaCursor = 0

            for Index, Type in RawTypes do
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
                Values[ValueIndices[Index]] = Value
            end

            --> Fill values with booleans
            if #BooleanIndices > 0 then
                local BooleanBits = string.unpack(BooleanFormat, Stream, DeltaFormatOffset)
                for Index, ValuesIndex in BooleanIndices do
                    local Boolean = bit32.extract(BooleanBits, Index - 1, 1)
                    Values[ValuesIndex] = (Boolean == TRUE)
                end
            end

            --> Reconstruct vectors
            for Index = #VectorIndices, 1, -1 do
                local ReadIndex = VectorIndices[Index]
                Values[ReadIndex] = Vector3.new(
                    Values[ReadIndex] :: number,
                    table.remove(Values :: {BaseValues}, ReadIndex + 1) :: number,
                    table.remove(Values :: {BaseValues}, ReadIndex + 1) :: number
                )          
            end

            --> Reconstruct dictionary if it exists
            if Dictionary then
                for Index, Key in Dictionary do
                    Values[Key] = Values[Index]
                    Values[Index] = nil
                end
            end
            
            return Values
        end
    }
end

---- Initialization ----

---- Connections ----

return Utility
