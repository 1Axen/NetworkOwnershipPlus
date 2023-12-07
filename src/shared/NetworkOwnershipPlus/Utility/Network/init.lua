--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Imports ----

---- Settings ----

---- Constants ----

local IsServer = RunService:IsServer()

---- Variables ----

---- Private Functions ----

---- Public Functions ----

---- Initialization ----

if IsServer then
    if not ReplicatedStorage:FindFirstChild("ReliableConnection") then
        local RemoteEvent = Instance.new("RemoteEvent")
        RemoteEvent.Name = "ReliableConnection"
        RemoteEvent.Parent = ReplicatedStorage
    end

    if not ReplicatedStorage:FindFirstChild("UnreliableConnection") then
        local UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
        UnreliableRemoteEvent.Name = "UnreliableConnection"
        UnreliableRemoteEvent.Parent = ReplicatedStorage
    end

    require(script.Protocol).Server.Start()
else
    ReplicatedStorage:WaitForChild("ReliableConnection")
    ReplicatedStorage:WaitForChild("UnreliableConnection")
    require(script.Protocol).Client.Start()
end

local Time = require(script.Time)
Time.Start()

---- Connections ----

return {
    Time = Time,
    Event = require(script.Event),
    Function = require(script.Function)
}
