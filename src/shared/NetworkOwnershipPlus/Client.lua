--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

local Package = script.Parent
local Utility = Package.Utility

local Enums = require(Package.Enums)
local Types = require(Package.Types)

local Signal = require(Utility.Signal)
local Buffer = require(Utility.Buffer)
local Network = require(Utility.Network)

---- Settings ----

---- Constants ----

local Client = {
    Frame = 0,
    Timer = 0,
    ServerTimer = 0,

    Initialized = Signal.new(),
    HasInitialized = false,
}

local Settings: Types.Settings;
local EntityMappings: {string};
local EntityDefinitions: {[string]: Types.EntityDefinition};

---- Variables ----

local Slots: {[number]: number} = {}
local UserIdSlots: {[number]: number} = {}

local ClientStart = 0
local ServerStart = 0

---- Private Functions ----

local function OnPreRender(DeltaTime: number)
    Client.Frame += 1
    Client.Timer = os.clock() - ClientStart
    Client.ServerTimer = workspace:GetServerTimeNow() - ServerStart
end

local function OnPostSimulation(DeltaTime: number)
    
end

local function OnNetworkEvent(Stream: string, ...)
    local Arguments = {...}
    local EventBuffer = Buffer.new(Stream)
    local Event = EventBuffer.ReadUnsignedByte()

    if Event ~= Enums.SystemEvent.Initialize and not Client.HasInitialized then
        Client.Initialized:Wait()
    end

    if Event == Enums.SystemEvent.Initialize then
        --> Player slots
        UserIdSlots = Arguments[1]
        for UserId, Slot in UserIdSlots do
            Slots[Slot] = UserId
        end

        --> Entity mappings
        EntityMappings = Arguments[2]
        for Index, Name in EntityMappings do
            EntityDefinitions[Name].Identifier = Index
        end

        ServerStart = EventBuffer.ReadDouble()

        --> Complete initialization
        Client.HasInitialized = true
        Client.Initialized:Fire()
    elseif Event == Enums.SystemEvent.AssignSlot then
        local Slot = EventBuffer.ReadUnsignedByte()
        local UserId = EventBuffer.ReadUnsignedInteger()

        if UserId == 0 then
            UserId = Slots[Slot]
            Slots[Slot] = nil
            UserIdSlots[UserId] = nil
        else
            Slots[Slot] = UserId
            UserIdSlots[UserId] = Slot
        end
    elseif Event == Enums.SystemEvent.WorldSnapshot then
        for Index, SnapshotStream in Arguments[1] do
            
        end
    end
end

---- Public Functions ----

---- Initialization ----

function Client.Initialize(UserSettings: Types.Settings, UserEntities: {[string]: Types.EntityDefinition})
    Settings = UserSettings
    EntityDefinitions = UserEntities

    --> Wait to recieve initialize event
    Client.Initialized:Once(function()
        ClientStart = os.clock()
        RunService.PreRender:Connect(OnPreRender)
        RunService.PostSimulation:Connect(OnPostSimulation)
        Network.SetupConnection(Enums.ConnectionType.Reliable, OnNetworkEvent)
    end)

    --> Network connections
    Network.SetupConnection(Enums.ConnectionType.Reliable, OnNetworkEvent)
end

---- Connections ----

return Client