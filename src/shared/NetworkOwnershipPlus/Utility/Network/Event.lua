--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

---- Imports ----

local Protocol = require(script.Parent.Protocol)
local Identifier = require(script.Parent.Identifier)

---- Settings ----

type Event<T...> = {
    Identifier: string,
    Reliable: boolean,

    Validate: (...unknown) -> (T...),

    Listener: ((T...) -> ())?,
    Listen: (self: Event<T...>, Listener: (T...) -> ()) -> (),

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

local IsServer = RunService:IsServer()

---- Functions ----

local function FireClient<T...>(self: Event<T...>, Player: Player, ...: T...)
    assert(IsServer, "FireClient can only be called from the server.")
    Protocol.Server.SendEvent(self.Identifier, self.Reliable, Player, ...)
end

local function FireClients<T...>(self: Event<T...>, Clients: {Player}, ...: T...)
    assert(IsServer, "FireClients can only be called from the server.")
    for _, Player in Clients do
        Protocol.Server.SendEvent(self.Identifier, self.Reliable, Player, ...)
    end
end

local function FireAllClients<T...>(self: Event<T...>, ...: T...)
    assert(IsServer, "FireAllClients can only be called from the server.")
    for _, Player in Players:GetPlayers() do
        Protocol.Server.SendEvent(self.Identifier, self.Reliable, Player, ...)
    end
end

local function FireAllClientsExcept<T...>(self: Event<T...>, Except: Player, ...: T...)
    assert(IsServer, "FireAllClientsExcept can only be called from the server.")
    for _, Player in Players:GetPlayers() do
        if Player == Except then
            continue
        end

        Protocol.Server.SendEvent(self.Identifier, self.Reliable, Player, ...)
    end
end

local function FireServer<T...>(self: Event<T...>, ...: T...)
    assert(not IsServer, "FireServer can only be called from the client.")
    Protocol.Client.SendEvent(self.Identifier, self.Reliable, ...)
end

local function Listen<T...>(self: Event<T...>, Listener: (T...) -> ())
    assert(self.Listener == nil, "Listener can only bet set once!")
    self.Listener = Listener
end

---- Constructor ----

return function<T...>(Options: EventConstructorOptions<T...>): Event<T...>
    local self: Event<T...> = {
        Identifier = Identifier.GetShared(Options.Name),
        Reliable = not Options.Unreliable,
        
        Listen = Listen,
        Validate = Options.Validate,

        FireClient = FireClient,
        FireClients = FireClients,
        FireAllClients = FireAllClients,
        FireAllClientsExcept = FireAllClientsExcept,

        FireServer = FireServer
    } :: any

    if IsServer then
        Protocol.Server.SetListener(self.Identifier, function(...)
            if self.Listener and pcall(self.Validate, ...) then
                self.Listener(...)
            end
        end)
    else
        Protocol.Client.SetListener(self.Identifier, function(...)
            if self.Listener and pcall(self.Validate, ...) then
                self.Listener(...)
            end
        end)
    end

    return self
end
