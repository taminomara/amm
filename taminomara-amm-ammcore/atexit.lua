local log = require "ammcore.log"
local defer = require "ammcore.defer"
local bootloader = require "ammcore.bootloader"

--- Register callbacks that run when computer shuts down.
---
--- !doctype module
--- @class ammcore.atexit
local ns = {}

local logger = log.Logger:New()

--- @type { callback: fun(), loc: string }[]
local callbacks = {}

local function runCallbacks()
    for i = #callbacks, 1, -1 do
        logger:trace("running atexit callback from %s", callbacks[i].loc)
        local ok, err = defer.xpcall(callbacks[i].callback)
        if not ok then
            logger:critical(
                "error when running atexit callback: %s\n%s\ncallback registered ad %s",
                err.message,
                err.trace,
                callbacks[i].loc
            )
        end
    end
end

local reset = computer.reset
local panic = computer.panic
local stop = computer.stop

--- Register a callback that will run before this computer shuts down.
---
--- Callbacks run in reverse order of their registration. Any errors in callbacks
--- are printed and ignored.
---
--- @param fn fun() a callback that will be invoked when computer shuts down.
function ns.register(fn)
    if type(fn) ~= "function" then
        error(string.format("expected a function, got %s", type(fn)))
    end

    local loc = bootloader.getLoc(2)
    logger:trace("registered atexit callback from %s", loc)
    table.insert(callbacks, { callback = fn, loc = loc })
end

--- Run the given function and stop the computer when it finishes,
--- making sure that all atexit callbacks fire before shutdown.
---
--- If function throws an error, `executeAndExit` will run all callbacks
--- and rethrow this error. For this reason, do not invoke this function
--- in a protected environment.
---
--- This function patches `computer.reset`, `computer.panic` and `computer.stop`
--- in order to guarantee that callbacks run in any case.
---
--- .. warning::
---
---    You don't need to use this function directly,
---    `ammcore.bin.main` will set everything up for you.
---
--- @param fn fun(...)
--- @param ... any
function ns.runAndExit(fn, ...)
    ---@diagnostic disable-next-line: duplicate-set-field
    computer.reset = function(...)
        pcall(runCallbacks)
        reset(...)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    computer.panic = function(...)
        pcall(runCallbacks)
        panic(...)
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    computer.stop = function(...)
        pcall(runCallbacks)
        stop(...)
    end

    local _ <close> = defer.defer(runCallbacks)
    fn(...)
    stop()
end

return ns
