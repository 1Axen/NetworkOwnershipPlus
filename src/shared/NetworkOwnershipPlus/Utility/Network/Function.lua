--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

local Protocol = require(script.Parent.Protocol)
local Identifier = require(script.Parent.Identifier)

---- Settings ----

type Function<T..., A...> = {
    Identifier: string,
    Reliable: boolean,

    Validate: (...unknown) -> (T...),

    Listener: ((Player: Player, T...) -> (A...))?,
    Listen: (self: Function<T..., A...>, Listener: (Player: Player, T...) -> (A...)) -> (),

    InvokeServer: (self: Function<T..., A...>, T...) -> (A...),
}

type FunctionConstructorOptions<T...> = {
    Name: string,
    Validate: (...unknown) -> (T...)
}

---- Constants ----

local IsServer = RunService:IsServer()

---- Functions ----

local function InvokeServer<T..., A...>(self: Function<T..., A...>, ...: T...): (A...)
    assert(not IsServer, "InvokeServer can only be called from the client.")
    return Protocol.Client.InvokeFunction(self.Identifier, Identifier.GetUnique(), ...)
end

local function Listen<T..., A...>(self: Function<T..., A...>, Listener: (Player, T...) -> (A...)): ()
    assert(IsServer, "Listen can only be called from the server.")
    assert(self.Listener == nil, "Listener can only bet set once!")
    self.Listener = Listener
end

---- Constructor ----

return function<T..., A...>(Options: FunctionConstructorOptions<T...>): Function<T..., A...>
    local self: Function<T..., A...> = {
        Identifier = Identifier.GetShared(Options.Name),
        Reliable = true,
        Listener = false,

        Validate = Options.Validate,

        Listen = Listen,

        InvokeServer = InvokeServer
    } :: any

    if IsServer then
        Protocol.Server.SetListener(self.Identifier, function(Player: Player, InvocationIdentifier: string, ...: any)
            if type(InvocationIdentifier) ~= "string" then
                return
            end

            if not self.Listener then
                Protocol.Server.SendEvent(self.Identifier, true, Player, InvocationIdentifier, "Function has no listener.")
                return
            end
    
            if pcall(self.Validate, ...) then
                Protocol.Server.SendEvent(self.Identifier, true, Player, InvocationIdentifier, self.Listener(Player, ...))
            end
        end)
    end

    return self
end
