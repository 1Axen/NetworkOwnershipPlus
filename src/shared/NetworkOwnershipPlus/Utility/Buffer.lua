--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

local Packages = script.Parent.Parent
local Utility = Packages.Utility

local CompressionUtility = require(Utility.Compression)

---- Settings ----

---- Constants ----

local Buffer = {}
local Types = CompressionUtility.Types

---- Variables ----

---- Private Functions ----

---- Public Functions ----

function Buffer.new(Stream: string?)
    local Cursor = 0
    local Stream = Stream or ""
    local BufferInstance = {}

    local Format = ""
    local Values: {number | string} = {}

    --> Read functions
    function BufferInstance.ReadByte(): number
        Cursor += 1
        return string.unpack(Types.Byte, Stream, Cursor)
    end

    function BufferInstance.ReadUnsignedByte(): number
        Cursor += 1
        return string.unpack(Types.UnsignedByte, Stream, Cursor)
    end

    function BufferInstance.ReadShort(): number
        Cursor += 1
        return string.unpack(Types.Short, Stream, Cursor)
    end

    function BufferInstance.ReadUnsignedShort(): number
        Cursor += 1
        return string.unpack(Types.UnsignedShort, Stream, Cursor)
    end

    function BufferInstance.ReadInteger(): number
        Cursor += 1
        return string.unpack(Types.Integer, Stream, Cursor)
    end

    function BufferInstance.ReadUnsignedInteger(): number
        Cursor += 1
        return string.unpack(Types.UnsignedInteger, Stream, Cursor)
    end

    function BufferInstance.ReadFloat(): number
        Cursor += 1
        return string.unpack(Types.Float, Stream, Cursor)
    end

    function BufferInstance.ReadDouble(): number
        Cursor += 1
        return string.unpack(Types.Double, Stream, Cursor)
    end

    function BufferInstance.ReadBytes(Bytes: number): number
        local Result = 0
        for Displacement = 0, (Bytes - 1) do
            local Byte = BufferInstance.ReadByte()
            Result += bit32.lshift(Byte, Displacement * 8)
        end

        return Result
    end

    function BufferInstance.ReadVector(): Vector3
        return Vector3.new(
            BufferInstance.ReadFloat(),
            BufferInstance.ReadFloat(),
            BufferInstance.ReadFloat()
        )
    end

    function BufferInstance.ReadString(Length: number): string
        Cursor += 1
        return string.unpack(`c{Length}`, Stream, Cursor)
    end

    --> Write functions
    local function WriteToFormat(Type: string, Value)
        Format ..= Type
        table.insert(Values, Value)
    end

    function BufferInstance.WriteByte(Value: number)
        WriteToFormat("b", Value)
    end

    function BufferInstance.WriteUnsignedByte(Value: number)
         WriteToFormat("B", Value)
    end

    function BufferInstance.WriteShort(Value: number)
        WriteToFormat("h", Value)
    end

    function BufferInstance.WriteUnsignedShort(Value: number)
        WriteToFormat("H", Value)
    end

    function BufferInstance.WriteInteger(Value: number)
        WriteToFormat("j", Value)
    end

    function BufferInstance.WriteUnsignedInteger(Value: number)
        WriteToFormat("J", Value)
    end

    function BufferInstance.WriteFloat(Value: number)
        WriteToFormat("f", Value)
    end

    function BufferInstance.WriteDouble(Value: number)
        WriteToFormat("d", Value)
    end

    function BufferInstance.WriteBytes(Value: number, Bytes: number)
        for Index = 0, (Bytes - 1) do
            local Byte = bit32.extract(Value, Index * 8, 8)
            BufferInstance.WriteByte(Byte)
        end
    end

    function BufferInstance.WriteVector(Vector: Vector3)
        BufferInstance.WriteFloat(Vector.X)
        BufferInstance.WriteFloat(Vector.Y)
        BufferInstance.WriteFloat(Vector.Z)
    end

    -- selene: allow(shadowing)
    function BufferInstance.WriteString(String: string, Length: number?)
        local Size = Length or string.len(String)
        WriteToFormat(`c{Size}`, String)
    end

    --> Export methods
    function BufferInstance.ToString(): string
        return string.pack(Format, table.unpack(Values))
    end

    return BufferInstance
end

---- Initialization ----

---- Connections ----

return Buffer