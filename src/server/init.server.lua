local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkOwnershipPlus = require(ReplicatedStorage.NetworkOwnershipPlus)

local Character = ReplicatedStorage.Character:Clone()
local Humanoid: Humanoid = Character.Humanoid
local RootPart: BasePart = Character.HumanoidRootPart
Character.Parent = workspace.CurrentCamera

local Enums = NetworkOwnershipPlus.Enums
local CompressionUtility = NetworkOwnershipPlus.Compression

local CharacterCompressionTable = CompressionUtility.CreateCompressionTable({
    Enums.CompressionTypes.UnsignedByte, --> Identifier [0-255]
    Enums.CompressionTypes.UnsignedShort, --> Health [0-65535]
    Enums.CompressionTypes.Vector, --> Position
    Enums.CompressionTypes.Vector, --> Rotation
    Enums.CompressionTypes.Vector, --> Velocity
})

local RandomNumberGenerator = Random.new()

local CharacterData;
local LastCharacterData;

local Rate = (1/20)
local Elapsed = 0

local function Format(Time: number): string
    local function RoundDecimals(Number: number): string
        return string.format("%.2f", Number)
    end

	if Time < 1E-6 then
		return `{RoundDecimals(Time * 1E+9)} ns`
	elseif Time < 0.001 then
		return `{RoundDecimals(Time * 1E+6)} μs`
	elseif Time < 1 then
		return `{RoundDecimals(Time * 1000)} ms`
	else
		return `{RoundDecimals(Time)} s`
	end
end

--> Wait for player to connect
task.wait(5)

game:GetService("RunService").PostSimulation:Connect(function(deltaTime)
    Elapsed += deltaTime
    if Elapsed < Rate then
        return
    end

    Elapsed -= Rate
    CharacterData = {
        CompressionUtility.AlwaysSend(0),
        Humanoid.Health,
        RootPart.Position,
        Vector3.new(RootPart.CFrame:ToOrientation()),
        Vector3.zero
    }

    local Stream, Size = CharacterCompressionTable.Compress(CharacterData, LastCharacterData)

    ReplicatedStorage.Event:FireAllClients(Stream)
    LastCharacterData = table.clone(CharacterData)
end)

while task.wait(1) do
    Humanoid:MoveTo(RandomNumberGenerator:NextUnitVector() * Vector3.new(100, 0, 100))
    Humanoid.MoveToFinished:Wait()
end