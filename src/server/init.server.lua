local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkOwnershipPlus = require(ReplicatedStorage.NetworkOwnershipPlus)

local Enums = NetworkOwnershipPlus.Enums
local BenchmarkUtility = require(ReplicatedStorage.NetworkOwnershipPlus.Utility.Benchmark)
local CompressionUtility = NetworkOwnershipPlus.Compression
local CompressionTypes = CompressionUtility.CompressionTypes

do
    type Structure = {
        Identifier: number,
        Name: string,
        Health: number,
        Jumping: boolean,
        Position: Vector3,
    }

    local CompressionTable = CompressionUtility.CreateCompressionTable({
        CompressionTypes.UnsignedByte,
        CompressionTypes.String,
        CompressionTypes.UnsignedShort,
        CompressionTypes.Boolean,
        CompressionTypes.Vector
    }, {
        "Identifier",
        "Name",
        "Health",
        "Jumping",
        "Position",
    })  
    
    local Input = {
        CompressionUtility.Always(0),
        "Hello, World!",
        65535,
        true,
        Vector3.new(0, 0, 0),
    }

    local Stream = CompressionTable.Compress(Input)
    local Result: Structure = CompressionTable.Decompress(Stream)

    print(Result)
    print(`Identifier: {Result.Identifier}\nName: {Result.Name}\nHealth: {Result.Health}\nJumping: {Result.Jumping}\nPosition: {Result.Position}`)
    
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