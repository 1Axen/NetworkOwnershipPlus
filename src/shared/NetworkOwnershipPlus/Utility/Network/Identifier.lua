---- Services ----

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Settings ----

local BYTE = (2^8)

---- Constants ----

local IsServer = RunService:IsServer()
local ReliableEvent: RemoteEvent = ReplicatedStorage:WaitForChild("ReliableConnection")

local Identifier = {}

---- Variables ----

local Shared = 0
local Unique = 0

---- Functions ----

function Identifier.GetShared(Name: string): string
    local Attribute = ReliableEvent:GetAttribute(Name)
    if IsServer then
        if not Attribute then
            Shared += 1
            Attribute = string.pack("B", Shared)
            ReliableEvent:SetAttribute(Name, Attribute)
        end
        
        return Attribute
    else
        while not Attribute do
            ReliableEvent.AttributeChanged:Wait()
            Attribute = ReliableEvent:GetAttribute(Name)
        end

        return Attribute
    end
end

function Identifier.GetUnique(): string
    Unique += 1

    if Unique == BYTE then
        Unique = 0
    end

    return string.pack("B", Unique)
end

return Identifier