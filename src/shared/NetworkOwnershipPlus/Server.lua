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
local NetworkUtility = require(Utility.Network)

---- Settings ----

local MAXIMUM_PLAYERS = 2^8
local MAXIMUM_ENTITIES = 2^16

---- Constants ----

local Server = {}

---- Variables ----

local Slots: {Types.PlayerRecord} = table.create(MAXIMUM_PLAYERS)
local EntitySlots: {Types.Entity} = table.create(MAXIMUM_ENTITIES)

local PlayerRecords: {[number]: Types.PlayerRecord} = {}
local EntityDefinitions: {[string]: Types.EntityDefinition} = {}

---- Private Functions ----

local function OnPlayerAdded(Player: Player)
    local PlayerRecord = {
        Slot = 0,
        Player = Player,
        UserId = Player.UserId,
        Entities = {},

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
    NetworkUtility.SendReliableEvent(
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

    local Success, Event: number = pcall(function()
        return string.unpack("B", Stream)
    end)

    if not Success then
        return
    end

    if Event == Enums.SystemEvent.RequestFullSnapshot then
        PlayerRecord.SendFullWorldSnapshot = true
    elseif Event == Enums.SystemEvent.ProcessEntityEvent then
        local Success, Identifier, Frame = pcall(function()
            return string.unpack("HJ", Stream, 2)
        end)

        if not Success then
            return
        end

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

    local Success, Event: number = pcall(function()
        return string.unpack("B", Stream)
    end)

    if not Success then
        return
    end

    if Event == Enums.SystemEvent.ProcessEntityEvent then
        local Success, Identifier, Frame, EventType = pcall(function()
            return string.unpack("HJB", Stream, 2)
        end)

        if not Success then
            return
        end

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
            local Success, Movement, DeltaTime = pcall(function()
                return string.unpack("Bd", Stream)
            end)

            if not Success then
                return
            end

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
    NetworkUtility.SendReliableEvent(
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
    NetworkUtility.SendReliableEvent(
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
        NetworkUtility.SendReliableEvent(
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
    NetworkUtility.SendReliableEvent(
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

    Players.PlayerAdded:Connect(OnPlayerAdded)
    Players.PlayerRemoving:Connect(OnPlayerRemoving)

    NetworkUtility.SetupConnection(Enums.ConnectionType.Reliable, OnReliableEvent)
    NetworkUtility.SetupConnection(Enums.ConnectionType.Unreliable, OnUnreliableEvent)    
end

return Server