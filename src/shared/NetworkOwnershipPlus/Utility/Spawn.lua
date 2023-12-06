-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Settings ----

local THREAD_LIFETIME = 120
local THREADS_ALLOCATED = 20

---- Variables ----

local Threads: {thread} = table.create(THREADS_ALLOCATED)

---- Functions ----

local function Call<T...>(Closure: (T...) -> (), ...: T...)
    --> Get free thread from pool
    local Thread = table.remove(Threads, #Threads)

    --> Run closure and recycle thread
    Closure(...)
    table.insert(Threads, Thread)
end

local function Yield()
    while true do
        Call(coroutine.yield())
    end
end

local function Create()
    local Thread: thread?
    Thread = coroutine.create(Yield)

    if #Threads > THREADS_ALLOCATED then
        
        task.delay(THREAD_LIFETIME, function()
            local Index = table.find(Threads, Thread :: thread)
            if Index then
                table.remove(Threads, Index)
            end

            Thread = nil
        end)
    end

    coroutine.resume(Thread :: thread)
    table.insert(Threads, Thread :: thread)
end

--> Allocate THREADS_ALLOCATED threads

for _ = 1, THREADS_ALLOCATED do
    Create()
end

return function<T...>(Closure: (T...) -> (), ...: T...)
    if #Threads == 0 then
        Create()
    end

    task.spawn(Threads[#Threads], Closure, ...)
end
