--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Imports ----

local Utility = script.Parent.Parent
local Package = Utility.Parent

local Enums = require(Package.Enums)
local Spawn = require(Utility.Spawn)

---- Settings ----

type Events = {[string]: {{any}}}

type Outgoing = {
    Reliable: {[string]: {{any}}},
    Unreliable: {[string]: {{any}}}
}

---- Constants ----

local Protocol = {}

local ReliableEvent: RemoteEvent = ReplicatedStorage:WaitForChild("ReliableConnection")
local UnreliableEvent: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("UnreliableConnection")

---- Variables ----

local Shared = 0
local WasPacketSent = false

local Listeners: {[string]: (Player, ...any) -> ()} = {}
local Outgoing: Outgoing = {
    Reliable = {},
    Unreliable = {}
}

---- Private Functions ----

local function ClearOutgoingPackets()
    if not WasPacketSent then
       return
    end

    Outgoing = {
        Reliable = {},
        Unreliable = {}
    }

    WasPacketSent = false
end

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

local function OnClientEvent(Events: Events)
    for Identifier, Packets in Events do
        local Listener = Listeners[Identifier]
        if not Listener then
            continue
        end

        for _, Packet in Packets do
            Spawn(Listener, table.unpack(Packet))
        end
    end
end

local function OnServerHeartbeat()
    for _, Packet in Outgoing.Reliable do
        ReliableEvent:FireClient(table.unpack(Packet) :: any)
    end

    for _, Packet in Outgoing.Unreliable do
        ReliableEvent:FireClient(table.unpack(Packet) :: any)
    end

    ClearOutgoingPackets()
end

local function OnClientHeartbeat()
    for _, Packet in Outgoing.Reliable do
        ReliableEvent:FireServer(table.unpack(Packet))
    end

    for _, Packet in Outgoing.Unreliable do
        ReliableEvent:FireServer(table.unpack(Packet))
    end

    ClearOutgoingPackets()
end

---- Public Functions ----

function Protocol.SendEvent(Identifier: string, Reliable: boolean, ...)
    local Arguments = {...}
    local Bucket = Reliable and Outgoing.Reliable or Outgoing.Unreliable

    if not Bucket[Identifier] then
        Bucket[Identifier] = {Arguments}
        return
    end

    WasPacketSent = true
    table.insert(Bucket[Identifier], Arguments)
end 

function Protocol.SetListener(Identifier: string, Listener: (...any) -> ())
    Listeners[Identifier] = Listener
end

function Protocol.GetIdentifier(Name: string): string
    local Identifier = ReliableEvent:GetAttribute(Name)
    if RunService:IsServer() then
        if not Identifier then
            Shared += 1
            Identifier = string.pack("B", Shared)
        end
        
        return Identifier
    else
        while not Identifier do
            ReliableEvent.AttributeChanged:Wait()
            Identifier = ReliableEvent:GetAttribute(Name)
        end

        return Identifier
    end
end

---- Initialization ----

function Protocol.Start()
    if RunService:IsServer() then
        ReliableEvent.OnServerEvent:Connect(OnServerEvent)
        UnreliableEvent.OnServerEvent:Connect(OnServerEvent)
        RunService.Heartbeat:Connect(OnServerHeartbeat)
    else
        ReliableEvent.OnClientEvent:Connect(OnClientEvent)
        UnreliableEvent.OnClientEvent:Connect(OnClientEvent)
        RunService.Heartbeat:Connect(OnClientHeartbeat)
    end
end

---- Connections ----

return Protocol
