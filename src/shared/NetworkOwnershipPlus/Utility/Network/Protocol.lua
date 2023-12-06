--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Imports ----

local Package = script.Parent.Parent
local Enums = require(Package.Enums)

---- Settings ----

type Outgoing = {
    Reliable: {[string]: {{any}}},
    Unreliable: {[string]: {{any}}}
}

---- Constants ----

local Protocol = {}

local ReliableEvent: RemoteEvent = ReplicatedStorage:WaitForChild("ReliableConnection")
local UnreliableEvent: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("UnreliableConnection")

---- Variables ----

local Listeners: {[string]: (Player, ...any) -> ()} = {}
local Outgoing: Outgoing = {
    Reliable = {},
    Unreliable = {}
}

---- Private Functions ----

---- Public Functions ----

local function OnServerEvent(Player: Player, Events: {[string]: {{any}}})
    for Identifier, Packets in Events do
        local Listener = Listeners[Identifier]
        if not Listener then
            continue
        end

        for _, Packet in Packets do
            task.spawn(Listener, table.unpack(Packet))
        end
    end
end

---- Initialization ----

function Protocol.Start()
    if RunService:IsServer() then
        ReliableEvent.OnServerEvent:Connect(OnServerEvent)
        UnreliableEvent.OnServerEvent:Connect(OnServerEvent)
    end

    RunService.Heartbeat:Connect(function()

    end)
end

---- Connections ----

return Protocol
