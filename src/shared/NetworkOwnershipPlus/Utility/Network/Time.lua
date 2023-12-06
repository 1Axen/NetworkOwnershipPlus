-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local RunService = game:GetService("RunService")

---- Imports ----

local Event = require(script.Parent.Event)
local Function = require(script.Parent.Function)

---- Settings ----

local FORCE_UPDATE_RATE = 5

---- Constants ----

local Time = {
    Ping = 0,
    Offset = -1,
    OneWayDelay = 0,
}

local IsServer = RunService:IsServer()

---- Variables ----

---- Private Functions ----

local function GetLocalTime()
    return os.clock()
end

---- Public Functions ----

function Time.GetSyncedTime(): number
    if IsServer then
        return GetLocalTime()
    end

    return (GetLocalTime() - Time.Offset)
end

---- Initialization ----

function Time.Start()
    local SyncEvent = Event({
        Name = "TimeSyncEvent",
        Unreliable = false,
        Validate = function()
            return
        end
    })

    local SyncFunction = Function({
        Name = "TimeSyncFunction",
        Validate = function(Number: unknown)
            assert(type(Number) == "number", "TimeSyncFunction expects a number.")
            return Number
        end
    })

    if IsServer then
        SyncEvent:Listen(function(Player: Player)
            SyncEvent:FireClient(Player, GetLocalTime())
        end)

        SyncFunction:Listen(function(_: Player, TimeThree: number)
            return (GetLocalTime() - TimeThree)
        end)

        task.delay(FORCE_UPDATE_RATE, function()
            while true do
                SyncEvent:FireAllClients(GetLocalTime())
                task.wait(FORCE_UPDATE_RATE)
            end
        end)
    else
        SyncEvent:Listen(function(TimeOne: number)
            local TimeTwo = GetLocalTime()
            local ServerClientDifference = TimeTwo - TimeOne

            local TimeThree = GetLocalTime()

            local StartTime = os.clock()
            local _, ClientServerDifference = SyncFunction:InvokeServer(TimeThree)

            Time.Ping = (os.clock() - StartTime)
            Time.Offset = (ServerClientDifference - ClientServerDifference) / 2
            Time.OneWayDelay = (ServerClientDifference + ClientServerDifference) / 2
        end)

        SyncEvent:FireServer()
    end
end

---- Connections ----

return Time
