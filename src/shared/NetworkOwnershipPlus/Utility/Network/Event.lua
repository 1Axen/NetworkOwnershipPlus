--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

local Protocol = require(script.Parent.Protocol)

---- Settings ----

type Event<T...> = {
    Identifier: string,
    Reliable: boolean,

    Validate: (...unknown) -> (T...),

    Listener: boolean?,
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

---- Functions ----

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
    self.Listener = true
    Protocol.SetListener(self.Identifier, function(...)
        if pcall(self.Validate, ...) then
            Listener(...)
        end
    end)
end

---- Constructor ----

return function<T...>(Options: EventConstructorOptions<T...>): Event<T...>
    return {
        Identifier = Protocol.GetIdentifier(Options.Name),
        Reliable = not Options.Unreliable,
        Listener = false,

        Validate = Options.Validate,

        Listen = Listen,

        FireClient = FireClient,
        FireClients = FireClients,
        FireAllClients = FireAllClients,
        FireAllClientsExcept = FireAllClientsExcept,

        FireServer = FireServer
    } :: any
end
