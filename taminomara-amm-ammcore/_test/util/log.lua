local test = require "ammtest.index"
local log = require "ammcore.util.log"

local suite = test.suite("log")

function suite:setupTest()
    test.patch(_G, "AMM_LOG_LEVELS", {})
    test.patch(log, "_loggers", {})
end

suite:case("Default log setup", function()
    local l = log.Logger:New("foo")
    test.assertEq(l.name, "foo")
    test.assertNil(l:getLevel())
    test.assertEq(l:getEffectiveLevel(), log.Level.Info)

    test.assertEq(test.getLogStr(), "")
    l:critical("critical!")
    l:error("error!")
    l:warning("warning!")
    l:info("info!")
    l:debug("debug!")
    l:trace("trace!")
    test.assertEq(
    test.getLogStr(),
        "[foo] Critical: critical!\n"
        .. "[foo] Error: error!\n"
        .. "[foo] Warning: warning!\n"
        .. "[foo] Info: info!\n"
    )
end)

suite:case("Global log setup", function()
    AMM_LOG_LEVELS["foo"] = log.Level.Warning

    local l = log.Logger:New("foo")
    test.assertEq(l.name, "foo")
    test.assertEq(l:getLevel(), log.Level.Warning)
    test.assertEq(l:getEffectiveLevel(), log.Level.Warning)

    test.assertEq(test.getLogStr(), "")
    l:critical("critical!")
    l:error("error!")
    l:warning("warning!")
    l:info("info!")
    l:debug("debug!")
    l:trace("trace!")
    test.assertEq(
        test.getLogStr(),
        "[foo] Critical: critical!\n"
        .. "[foo] Error: error!\n"
        .. "[foo] Warning: warning!\n"
    )
end)

suite:case("Local log setup", function()
    local l = log.Logger:New("foo")
    test.assertEq(l.name, "foo")
    test.assertNil(l:getLevel())
    test.assertEq(l:getEffectiveLevel(), log.Level.Info)
    l:setLevel(log.Level.Warning)
    test.assertEq(l:getLevel(), log.Level.Warning)
    test.assertEq(l:getEffectiveLevel(), log.Level.Warning)

    test.assertEq(test.getLogStr(), "")
    l:critical("critical!")
    l:error("error!")
    l:warning("warning!")
    l:info("info!")
    l:debug("debug!")
    l:trace("trace!")
    test.assertEq(
        test.getLogStr(),
        "[foo] Critical: critical!\n"
        .. "[foo] Error: error!\n"
        .. "[foo] Warning: warning!\n"
    )
end)

suite:case("Log all levels", function()
    local l = log.Logger:New("foo")
    l:setLevel(log.Level.Trace)

    test.assertEq(test.getLogStr(), "")
    l:critical("critical!")
    l:error("error!")
    l:warning("warning!")
    l:info("info!")
    l:debug("debug!")
    l:trace("trace!")
    test.assertEq(
    test.getLogStr(),
        "[foo] Critical: critical!\n"
        .. "[foo] Error: error!\n"
        .. "[foo] Warning: warning!\n"
        .. "[foo] Info: info!\n"
        .. "[foo] Debug: debug!\n"
        .. "[foo] Trace: trace!\n"
    )
end)

suite:case("Parent logger", function()
    log.Logger:New("foo"):setLevel(log.Level.Warning)

    local l = log.Logger:New("foo.bar")
    test.assertEq(l.name, "foo.bar")
    test.assertNil(l:getLevel())
    test.assertEq(l:getEffectiveLevel(), log.Level.Warning)

    test.assertEq(test.getLogStr(), "")
    l:critical("critical!")
    l:error("error!")
    l:warning("warning!")
    l:info("info!")
    l:debug("debug!")
    l:trace("trace!")
    test.assertEq(
        test.getLogStr(),
        "[foo.bar] Critical: critical!\n"
        .. "[foo.bar] Error: error!\n"
        .. "[foo.bar] Warning: warning!\n"
    )
end)

suite:case("Parent logger override", function()
    log.Logger:New("foo"):setLevel(log.Level.Warning)

    local l = log.Logger:New("foo.bar")
    l:setLevel(log.Level.Info)
    test.assertEq(l.name, "foo.bar")
    test.assertEq(l:getLevel(), log.Level.Info)
    test.assertEq(l:getEffectiveLevel(), log.Level.Info)

    test.assertEq(test.getLogStr(), "")
    l:critical("critical!")
    l:error("error!")
    l:warning("warning!")
    l:info("info!")
    l:debug("debug!")
    l:trace("trace!")
    test.assertEq(
        test.getLogStr(),
        "[foo.bar] Critical: critical!\n"
        .. "[foo.bar] Error: error!\n"
        .. "[foo.bar] Warning: warning!\n"
        .. "[foo.bar] Info: info!\n"
    )
end)
