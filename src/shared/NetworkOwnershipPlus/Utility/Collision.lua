--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

local Utility = script.Parent
local Draw = require(Utility.Draw)

---- Settings ----

local RAYCAST_FILTER = RaycastParams.new()
RAYCAST_FILTER.IgnoreWater = true
RAYCAST_FILTER.RespectCanCollide = true

export type Result = {
    Normal: Vector3,
    Position: Vector3,
    Fraction: number,
    Distance: number,
    Instance: Instance,
    Material: Enum.Material,
}

---- Constants ----

local Collision = {}

---- Variables ----

---- Private Functions ----

---- Public Functions ----

-- selene: allow(unused_variable)
--[[function Collision.Capsule(Origin: Vector3, Direction: Vector3, Radius: number, Height: number): Result?
    --> 3 Spheres form our "Capsule"
    for Index = 1, -1, -1 do
        local Offset = Vector3.new(0, Radius * Index, 0)
        local Result = workspace:Spherecast(Origin + Offset, Radius, Direction, RAYCAST_FILTER)
        if Result then
            return {
                Normal = Result.Normal,
                Position = (Origin + Vector3.new(0, Radius * (Index + 1) , 0)) + (Direction.Unit * Result.Distance),
                Fraction = (Result.Distance / Direction.Magnitude),
                Distance = Result.Distance,
                Instance = Result.Instance,
                Material = Result.Material,
            }
        end
    end

    --> This is annoying
    return
end]]

function Collision.Capsule(Origin: Vector3, Direction: Vector3): Result?
    local Result = workspace:Blockcast(CFrame.new(Origin), Vector3.new(2, 5, 2), Direction, RAYCAST_FILTER)
    if Result then
        return {
            Normal = Result.Normal,
            Position = Origin + (Direction.Unit * Result.Distance),
            Fraction = (Result.Distance / Direction.Magnitude),
            Distance = Result.Distance,
            Instance = Result.Instance,
            Material = Result.Material,
        }
    end

    return
end

---- Initialization ----

---- Connections ----

return Collision