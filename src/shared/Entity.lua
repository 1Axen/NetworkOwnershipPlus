--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Imports ----

local NetworkOwnershipPlus = ReplicatedStorage.NetworkOwnershipPlus

local Types = require(NetworkOwnershipPlus.Types)
local Enums = require(NetworkOwnershipPlus.Enums)
local Compression = require(NetworkOwnershipPlus.Utility.Compression)

local NetworkOwnershipPlus = require(NetworkOwnershipPlus)

---- Settings ----

---- Constants ----

local Definition = {
    Name = "Dummy",
    Serialized = {
        Position = Compression.Types.Vector,
    }
}

local Entity = {}
Entity.__index = Entity

---- Variables ----

---- Private Functions ----

---- Public Functions ----

--> Shared Methods
function Entity:SetAngle(Angle: Vector3)
    
end

function Entity:SetPosition(Position: Vector3)
    
end

--> Client Methods
function Entity:ClientStep(DeltaTime: number)
    
end

function Entity:ClientProcessEvent(Event: Types.Event)
    
end

function Entity:ClientDestroy()
    
end

--> Server Methods
function Entity:ServerStep(DeltaTime: number)
    
end
function Entity:ServerProcessEvent(Event: Types.Event)
    
end

function Entity:ServerDestroy()
    
end

--> Network Methods
function Entity:Serialize(): ({[string]: Compression.SupportedValues})
    return {
        Position = Vector3.new()
    }
end

function Entity:SetNetworkOwner(Owner: Player?)
    
end

function Entity:ShouldReplicate(Player: Types.PlayerRecord): boolean
    return true
end

---- Initialization ----

function Definition.CreateEntity(Angle: Vector3, Position: Vector3): Types.Entity
    return setmetatable({
        Identifier = 0,
        Definition = Definition,
        ReplicationState = Enums.ReplicationState.DontSend,

        Components = {},
        Simulation = 1 :: any
    } :: any, Entity)
end

---- Connections ----

return Definition :: Types.EntityDefinition