--!strict
--!nolint LocalShadow

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

local Core = script.Parent
local Utility = Core.Utility

local Types = require(Core.Types)
local DrawUtility = require(Utility.Draw)
local MathUtility = require(Utility.Math)
local CollisionUtility = require(Utility.Collision)

---- Settings ----

local GROUND_OFFSET = Vector3.new(0, -0.2, 0)

export type Simulation = typeof(setmetatable({}, {})) & {
    --> Members
    Identifier: number,
    Camera: BasePart,

    Air: number,
    Jump: number,
    Step: number,
    Angle: Vector2,
    Position: Vector3,
    Velocity: Vector3,
    Radius: number,
    Height: number,
    MaxSpeed: number,
    MaxAirSpeed: number,
    MaxGroundAngle: number,
    TurnFraction: number,
    SpeedDecayFraction: number,
    JumpPower: number,
    JumpCooldown: number,
    Acceleration: number,
    AirAcceleration: number,
    Gravity: number,
    StepSize: Vector3,

    --> Methods
    new: (Identifier: number) -> Simulation,
    Simulate: (Simulation, Command: Types.Command) -> (),
    Traverse: (Simulation, Position: Vector3, Velocity: Vector3, DeltaTime: number) -> (Vector3, Vector3, CollisionUtility.Result?),
    IsGrounded: (Simulation, Position: Vector3) -> CollisionUtility.Result?,
}

---- Constants ----

local Simulation = {}
Simulation.__index = Simulation

---- Variables ----

---- Private Functions ----

local function TruncateVector(Vector: Vector3): string
    return string.format("%.4f, %.4f, %.4f", Vector.X, Vector.Y, Vector.Z)
end

---- Public Functions ----

function Simulation.new(Identifier: number): Simulation
    return setmetatable({
        Identifier = Identifier,
        Camera = DrawUtility.point(Vector3.zero, DrawUtility._defaultColor, workspace),

        --> State
        Air = 0,
        Jump = 0,
        Step = 0,
        Angle = Vector2.new(0, 0),
        Position = Vector3.new(0, 30, 0),
        Velocity = Vector3.zero,

        --> Properties (From new roblox controllers) & (Credits to chickynoid for some of these!)
        Radius = 1.5,
        Height = 1.5,
        MaxSpeed = 16,
        MaxAirSpeed = 16,
        MaxGroundAngle = math.rad(89),

        TurnFraction = 8,
        SpeedDecayFraction = 8,

        JumpPower = 50,
        JumpCooldown = 0.4,

        Acceleration = 10,
        AirAcceleration = 1,

        Gravity = -198,
        StepSize = Vector3.new(0, 2.2, 0),
    } :: any, Simulation)
end

-- selene: allow(shadowing)
function Simulation:Simulate(Command: Types.Command)
    --> State
    local self: Simulation = self
    local Velocity = self.Velocity
    local Position = self.Position
    local DeltaTime = Command.DeltaTime

    DrawUtility.clear()

    --> Ground
    local GroundSurface = self:IsGrounded(Position)

    --> Decay
    if self.Jump > 0 then
        self.Jump = math.max(self.Jump - DeltaTime, 0)
    end

    --> Movement
    local FlatVelocity = MathUtility.FlatVector(Velocity)
    local WishDirection = Vector3.new(Command.X, 0, Command.Z).Unit
    
    if WishDirection.Magnitude > 0 then
        FlatVelocity = MathUtility.Accelerate(
            FlatVelocity, 
            WishDirection, 
            GroundSurface and self.MaxSpeed or self.MaxAirSpeed, 
            GroundSurface and self.Acceleration or self.AirAcceleration, 
            DeltaTime
        )
    else
        FlatVelocity = MathUtility.VectorFriction(Velocity, self.SpeedDecayFraction, DeltaTime)
    end
    
    if GroundSurface then
        if Command.Y > 0 and self.Jump <= 0 then
            --> Preserve any vertical moment we already have
            Velocity += Vector3.new(0, self.JumpPower, 0)
            self.Jump = self.JumpCooldown
        end
    else
        Velocity += Vector3.new(0, self.Gravity * DeltaTime, 0)
    end
    
    --> Traverse world
    local TraversalResult: CollisionUtility.Result?;
    Velocity = Vector3.new(FlatVelocity.X, Velocity.Y, FlatVelocity.Z)
    Position, Velocity, TraversalResult = self:Traverse(Position, Velocity, DeltaTime)

    --> Did we land?
    if not GroundSurface and TraversalResult then
        GroundSurface = self:IsGrounded(Position)
        if GroundSurface then
            Velocity = MathUtility.FlatVector(Velocity)
        end
    end

    if TraversalResult then
        DrawUtility.point(TraversalResult.Position, nil, workspace.Terrain, 0.2)
    end

    --> Step Up
    if GroundSurface and TraversalResult and self.Jump <= 0 then
        local StepSize = self.StepSize
        FlatVelocity = MathUtility.FlatVector(Velocity)
        
        --> Is there anything blocking us overhead?
        local Ceiling = CollisionUtility.Capsule(Position, StepSize, self.Radius, self.Height)

        --> Is there enough space for us to fit on the step?
        local StepUpPosition, StepUpVelocity = self:Traverse(Ceiling and Ceiling.Position or (Position + StepSize), FlatVelocity, DeltaTime)

        --> "Step Down" on our new ground surface
        local StepUpGroundSurface = CollisionUtility.Capsule(StepUpPosition + Vector3.new(0, 0.1, 0), -StepSize, self.Radius, self.Height)
        
        --> Are we on the ground? Great! Otherwise do nothing!
        if StepUpGroundSurface then
            Position = StepUpGroundSurface.Position
            Velocity = StepUpVelocity
        end
    end

    --> Gizmos
    DrawUtility.capsule(Position, 1.5, 1.5)
    DrawUtility.ray(Position, Velocity)
    DrawUtility.ray(Position, WishDirection * self.MaxSpeed, Color3.new(0, 0, 1))
    DrawUtility.text(Position + Vector3.new(0, self.Height + 2, 0), `Position:{TruncateVector(Position)}\nVelocity:{TruncateVector(Velocity)}\nIsGrounded: {GroundSurface ~= nil}\nHitSomething:{TraversalResult~=nil}`)

    --> Update State
    self.Velocity = Velocity
    self.Position = Position
    self.Camera.Position = self.Position
end

-- selene: allow(shadowing)
function Simulation:Traverse(Position: Vector3, Velocity: Vector3, DeltaTime: number)
    local self: Simulation = self
    local Result: CollisionUtility.Result?;
    
    local Geometry = {}
    local StartVelocity = Velocity

    --> NOTE: Expose option to modify the maximum amount of steps
    for _ = 1, 5  do
        --> Is velocity completely reversed? (can happen when landing)
        if Velocity:Dot(StartVelocity) < 0 then
            Velocity = Vector3.zero
            break
        end

        local Direction = (Velocity * DeltaTime)
        local StepResult = CollisionUtility.Capsule(Position, Direction, self.Radius, self.Height)
        Position = StepResult and StepResult.Position or (Position + Direction)

        --> No collision
        if not StepResult then
            break
        end

        --> Collision
        Result = StepResult
        DeltaTime -= (DeltaTime * Result.Fraction)

        if not Geometry[Result.Instance] then
            Geometry[Result.Instance] = true
            Velocity = MathUtility.ClipVector(Velocity, Result.Normal)
        else
            Velocity += Result.Normal
            Position += Result.Normal * 0.1
        end
    end

    return Position, Velocity, Result
end

-- selene: allow(shadowing)
function Simulation:IsGrounded(Position: Vector3)
    local self: Simulation = self
    return CollisionUtility.Capsule(Position + Vector3.new(0, 0.1, 0), GROUND_OFFSET, self.Radius, self.Height)
end

---- Initialization ----

---- Connections ----

return Simulation