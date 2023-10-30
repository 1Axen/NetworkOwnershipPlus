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
local MathUtility = require(Utility.Math)
local NetworkUtility = require(Utility.Network)
local CollisionUtility = require(Utility.Collision)
local CompressionUtility = require(Utility.Compression)

---- Constants ----

local NetworkOwnershipPlus = {
    Enums = Enums,

    Math = MathUtility,
    Network = NetworkUtility,
    Collision = CollisionUtility,
    Compression = CompressionUtility
}

---- Initialization ----

if RunService:IsServer() then
    local Server = require(script.Server)

    Server.Initialize()
    NetworkOwnershipPlus.Server = Server
else
    local Client = require(script.Client)

    Client.Initialize()
    NetworkOwnershipPlus.Client = Client
end

return NetworkOwnershipPlus