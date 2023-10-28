--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

local EPSILON = 1E-5

---- Constants ----

local Math = {
    EPSILON = EPSILON
}

---- Variables ----

---- Private Functions ----

---- Public Functions ----

function Math.Lerp(Value: number, Goal: number, Fraction: number): number
    return (Value + (Goal - Value) * Fraction)
end

function Math.Friction(Value: number, Friction: number, DeltaTime: number): number
    local Ratio = (1 / (1 + (DeltaTime * Friction)))
    return (Value * Ratio)
end

function Math.VectorFriction(Vector: Vector3, Friction: number, DeltaTime: number): Vector3
    local Value = Math.Friction(Vector.Magnitude, Friction, DeltaTime)
    if Value < EPSILON then
        return Vector3.zero
    end

    return Vector.Unit * Value
end

function Math.FlatVector(Vector: Vector3): Vector3
    return Vector3.new(Vector.X, 0, Vector.Z)
end

function Math.ClipVector(Vector: Vector3, Normal: Vector3): Vector3
    local Fraction = Vector:Dot(Normal)
    return (Vector - (Normal * Fraction))
end

function Math.Accelerate(Velocity: Vector3, WishDirection: Vector3, WishSpeed: number, Acceleration: number, DeltaTime: number): Vector3
    local Length = Velocity.Magnitude
    if Length > WishSpeed then
        Velocity = Velocity.Unit * WishSpeed
    end

    local WishVelocity = WishDirection * WishSpeed
    local ShoveDirection = WishVelocity - Velocity

    local ShoveSpeed = ShoveDirection.Magnitude
    local AccelerationSpeed = Acceleration * DeltaTime * WishSpeed

    if AccelerationSpeed > ShoveSpeed then
        AccelerationSpeed = ShoveSpeed
    end
    
    if AccelerationSpeed < EPSILON then
        return Velocity
    end

    return Velocity + (AccelerationSpeed * ShoveDirection.Unit)
end

---- Initialization ----

---- Connections ----

return Math