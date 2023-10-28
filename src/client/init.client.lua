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

local NetworkOwnershipPlus = ReplicatedStorage.NetworkOwnershipPlus

local Types = require(NetworkOwnershipPlus.Types)
local Simulation = require(NetworkOwnershipPlus.Simulation)

---- Settings ----

---- Constants ----

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local LocalSimulation = Simulation.new(1)

---- Variables ----

---- Private Functions ----

local ControlModule;
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
end

---- Public Functions ----

local function OnPreRender(DeltaTime: number)
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
end

---- Initialization ----

---- Connections ----

RunService:BindToRenderStep("Input", Enum.RenderPriority.Input.Value, OnPreRender)
