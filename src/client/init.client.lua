--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

---- Imports ----

local NetworkOwnershipPlus = require(ReplicatedStorage.NetworkOwnershipPlus)

local Enums = NetworkOwnershipPlus.Enums
local CompressionUtility = NetworkOwnershipPlus.Compression

local CharacterCompressionTable = CompressionUtility.CreateCompressionTable({
    Enums.CompressionTypes.UnsignedByte, --> Identifier [0-255]
    Enums.CompressionTypes.UnsignedShort, --> Health [0-65535]
    Enums.CompressionTypes.Vector, --> Position
    Enums.CompressionTypes.Vector, --> Rotation
    Enums.CompressionTypes.Vector, --> Velocity
})

local Character = ReplicatedStorage.Character:Clone()
local Humanoid: Humanoid = Character.Humanoid
local RootPart: BasePart = Character.HumanoidRootPart
RootPart.Anchored = true
Character.Parent = workspace.CurrentCamera

local CharacterData;

local Gui = game:GetService("StarterGui").Debug
local Text = Gui.Label
Gui.Parent = Players.LocalPlayer.PlayerGui

local function FormatVector(Vector: Vector3): string
    return string.format("%.2f %.2f %.2f", Vector.X, Vector.Y, Vector.Z)
end

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

ReplicatedStorage.Event.OnClientEvent:Connect(function(Stream)
    local LatestCharacterData, PacketSize = CharacterCompressionTable.Decompress(Stream)

    if CharacterData then
        CompressionUtility.ReconcileWithDeltaTable(LatestCharacterData, CharacterData)
    else
        CharacterData = LatestCharacterData
    end

    local Health: number = CharacterData[2] :: number
    local Position: Vector3 = CharacterData[3] :: Vector3
    local Rotation: Vector3 = CharacterData[4] :: Vector3

    Humanoid.Health = Health
    RootPart.CFrame = CFrame.new(Position) * CFrame.fromOrientation(Rotation.X, Rotation.Y, Rotation.Z)

    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    workspace.CurrentCamera.CFrame = CFrame.new(0, 100, 0) * CFrame.Angles(math.rad(-90), 0, 0)

    Text.Text = `Identifier: {CharacterData[1]}\nHealth: {Health}\nPosition: {FormatVector(Position)}\nRotation: {string.format("%.2f", math.deg(Rotation.Y))}\nVelocity: {CharacterData[5]}\n\nPacket In (bytes): {PacketSize}\nPacket Uncompressed (bytes): {CharacterCompressionTable.Size}`
end)



--local Types = require(NetworkOwnershipPlus.Types)
--local Simulation = require(NetworkOwnershipPlus.Simulation)

---- Settings ----

---- Constants ----

--local Camera = workspace.CurrentCamera
--local LocalPlayer = Players.LocalPlayer
--local LocalSimulation = Simulation.new(1)

---- Variables ----

---- Private Functions ----

--[[local ControlModule;
local function GetControlModule()
    if ControlModule == nil then
        local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
        if scripts == nil then
            return nil
        end

        local playerModule = scripts:FindFirstChild("PlayerModule")
        if playerModule == nil then
            return nil
        end

        local controlModule = playerModule:FindFirstChild("ControlModule")
        if controlModule == nil then
            return nil
        end

        ControlModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
    end

    return ControlModule
end

function CalculateRawMoveVector(CameraRelativeMoveVector: Vector3)
    local _, yaw = Camera.CFrame:ToEulerAnglesYXZ()
    return CFrame.fromEulerAnglesYXZ(0, yaw, 0) * Vector3.new(CameraRelativeMoveVector.X, 0, CameraRelativeMoveVector.Z)
end]]

---- Public Functions ----

--[[local function OnPreRender(DeltaTime: number)
    ControlModule = GetControlModule()
    if not ControlModule then
        return
    end

    --> Move Vector
    local MoveVector = ControlModule:GetMoveVector() :: Vector3
    if MoveVector.Magnitude > 1 then
        MoveVector = MoveVector.Unit
    end

    MoveVector = CalculateRawMoveVector(Vector3.new(MoveVector.X, 0, MoveVector.Z))

    --> Jump / Crouch / Prone
    local Jump = UserInputService:IsKeyDown(Enum.KeyCode.Space)
    local Crouch = UserInputService:IsKeyDown(Enum.KeyCode.C)

    local Y = 0
    if Crouch then
        Y = -1
    elseif Jump then
        Y = 1
    end

    local Command: Types.Command = {
        X = MoveVector.X,
        Y = Y, 
        Z = MoveVector.Z,

        Frame = 0,
        DeltaTime = DeltaTime,
    }

    LocalSimulation:Simulate(Command)

    --> Camera
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = LocalSimulation.Camera
end]]

---- Initialization ----

---- Connections ----

--RunService:BindToRenderStep("Input", Enum.RenderPriority.Input.Value, OnPreRender)
