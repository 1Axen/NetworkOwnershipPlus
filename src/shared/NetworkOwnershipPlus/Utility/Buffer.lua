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

function Buffer.new(Stream: string)
    local Cursor = 0
    local BufferInstance = {}

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
    function BufferInstance.WriteByte(Value: number)
    
    end

    function BufferInstance.WriteUnsignedByte(Value: number)
         
    end

    function BufferInstance.WriteShort(Value: number)
        
    end

    function BufferInstance.WriteUnsignedShort(Value: number)
        
    end

    function BufferInstance.WriteInteger(Value: number)
        
    end

    function BufferInstance.WriteUnsignedInteger(Value: number)
        
    end

    function BufferInstance.WriteFloat(Value: number)
        
    end

    function BufferInstance.WriteDouble(Value: number)
        
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
        local Length = Length or string.len(String)
        
    end

    return BufferInstance
end

---- Initialization ----

---- Connections ----

return Buffer