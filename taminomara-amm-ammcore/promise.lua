local class = require "ammcore.class"

--- Promise and synchronization primitives.
---
--- !doctype module
--- @class ammcore.promise
local ns = {}

--- Create a promise and a function to resolve it.
---
--- @return Future promise
--- @return fun(...) resolve
function ns.promise()
    local v = {}

    local promise = async(function()
        while not v.val do
            coroutine.yield(nil)
        end
        return table.unpack(v.val)
    end)

    local resolve = function(...)
        if v.val then
            error("this promise is already resolved")
        end

        v.val = { ... }

        promise:poll()
    end

    return promise, resolve
end

--- The simplest synchronization primitive: one thread signals an event
--- and another threads wait for it.
---
--- `Event` can be though of as having an internal flag. One thread
--- can set this to `true` using the `set` method. Another thread
--- can wait for the flag to become `true` using the `await` method.
---
--- Initially, flag starts as `false`.
---
--- @class ammcore.promise.Event: ammcore.class.Base
ns.Event = class.create("Event")

--- !doctype classmethod
--- @generic T: ammcore.promise.Event
--- @param self T
--- @return T
function ns.Event:New()
    self = class.Base.New(self)

    --- @private
    self._promise, self._resolve = ns.promise()

    return self
end

--- Set the event flag to `false`.
---
--- Threads that call `await` after the event was reset
function ns.Event:reset()
    if self:isSet() then
        self._promise, self._resolve = ns.promise()
    end
end

--- Set the event flag to `true`.
---
--- All threads waiting for it to become true are awakened.
--- Threads that call `await` once the flag is true will not block at all.
function ns.Event:set()
    if not self:isSet() then
        self._resolve(nil)
    end
end

--- Get the event flag.
---
--- @return boolean isSet
function ns.Event:isSet()
    return self._promise:canGet()
end

--- Wait for the event flag to become `true`.
function ns.Event:await()
    self._promise:await()
end

--- Get a future that resolves when the event flag becomes `true`.
---
--- @return Future
function ns.Event:future()
    return self._promise
end

return ns
