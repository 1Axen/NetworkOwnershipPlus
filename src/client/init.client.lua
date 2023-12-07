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
    Validate = function(String: unknown, Number: unknown, Boolean: unknown)
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

Empty:Listen(function()
    print("Empty event!")
end)

Complex:Listen(function(string, number, boolean)
    print(`Complex event: {string} {number} {boolean}`)
end)

print(Function:InvokeServer(1))
print(Network.Time.GetSyncedTime())