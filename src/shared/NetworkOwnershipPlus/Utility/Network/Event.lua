--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

---- Settings ----

type Event<T...> = {
    Identifier: number,
    Reliable: boolean,

    Listener: ((...any) -> ())?,
    Listen: (self: Event<T...>, T...) -> (),

    FireClient: (self: Event<T...>, Player: Player, T...) -> (),
    FireClients: (self: Event<T...>, Players: {Player}, T...) -> (),
    FireAllClients: (self: Event<T...>, T...) -> (),
    FireAllClientsExcept: (self: Event<T...>, Player: Player, T...) -> (),

    FireServer: (self: Event<T...>, T...) -> (),
}

type EventConstructorOptions<T...> = {
    Name: string,
    Unreliable: boolean?,
    Validate: (...unknown) -> (T...)
}

---- Constants ----

---- Variables ----

---- Private Functions ----

---- Public Functions ----

local function FireClient<T...>(self: Event<T...>, Player: Player, ...: T...)
    assert(RunService:IsServer(), "FireClient can only be called from the server.")
end

local function FireClients<T...>(self: Event<T...>, Players: {Player}, ...: T...)
    assert(RunService:IsServer(), "FireClients can only be called from the server.")
end

local function FireAllClients<T...>(self: Event<T...>, ...: T...)
    assert(RunService:IsServer(), "FireAllClients can only be called from the server.")
end

local function FireAllClientsExcept<T...>(self: Event<T...>, Player: Player, ...: T...)
    assert(RunService:IsServer(), "FireAllClientsExcept can only be called from the server.")
end

local function FireServer<T...>(self: Event<T...>, ...: T...)
    assert(RunService:IsClient(), "FireServer can only be called from the client.")
end

local function Listen<T...>(self: Event<T...>, Listener: (T...) -> ())
    assert(self.Listener == nil, "Listener can only bet set once!")
    self.Listener = Listener
end

---- Initialization ----

local function Constructor<T...>(Options: EventConstructorOptions<T...>): Event
    return {
        
    }
end

---- Connections ----

return Constructor
