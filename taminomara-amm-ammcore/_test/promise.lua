local test = require "ammtest"
local promise = require "ammcore.promise"

local suite = test.suite()

suite:case("promise", function ()
    local p, r = promise.promise()
    test.assertFalse(p:canGet())
    r(1, 2, 3)
    test.assertTrue(p:canGet())
    test.assertDeepEq({ p:get() }, { 1, 2, 3 })
end)

suite:case("event", function ()
    local e = promise.Event:New()
    test.assertFalse(e:isSet())
    test.assertFalse(e:future():canGet())
    e:set()
    test.assertTrue(e:isSet())
    test.assertTrue(e:future():canGet())
    test.assertNil(e:future():get())
    e:reset()
    test.assertFalse(e:isSet())
    test.assertFalse(e:future():canGet())
end)

suite:case("event-mt", function ()
    local e = promise.Event:New()

    local reader = function ()
        e:await()
        print("read")
    end

    local writer = function ()
        print("write")
        e:set()
    end

    future.addTask(async(reader))
    future.addTask(async(reader))
    future.addTask(async(writer))
    future.addTask(async(reader))
    future.addTask(async(reader))

    while future.run() do end

    test.assertEq(test.getLogStr(), "")
end)
