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
    Reliable: {[string]: {{any}}},
    Unreliable: {[string]: {{any}}}
}

---- Constants ----

local Protocol = {}

local ReliableEvent: RemoteEvent = ReplicatedStorage:WaitForChild("ReliableConnection")
local UnreliableEvent: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("UnreliableConnection")

---- Variables ----

local WasPacketSent = false

local Listeners: {[string]: (Player, ...any) -> ()} = {}
local Invocations: {[string]: thread} = {}

local Outgoing: Outgoing = {
    Reliable = {},
    Unreliable = {}
}

---- Private Functions ----

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

local function OnClientHeartbeat()
    for _, Packet in Outgoing.Reliable do
        ReliableEvent:FireServer(table.unpack(Packet))
    end

    for _, Packet in Outgoing.Unreliable do
        ReliableEvent:FireServer(table.unpack(Packet))
    end

    if WasPacketSent then
        Outgoing = {
            Reliable = {},
            Unreliable = {}
        }
    
        WasPacketSent = false
    end
end

---- Public Functions ----

function Protocol.SendEvent(Identifier: string, Reliable: boolean, ...)
    local Arguments = {...}
    local Bucket = Reliable and Outgoing.Reliable or Outgoing.Unreliable

    if not Bucket[Identifier] then
        Bucket[Identifier] = {}
    end

    WasPacketSent = true
    table.insert(Bucket[Identifier], Arguments)
end 

function Protocol.InvokeFunction(Identifier: string, InvocationIdentifier: string, ...)
    local Arguments = {...}
    local Bucket = Outgoing.Reliable
    if not Bucket[Identifier] then
        Bucket[Identifier] = {}
    end

    WasPacketSent = true
    table.insert(Arguments, 1, InvocationIdentifier)
    table.insert(Bucket[Identifier], Arguments)

    Invocations[InvocationIdentifier] = coroutine.running()
    return coroutine.yield()
end

function Protocol.SetListener(Identifier: string, Listener: (...any) -> ())
    Listeners[Identifier] = Listener
end

---- Initialization ----

function Protocol.Start()
    ReliableEvent.OnClientEvent:Connect(OnClientEvent)
    UnreliableEvent.OnClientEvent:Connect(OnClientEvent)
    RunService.Heartbeat:Connect(OnClientHeartbeat)
end

---- Connections ----

return Protocol
