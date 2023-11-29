--!strict
--!nolint LocalShadow 

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

local Utility = script.Utility

local Enums = require(script.Enums)
local Types = require(script.Types)

local Math = require(Utility.Math)
local Network = require(Utility.Network)
local Collision = require(Utility.Collision)
local Compression = require(Utility.Compression)

---- Constants ----

local DefaultSettings: Types.Settings = {
    UpdateRate = 0.05, --> 20 Times per second
    Interpolation = 0.1, --> 100 ms
    CommandBufferTime = (1 / 60), --> Keep commands in queue for 1 frame,
    CommandProcessingTime = 0.150 -- 150 ms
}

local NetworkOwnershipPlus = {}

---- Variables ----

local UserEntities: {[string]: Types.EntityDefinition} = {}

---- Private Functions ----

local function ShallowReconcile(Table, Base)
    for Key, Value in Base do
        Table[Key] = Table[Key] or Value
    end
end

---- Initialization ----

function NetworkOwnershipPlus.RegisterEntity(Entity: ModuleScript)
    local UserDefinition: Types.UserEntityDefinition = require(Entity) :: any
    local Serialized = table.clone(UserDefinition.Serialized)

    if Serialized.Identifier or Serialized.DefinitionIdentifier then
        error("Identifier & EntityIdentifier are reserved keys and cannot be used!")
    end

    Serialized.Identifier = Compression.Types.UnsignedShort
    Serialized.EntityIdentifier = Compression.Types.UnsignedByte

    local Definition: Types.EntityDefinition = {
        Name = UserDefinition.Name,
        Identifier = 0,
        Serialized = Serialized,
        CompressionTable = Compression.CreateCompressionTable(Serialized),

        CreateEntity = UserDefinition.CreateEntity,
    }

    UserEntities[Definition.Name] = Definition
end

function NetworkOwnershipPlus.RegisterEntitiesIn(Directory: Instance)
    for _, Child in Directory:GetChildren() do
        if Child:IsA("ModuleScript") then
            NetworkOwnershipPlus.RegisterEntity(Child)
        end
    end
end

function NetworkOwnershipPlus.Initialize(UserSettings: Types.Settings?)
    local Settings = UserSettings and table.clone(UserSettings) or DefaultSettings

    --> Only reconcile if user settings were provided   
    if UserSettings then
        ShallowReconcile(Settings, DefaultSettings)
    end

    --> Load contex
    if RunService:IsServer() then
        local Server = require(script.Server)

        Server.Initialize(Settings, UserEntities) 
        NetworkOwnershipPlus.Server = Server
    else
        local Client = require(script.Client)

        Client.Initialize(Settings, UserEntities)
        NetworkOwnershipPlus.Client = Client
    end
end

return NetworkOwnershipPlus