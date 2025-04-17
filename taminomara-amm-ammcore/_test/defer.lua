local test = require "ammtest"
local defer = require "ammcore.defer"

local suite = test.safeSuite()

suite:case("xpcall success", function()
    local args
    local ok, err = defer.xpcall(
        function(...)
            args = { ... };

            --- @diagnostic disable-next-line: redundant-return-value
            return "ret"
        end,
        1, 2, 3
    )

    test.assertTrue(ok)
    test.assertEq(err, "ret")
    test.assertDeepEq(args, { 1, 2, 3 })
end)

suite:case("xpcall fail", function()
    local errValue = {}
    local ok, err = defer.xpcall(function() error(errValue) end)

    test.assertFalse(ok)
    test.assertTable(err)
    test.assertEq(err.message, errValue)
    test.assertString(err.trace)
end)

suite:case("defer", function()
    local called = false

    do
        local _<close> = defer.defer(function() called = true end)
        test.assertFalse(called)
    end

    test.assertTrue(called)
end)
