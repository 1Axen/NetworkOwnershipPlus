--!strict
--!nolint LocalShadow 

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

---- Imports ----

local Package = script.Parent
local Utility = Package.Utility

local Types = require(Package.Types)
local Enums = require(Package.Enums)
local Buffer = require(Utility.Buffer)
local Network = require(Utility.Network)
local Compression = require(Utility.Compression)

---- Settings ----

local SERVER_RATE = (1 / 60) -- Assume stable 60 FPS

local MAXIMUM_PLAYERS = 2^8
local MAXIMUM_ENTITIES = 2^16

local MAXIMUM_FIELD_OF_VIEW = math.rad(120)
local MAXIMUM_VISIBILITY_DISTANCE = 2000

---- Constants ----

local Server = {
    Frame = 0,
    Timer = 0,

    SnapshotTimer = 0,
}

local Settings: Types.Settings;

---- Variables ----

local ServerStart = 0

local Slots: {Types.PlayerRecord} = table.create(MAXIMUM_PLAYERS)
local UserIdSlots: {[number]: number} = {}
local EntitySlots: {Types.Entity} = table.create(MAXIMUM_ENTITIES)

local PlayerRecords: {[number]: Types.PlayerRecord} = {}

local EntityMappings: {string} = {}
local EntityDefinitions: {[string]: Types.EntityDefinition};

---- Private Functions ----

local function BuildSnapshot(PlayerRecord: Types.PlayerRecord): ({string})
    local Streams: {string} = {}

    for _, Entity in EntitySlots do
        if Entity.ReplicationState == Enums.ReplicationState.DontSend then
            continue
        elseif Entity.ReplicationState == Enums.ReplicationState.Manual then
            if not Entity:ShouldReplicate(PlayerRecord) then
                continue
            end
        elseif Entity.ReplicationState == Enums.ReplicationState.OnlyVisible then
            local PrimaryEntity = PlayerRecord.Entities[1]
            if not PrimaryEntity then
                continue
            end

            local Direction = PrimaryEntity.Simulation.Position - Entity.Simulation.Position
            local Angle = PrimaryEntity.Simulation.Angle:Dot(Direction)
            if Angle > MAXIMUM_FIELD_OF_VIEW or Direction.Magnitude > MAXIMUM_VISIBILITY_DISTANCE then
                continue
            end
        end

        local Identifier = Entity.Identifier
        local EntitySerialized: Compression.SupportedValuesLayout = Entity:Serialize()
        local ReplicationRecord = PlayerRecord.Replication[Identifier]

        PlayerRecord.Replication[Identifier] = {
            Frame = Server.Frame,
            Layout = EntitySerialized
        }

        --> Should we send a full snapshot or a delta one?
        local Stream: string;
        if not ReplicationRecord or (Server.Frame - ReplicationRecord.Frame) > 1 or PlayerRecord.SendFullWorldSnapshot then
            Stream = Entity.Definition.CompressionTable.Compress(EntitySerialized)
        else
            Stream = Entity.Definition.CompressionTable.Compress(EntitySerialized, ReplicationRecord.Layout)
        end

        --> Add stream entry
        table.insert(Streams, Stream)
    end

    return Streams
end

local function OnPlayerAdded(Player: Player)
    local PlayerRecord = {
        Slot = 0,
        Player = Player,
        UserId = Player.UserId,

        Entities = {},
        Replication = {},

        Commands = {},

        SendFullWorldSnapshot = true,
    }

    --> Find a valid slot for the player, kick them if there is none available
    for Slot = 1, MAXIMUM_PLAYERS do
        if not Slots[Slot] then
            PlayerRecord.Slot = Slot
            Slots[Slot] = PlayerRecord
        end
    end
    
    if PlayerRecord.Slot == 0 then
        table.clear(PlayerRecord)
        Player:Kick("Server is currently full, please try again later!")
        return
    end

    --> Add to records
    UserIdSlots[Player.UserId] = PlayerRecord.Slot
    PlayerRecords[Player.UserId] = PlayerRecord

    --> Replicate initial state
    do
        local EventBuffer = Buffer.new()
        EventBuffer.WriteByte(Enums.SystemEvent.Initialize)
        EventBuffer.WriteDouble(ServerStart)

        Network.SendReliableEvent(
            Enums.NetworkRecipient.Player, 
            Player, 
            EventBuffer.ToString(),
            UserIdSlots,
            EntityMappings
        )
    end

    --> Replicate slot assignment
    do
        local EventBuffer = Buffer.new()
        EventBuffer.WriteUnsignedByte(Enums.SystemEvent.AssignSlot)
        EventBuffer.WriteUnsignedByte(PlayerRecord.Slot)
        EventBuffer.WriteUnsignedInteger(Player.UserId)

        Network.SendReliableEvent(
            Enums.NetworkRecipient.AllPlayersExcept,
            Player,
            EventBuffer
        )
    end
end

local function OnPlayerRemoving(Player: Player)
    local PlayerRecord = PlayerRecords[Player.UserId]
    if not PlayerRecord then
        return
    end

    --> Replicate slot assignment
    do
        local EventBuffer = Buffer.new()
        EventBuffer.WriteUnsignedByte(Enums.SystemEvent.AssignSlot)
        EventBuffer.WriteUnsignedByte(PlayerRecord.Slot)
        EventBuffer.WriteUnsignedInteger(0)

        Network.SendReliableEvent(
            Enums.NetworkRecipient.AllPlayersExcept,
            Player,
            EventBuffer
        )
    end

    --> Remove entity ownership
    for Index, Entity in PlayerRecord.Entities do
        Entity:SetNetworkOwner()
        PlayerRecord.Entities[Index] = nil
    end

    --> Remove from records
    Slots[PlayerRecord.Slot] = nil
    UserIdSlots[Player.UserId] = nil
    PlayerRecords[PlayerRecord.UserId] = nil

    --> Clear
    table.clear(PlayerRecord)
end

-- selene: allow(shadowing)
local function OnNetworkEvent(Player: Player, Stream: string, Packet: any)
    --> Type validation
    if type(Stream) ~= "string" then
        return
    end

    local PlayerRecord = PlayerRecords[Player.UserId]
    if not PlayerRecord then
        return
    end

    local StreamBuffer = Buffer.new(Stream)
    local Event = StreamBuffer.ReadUnsignedByte()

    if Event == Enums.SystemEvent.RequestFullSnapshot then
        PlayerRecord.SendFullWorldSnapshot = true
    elseif Event == Enums.SystemEvent.ProcessEntityEvent then
        local Time = StreamBuffer.ReadDouble()
        local Frame = StreamBuffer.ReadUnsignedInteger()
        local EventType = StreamBuffer.ReadUnsignedByte()
        local Identifier = StreamBuffer.ReadUnsignedShort()

        --> Prevent invalid command times
        if Time > Server.Timer then
            return
        end

        local Entity = PlayerRecord.Entities[Identifier]
        if not Entity then
            return
        end

        if EventType == Enums.EntityEvent.Custom then
            Entity:ServerProcessEvent({
                Type = Enums.EntityEvent.Custom,
                Time = Time,
                Frame = Frame,
                Packet = Packet
            })
        elseif EventType == Enums.EntityEvent.Movement then
            local Movement = StreamBuffer.ReadUnsignedByte()
            local DeltaTime = StreamBuffer.ReadDouble()

            --> Prevent commands with large delta times (speed hack)
            if DeltaTime > Settings.CommandProcessingTime then
                return
            end

            table.insert(PlayerRecord.Commands, {
                Type = Enums.EntityEvent.Movement,
                Time = Time,
                Frame = Frame,
                Entity = Entity.Identifier,
                Packet = Packet,
                DeltaTime = DeltaTime,

                X = bit32.extract(Movement, 2, 2),
                Y = bit32.extract(Movement, 4, 2),
                Z = bit32.extract(Movement, 0, 2)
            })
        end
    end
end

local function OnPreSimulation(DeltaTime: number)
    
end

local function OnPostSimulation(DeltaTime: number)
    --> Advance timers
    Server.Frame += 1
    Server.Timer = workspace:GetServerTimeNow() - ServerStart
    Server.SnapshotTimer += DeltaTime

    --> Process commands
    for _, PlayerRecord in PlayerRecords do
        local Commands = PlayerRecord.Commands
        local TimeSimulated = 0

        --> Sort commands (fixes out of order commands)
        --> Process oldest commands first
        table.sort(Commands, function(A, B)
            return A.Frame < B.Frame
        end)

        for Index = #Commands, 1, -1 do
            --> Do not simulate more than the maximum allowed time (Speed hack)
            if TimeSimulated > Settings.CommandProcessingTime then
                break
            end

            local Command = Commands[Index]
            if not Command then
                continue
            end

            --> Is command being buffered?
            if (Server.Timer - Command.Time) < Settings.CommandBufferTime then
                continue
            end

            --> Remove command from queue
            table.remove(Commands, Index)

            local Entity = EntitySlots[Command.Entity]
            
            --> Entity was deleted
            if not Entity then
                continue
            end

            --> Player lost ownership
            if Entity.Owner ~= PlayerRecord then
                continue
            end

            TimeSimulated += Command.DeltaTime
            Entity:ServerProcessEvent(Command)
        end
    end

    --> Step entities & components
    for _, Entity in EntitySlots do
        for _, Component in Entity.Components do
            Component:ServerStep(DeltaTime)
        end

        Entity:ServerStep(DeltaTime)
    end

    --> Replicate world to players
    if Server.SnapshotTimer >= Settings.UpdateRate then
        --> The server might have lagged, and taken extra time to process the last frame
        --> We account for this by only subtracting the time needed to send one snapshot instead of resetting the timer
        Server.SnapshotTimer -= Settings.UpdateRate

        local EventBuffer = Buffer.new()
        EventBuffer.WriteUnsignedByte(Enums.SystemEvent.WorldSnapshot)
        EventBuffer.WriteUnsignedInteger(Server.Frame)
        EventBuffer.WriteDouble(Server.Timer)

        print(`Frame: {Server.Frame}, Timestamp: {Server.Timer}`)

        for _, PlayerRecord in PlayerRecords do
            --! FIXME(Axen): Convert to unreliable event once they are released
            local Streams = BuildSnapshot(PlayerRecord)
            Network.SendReliableEvent(
                Enums.NetworkRecipient.Player, 
                PlayerRecord.Player,
                EventBuffer.ToString(),
                Streams
            )
            print(`{PlayerRecord.Player.Name} ({PlayerRecord.UserId}):`, Streams)
        end
    end
end

---- Public Functions ----

function Server.CreateEntity(Name: string, Angle: Vector3, Position: Vector3, Owner: Player?, ...): Types.Entity
    local Definition: Types.EntityDefinition? = EntityDefinitions[Name]
    assert(Definition, "Unknown entity definition, double check your spelling.")
    
    local Identifier: number?;
    for Index = 1, MAXIMUM_ENTITIES do
        if not EntitySlots[Index] then
            Identifier = Index
            EntitySlots[Index] = true :: any --> Claim slot
        end
    end

    if not Identifier then
        error("Maximum number of entities reached, something has gone terribly wrong!")
    end

    local Entity = Definition.CreateEntity(Angle, Position, ...)
    Entity.Identifier = Identifier
    EntitySlots[Identifier] = Entity

    --> Assign network ownership
    if Owner then
        Server.SetEntityNetworkOwner(Entity, Owner)
    end

    return Entity
end

function Server.DestroyEntity(Entity: Types.Entity)
    --> Remove from records
    EntitySlots[Entity.Identifier] = nil

    --> Remove network ownership
    if Entity.Owner then
        Server.SetEntityNetworkOwner(Entity)
    end

    --> Replicate destruction
    local EventBuffer = Buffer.new()
    EventBuffer.WriteUnsignedByte(Enums.SystemEvent.DestroyEntity)
    EventBuffer.WriteUnsignedShort(Entity.Identifier)
    Network.SendReliableEvent(
        Enums.NetworkRecipient.AllPlayers, 
        EventBuffer.ToString()
    )
    
    --> Call entity destroy
    Entity:ServerDestroy()
end

function Server.SetEntityNetworkOwner(Entity: Types.Entity, Owner: Player?)
    local PreviousOwner = Entity.Owner
    if PreviousOwner then
        local EventBuffer = Buffer.new()
        EventBuffer.WriteUnsignedByte(Enums.SystemEvent.RemoveOwnership)
        EventBuffer.WriteUnsignedShort(Entity.Identifier)

        PreviousOwner.Entities[Entity.Identifier] = nil
        Network.SendReliableEvent(
            Enums.NetworkRecipient.Player, 
            PreviousOwner.Player,
            EventBuffer.ToString()
        )
    end

    local PlayerRecord = Owner and PlayerRecords[Owner.UserId]
    if not PlayerRecord then
        --error("Attempted to assign network ownership to a player that isn't connected!")
        return
    end

    local EventBuffer = Buffer.new()
    EventBuffer.WriteUnsignedByte(Enums.SystemEvent.AssignOwnership)
    EventBuffer.WriteUnsignedByte(PlayerRecord.Slot)
    EventBuffer.WriteUnsignedShort(Entity.Identifier)

    PlayerRecord.Entities[Entity.Identifier] = Entity
    Network.SendReliableEvent(
        Enums.NetworkRecipient.AllPlayers,
        EventBuffer.ToString()
    )
end

---- Initialization ----

function Server.Initialize(UserSettings: Types.Settings, UserEntities: {[string]: Types.EntityDefinition})
    if Players.MaxPlayers > MAXIMUM_PLAYERS then
        warn(`[WARNING] NetworkOwnershipPlus only supports 256 maximum players, but the server size is {Players.MaxPlayers}. Any excess players will be kicked upon connecting to the server!`)
    end

    --> Create entity mappings
    local Index = 0
    for _, Entity in UserEntities do
        Entity.Identifier = Index
        EntityMappings[Index] = Entity.Name
        Index += 1
    end

    Settings = UserSettings
    EntityDefinitions = UserEntities
    ServerStart = workspace:GetServerTimeNow()

    Players.PlayerAdded:Connect(OnPlayerAdded)
    Players.PlayerRemoving:Connect(OnPlayerRemoving)

    RunService.PreSimulation:Connect(OnPreSimulation)
    RunService.PostSimulation:Connect(OnPostSimulation)

    Network.SetupConnection(Enums.ConnectionType.Reliable, OnNetworkEvent)
    Network.SetupConnection(Enums.ConnectionType.Unreliable, OnNetworkEvent)    
end

return Server