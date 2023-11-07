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

local MAXIMUM_PLAYERS = 2^8
local MAXIMUM_ENTITIES = 2^16

local MAXIMUM_FIELD_OF_VIEW = math.rad(120)
local MAXIMUM_VISIBILITY_DISTANCE = 2000

local SERVER_UPDATE_RATE = (1 / 20) --> 20 FPS

---- Constants ----

local Server = {}

---- Variables ----

local ServerStart = 0

local ServerFrame = 0
local ServerTimer = 0
local ServerUpdateTimer = 0

local Slots: {Types.PlayerRecord} = table.create(MAXIMUM_PLAYERS)
local EntitySlots: {Types.Entity} = table.create(MAXIMUM_ENTITIES)

local PlayerRecords: {[number]: Types.PlayerRecord} = {}
local EntityDefinitions: {[string]: Types.EntityDefinition} = {}

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
            Frame = ServerFrame,
            Layout = EntitySerialized
        }

        --> Should we send a full snapshot or a delta one?
        local Stream: string;
        if not ReplicationRecord or (ServerFrame - ReplicationRecord.Frame) > 1 or PlayerRecord.SendFullWorldSnapshot then
            Stream = Entity.CompressionTable.Compress(EntitySerialized)
        else
            Stream = Entity.CompressionTable.Compress(EntitySerialized, ReplicationRecord.Layout)
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
    PlayerRecords[Player.UserId] = PlayerRecord

    --> Replicate initial state
    Network.SendReliableEvent(
        Enums.NetworkRecipient.Player, 
        Player, 
        string.pack("B", Enums.SystemEvent.Initialize),
        Slots
    )
end

local function OnPlayerRemoving(Player: Player)
    local PlayerRecord = PlayerRecords[Player.UserId]
    if not PlayerRecord then
        return
    end

    --> Remove entity ownership
    for Index, Entity in PlayerRecord.Entities do
        Entity:SetNetworkOwner()
        PlayerRecord.Entities[Index] = nil
    end

    --> Remove from records
    Slots[PlayerRecord.Slot] = nil
    PlayerRecords[PlayerRecord.UserId] = nil

    --> Clear
    table.clear(PlayerRecord)
end

-- selene: allow(shadowing)
local function OnReliableEvent(Player: Player, Stream: string, Packet: any)
    --> Type validation
    if typeof(Stream) ~= "string" then
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
        local Frame = StreamBuffer.ReadUnsignedInteger()
        local Identifier = StreamBuffer.ReadUnsignedShort()

        local Entity = PlayerRecord.Entities[Identifier]
        if not Entity then
            return
        end

        Entity:ProcessEvent({
            Type = Enums.EntityEvent.Custom,
            Frame = Frame,
            Packet = Packet
        })
    end
end

-- selene: allow(shadowing)
local function OnUnreliableEvent(Player: Player, Stream: string, Packet: any)
    --> Type validation
    if typeof(Stream) ~= "string" then
        return
    end

    local PlayerRecord = PlayerRecords[Player.UserId]
    if not PlayerRecord then
        return
    end

    local StreamBuffer = Buffer.new(Stream)
    local Event = StreamBuffer.ReadByte()

    if Event == Enums.SystemEvent.ProcessEntityEvent then
        local Frame = StreamBuffer.ReadUnsignedInteger()
        local EventType = StreamBuffer.ReadUnsignedByte()
        local Identifier = StreamBuffer.ReadUnsignedShort()

        local Entity = PlayerRecord.Entities[Identifier]
        if not Entity then
            return
        end

        if EventType == Enums.EntityEvent.Custom then
            Entity:ProcessEvent({
                Type = Enums.EntityEvent.Custom,
                Frame = Frame,
                Packet = Packet
            })
        elseif EventType == Enums.EntityEvent.Command then
            local Movement = StreamBuffer.ReadUnsignedByte()
            local DeltaTime = StreamBuffer.ReadDouble()

            Entity:ProcessEvent({
                Type = Enums.EntityEvent.Custom,
                Frame = Frame,
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
    ServerFrame += 1
    ServerTimer = os.clock() - ServerStart
    ServerUpdateTimer += DeltaTime

    --> Step entities
    for _, Entity in EntitySlots do
        Entity:Step(DeltaTime)
    end

    --> Replicate world to players
    if ServerUpdateTimer >= SERVER_UPDATE_RATE then
        --> The server might have lagged, and taken extra time to process the last frame
        --> We account for this by only subtracting the time needed to send one snapshot instead of resetting the timer
        ServerUpdateTimer -= SERVER_UPDATE_RATE

        local EventBuffer = Buffer.new("")
        EventBuffer.WriteUnsignedByte(Enums.SystemEvent.WorldSnapshot)
        EventBuffer.WriteUnsignedInteger(ServerFrame)
        EventBuffer.WriteDouble(ServerTimer)

        print(`Frame: {ServerFrame}, Timestamp: {ServerTimer}`)

        for _, PlayerRecord in PlayerRecords do
            --! FIXME(Axen): Convert to unreliable event once they are released
            local Streams = BuildSnapshot(PlayerRecord)
            Network.SendReliableEvent(
                Enums.NetworkRecipient.Player, 
                PlayerRecord.Player,
                EventBuffer,
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

    --> Replicate entity creation
    Network.SendReliableEvent(
        Enums.NetworkRecipient.AllPlayers, 
        string.pack(
            "BH", 
            Enums.SystemEvent.CreateEntity, 
            Entity.Identifier
        ),
        Angle,
        Position
    )

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
    Network.SendReliableEvent(
            Enums.NetworkRecipient.AllPlayers, 
            string.pack(
                "BH", 
                Enums.SystemEvent.DestroyEntity, 
                Entity.Identifier
            )
        )
    
    --> Call entity destroy
    Entity:Destroy()
end

function Server.RegisterEntity(Definition: Types.EntityDefinition)
    EntityDefinitions[Definition.Name] = Definition
end

function Server.SetEntityNetworkOwner(Entity: Types.Entity, Owner: Player?)
    local PreviousOwner = Entity.Owner
    if PreviousOwner then
        PreviousOwner.Entities[Entity.Identifier] = nil
        Network.SendReliableEvent(
            Enums.NetworkRecipient.Player, 
            PreviousOwner.Player,
            string.pack(
                "BH", 
                Enums.SystemEvent.RemoveOwnership, 
                Entity.Identifier
            )
        )
    end

    local PlayerRecord = Owner and PlayerRecords[Owner.UserId]
    if not PlayerRecord then
        --error("Attempted to assign network ownership to a player that isn't connected!")
        return
    end

    PlayerRecord.Entities[Entity.Identifier] = Entity
    Network.SendReliableEvent(
        Enums.NetworkRecipient.Player, 
        Owner,
        string.pack(
            "BH", 
            Enums.SystemEvent.AssignOwnership, 
            Entity.Identifier
        )
    )
end

---- Initialization ----

function Server.Initialize()
    if Players.MaxPlayers > MAXIMUM_PLAYERS then
        warn(`[WARNING] NetworkOwnershipPlus only supports 256 maximum players, but the server size is {Players.MaxPlayers}. Any excess players will be kicked upon connecting to the server!`)
    end

    ServerStart = os.clock()

    Players.PlayerAdded:Connect(OnPlayerAdded)
    Players.PlayerRemoving:Connect(OnPlayerRemoving)

    RunService.PreSimulation:Connect(OnPreSimulation)
    RunService.PostSimulation:Connect(OnPostSimulation)

    Network.SetupConnection(Enums.ConnectionType.Reliable, OnReliableEvent)
    Network.SetupConnection(Enums.ConnectionType.Unreliable, OnUnreliableEvent)    
end

return Server