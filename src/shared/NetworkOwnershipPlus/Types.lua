--> The purpose of this module is to define the base types and their functions
--> The idea is for these types to have standard known behaviour that the system can use to reason about them
--> While also allowing developers to extend their behaviour using their own types that inherit from the base types
--> Take a look at the character entity for an example

--> Personal rant incoming, skip ahead if you aren't interested !!!
--> I hate pointless getters/setters that wrap around index operations
--> and add absolutely nothing of value other than making the code a slight bit slower (ITS NOT THAT SLOW BUT STILL)
--> I think it's really pointless to have something like :GetPosition() that just returns self.Position
--> Just index it!!!! It would be fine if it had some sort of custom behaviour attached to it like with some of these getters/setters
--> Otherwise it's just getters/setters for the sake of getters/setters
--> It also doesn't fit with the way the ROBLOX API is structured (at least most of it)
--> If you are trying to get the position of a part you would do Part.Position not Part:GetPosition()
--> Now think to something like Instance:GetAttribute()/SetAttribute() which are interacting with the Attributes system
--> Thus requiring custom behaviour otherwise you would have issues where Instance.ATTRIBUTE_NAME would result in undefined behaviour
--> If ATTRIBUTE_NAME was also the name of a child of Instance, should it return the child or the value of the attribute, who knows?

---- Imports ----

local Package = script.Parent
local Utility = Package.Utility

local Compression = require(Utility.Compression)

---- Types ----

--> SUPER & PARTIAL TYPES

export type UserEntityDefinition = {
    --> Members
    Name: string,
    Serialized: {[string]: string},

    --> Methods
    CreateEntity: (Angle: Vector3, Position: Vector3) -> Entity,
}

--> PUBLIC TYPES

export type Settings = {
    UpdateRate: number,
    Interpolation: number,
    CommandBufferTime: number,
    CommandProcessingTime: number
}

export type Event = {
    Type: number,
    Time: number,
    Frame: number,
    Player: PlayerRecord?,
}

export type Command = Event & {
    Entity: number,

    --> Input
    X: number,
    Y: number,
    Z: number,

    --> Simulation
    DeltaTime: number,
}

type ReplicationRecord = {
    Frame: number,
    Layout: any,
}

export type PlayerRecord = {
    Slot: number,
    UserId: number,
    Player: Player,

    Entities: {Entity},
    Replication: {[number]: ReplicationRecord},

    Commands: {Command},

    --> Replication State
    SendFullWorldSnapshot: boolean,
}

export type Component = {
    Entity: Entity,
    Identifier: number,

    --> Server Methods
    ServerInitialize: (Component) -> (),
    ServerProcessEvent: (Component, Event: Event) -> (),
    ServerStep: (Component, DeltaTime: number) -> (),
    ServerDestroy: (Component) -> (),

    --> Client Methods
    ClientInitialize: (Component) -> (),
    ClientProcessEvent: (Component, Event: Event) -> (),
    ClientStep: (Component, DeltaTime: number) -> (),
    ClientDestroy: (Component) -> (),
}

export type Entity = {
    Identifier: number,
    Definition: EntityDefinition,
    ReplicationState: number,

    --> Ownership
    Owner: PlayerRecord?,

    --> Components
    Components: {Component},
    Simulation: Simulation,

    --> Shared methods
    SetAngle: (Entity, Angle: Vector3) -> (), 
    SetPosition: (Entity, Position: Vector3) -> (),

    --> Client methods
    ClientStep: (Entity, DeltaTime: number) -> (),
    ClientProcessEvent: (Entity, Event: Event) -> (),
    ClientDestroy: (Entity) -> (),

    --> Server methods
    ServerStep: (Entity, DeltaTime: number) -> (),
    ServerProcessEvent: (Entity, Event: Event) -> (),
    ServerDestroy: (Entity) -> (),

    --> Server network methods
    Serialize: (Entity) -> {[string]: Compression.SupportedValues},
    SetNetworkOwner: (Entity, Owner: Player?) -> (),
    ShouldReplicate: (Entity, Player: PlayerRecord) -> boolean,
}

export type Simulation = {
    Angle: Vector3,
    Position: Vector3,
    Velocity: Vector3,

    Rendered: RenderedEntity,

    Step: (Simulation, Command: Command) -> (),
    SetAngle: (Entity, Angle: Vector3, Instant: boolean?) -> (), 
    SetPosition: (Entity, Position: Vector3, Instant: boolean?) -> (),
}

--> Special variation of the entity holding the replicated & rendered data of the entity
--> Think of "CharacterData" in Chickynoid
export type RenderedEntity = {
    --> Current
    Angle: Vector3,
    Position: Vector3,

    --> Target
    TargetAngle: Vector3,
    TargetPosition: Vector3,

    Interpolate: (RenderedEntity, Fraction: number) -> (),
}

--> This is what you should pass into RegisterEntity
export type EntityDefinition = UserEntityDefinition & {
    Identifier: number,
    CompressionTable: Compression.CompressionTable,
}

return {}