local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkOwnershipPlus = require(ReplicatedStorage.NetworkOwnershipPlus)

local Enums = NetworkOwnershipPlus.Enums
local Benchmark = require(ReplicatedStorage.NetworkOwnershipPlus.Utility.Benchmark)
local Compression = NetworkOwnershipPlus.Compression
local Types = Compression.Types

do
    type Structure = {
        Identifier: number,
        Name: string,
        Health: number,
        Jumping: boolean,
        Position: Vector3,
    }

    local CompressionTable = Compression.CreateCompressionTable({
        Identifier = Types.UnsignedByte,
        Name = Types.String,
        Health = Types.UnsignedShort,
        Jumping = Types.Boolean,
        Position = Types.Vector
    })  
    
    local Input = {
        Identifier = Compression.Always(0),
        Name = "Hello, World!",
        Health = 65535,
        Jumping = false,
        Position = Vector3.new(0, 0, 0),
    }

    local LastInput = table.clone(Input)

    local Stream = CompressionTable.Compress(Input)
    print(CompressionTable.Decompress(Stream))

    Input.Health = 0
    Input.Jumping = true
    Input.Position = Vector3.yAxis

    Stream = CompressionTable.Compress(Input, LastInput)
    local Decompress = CompressionTable.Decompress(Stream)
    Compression.ReconcileWithDeltaTable(Decompress, LastInput)
    print(LastInput)
    
    --[[BenchmarkUtility.Benchmark("Compression", 10_000, function()
        CharacterCompressionTable.Compress(Input)
    end)
    
    BenchmarkUtility.Benchmark("Compress 100", 10_000, function()
        for _ = 1, 100 do
            CharacterCompressionTable.Compress(Input)
        end
    end)

    local Stream = CharacterCompressionTable.Compress(Input)
    BenchmarkUtility.Benchmark("Decompression", 10_000, function()
        CharacterCompressionTable.Decompress(Stream)
    end)]]
end