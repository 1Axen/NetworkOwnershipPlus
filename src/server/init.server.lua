--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkOwnershipPlus = ReplicatedStorage.NetworkOwnershipPlus

local Network = require(NetworkOwnershipPlus.Utility.Network)

local Empty = Network.Event({
    Name = "Empty",
    Unreliable = false,
    Validate = function()
        return
    end
})

local Complex = Network.Event({
    Name = "Complex",
    Unreliable = false,
    Validate = function(String, Number, Boolean)
        assert(type(String) == "string", "Expected string")
        assert(type(Number) == "number", "Expected number")
        assert(type(Boolean) == "boolean", "Expected boolean")
        return String, Number, Boolean
    end
})

local Function = Network.Function({
    Name = "Function",
    Validate = function(number)
        assert(typeof(number) == "number", "Expected number")
        return number
    end
})

Complex:SetServerListener(function(Player, string, number, boolean)
    
end)

Function:Listen(function(Player, number)
    return (number + 1)
end)

task.delay(5, function()
    print("FireAllClients")
    Empty:FireAllClients()
    Complex:FireAllClients("test", 1, true)
end)
