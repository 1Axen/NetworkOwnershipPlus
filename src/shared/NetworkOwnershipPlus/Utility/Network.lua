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

local FOLDER_NAME = "_CONNECTIONS"

--! FIXME(Axen): Remove this once the BaseRemoteEvent type is LIVE
type BaseRemoteEvent = RemoteEvent
type UnreliableRemoteEvent = RemoteEvent

---- Constants ----

local Utility = {}
local ReliableConnection: RemoteEvent;
local UnreliableConnection: UnreliableRemoteEvent;

---- Variables ----

---- Private Functions ----

local function SendEvent(Connection: BaseRemoteEvent, Recipient: number, ...)
    if Recipient == Enums.NetworkRecipient.Server then
        Connection:FireServer(...)
    elseif Recipient == Enums.NetworkRecipient.Player then
        Connection:FireClient(...)
    elseif Recipient == Enums.NetworkRecipient.AllPlayers then
        Connection:FireAllClients(...)
    end
end

local function InitializeServerConnections()
    local Events = Instance.new("Folder")
    Events = Instance.new("Folder")
    Events.Name = FOLDER_NAME

    ReliableConnection = Instance.new("RemoteEvent")
    ReliableConnection.Name = "Reliable"
    ReliableConnection.Parent = Events

    --! FIXME: Remove this type casting once UnreliableRemoteEvent is LIVE
    UnreliableConnection = Instance.new("UnreliableRemoteEvent") :: any
    UnreliableConnection.Name = "Unreliable"
    UnreliableConnection.Parent = Events

    Events.Parent = ReplicatedStorage
end

local function InitializeClientConnections()
    local Events = ReplicatedStorage:WaitForChild(FOLDER_NAME)
    ReliableConnection = Events:WaitForChild("Reliable")
    UnreliableConnection = Events:WaitForChild("Unreliable")
end

---- Public Functions ----

function Utility.SendReliableEvent(Recipient: number, ...)
    SendEvent(ReliableConnection, Recipient, ...)
end

function Utility.SendUnreliableEvent(Recipient: number, ...)
    SendEvent(UnreliableConnection, Recipient, ...)
end

function Utility.SetupConnection(Reliability: number, Callback: (...any) -> ()): RBXScriptConnection
    local Connection: BaseRemoteEvent;
    if Reliability == Enums.ConnectionType.Reliable then
        Connection = ReliableConnection
    elseif Reliability == Enums.ConnectionType.Unreliable then
        Connection = UnreliableConnection
    end

    if RunService:IsServer() then
        return Connection.OnServerEvent:Connect(Callback)
    else
        return Connection.OnClientEvent:Connect(Callback)
    end
end

---- Initialization ----

--> Initialize context connections
if RunService:IsServer() then
    InitializeServerConnections()
else
    InitializeClientConnections()
end

---- Connections ----

return Utility
