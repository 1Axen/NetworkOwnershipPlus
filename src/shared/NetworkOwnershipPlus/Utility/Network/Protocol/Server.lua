--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Imports ----

local Network = script.Parent.Parent
local Utility = Network.Parent

local Spawn = require(Utility.Spawn)

---- Settings ----

type Events = {[string]: {{any}}}

type Outgoing = {
    [Player]: {
        Reliable: {[string]: {{any}}},
        Unreliable: {[string]: {{any}}}
    }
}

---- Constants ----

local Protocol = {}

local ReliableEvent: RemoteEvent = ReplicatedStorage:FindFirstChild("ReliableConnection")
local UnreliableEvent: UnreliableRemoteEvent = ReplicatedStorage:FindFirstChild("UnreliableConnection")

---- Variables ----

local Listeners: {[string]: (Player, ...any) -> (...any)} = {}
local Outgoing: Outgoing = {}

---- Private Functions ----

local function OnServerEvent(Player: Player, Events: Events)
    for Identifier, Packets in Events do
        local Listener = Listeners[Identifier]
        if not Listener then
            continue
        end

        for _, Packet in Packets do
            Spawn(Listener, Player, table.unpack(Packet))
        end
    end
end

local function OnServerHeartbeat()
    for Player, Events in Outgoing do
        if next(Events.Reliable) then
            ReliableEvent:FireClient(Player, Events.Reliable)
        end

        if next(Events.Unreliable) then
            UnreliableEvent:FireClient(Player, Events.Unreliable)
        end

        Outgoing[Player] = nil
    end
end

---- Public Functions ----

function Protocol.SendEvent(Identifier: string, Reliable: boolean, Player: Player, ...)
    local Arguments = {...}

    local Bucket = Outgoing[Player]
    if not Bucket then
        Bucket = {
            Reliable = {},
            Unreliable = {}
        }
        Outgoing[Player] = Bucket
    end

    local Layer = Reliable and Bucket.Reliable or Bucket.Unreliable
    if not Layer[Identifier] then
        Layer[Identifier] = {}
    end

    table.insert(Layer[Identifier], Arguments)
end 

function Protocol.SetListener(Identifier: string, Listener: (...any) -> ())
    Listeners[Identifier] = Listener
end

---- Initialization ----

function Protocol.Start()
    ReliableEvent.OnServerEvent:Connect(OnServerEvent)
    UnreliableEvent.OnServerEvent:Connect(OnServerEvent)
    RunService.Heartbeat:Connect(OnServerHeartbeat)
end

---- Connections ----

return Protocol
