local test = require "ammtest"
local log = require "ammcore.log"
local bootloader = require "ammcore.bootloader"

local suite = test.safeSuite()

function suite:setupTest()
    local config = bootloader.getBootloaderConfig()
    test.patch(config, "logLevels", {})
end

suite:caseParams(
    "Level from name",
    {
        test.param(0, 0),
        test.param(100, 100),
        test.param("100", 100),
        test.param("Trace", 0),
        test.param("TRACE", 0),
        test.param("trace", 0),
        test.param("Debug", 100),
        test.param("DEBUG", 100),
        test.param("debug", 100),
        test.param("dbg", 100),
        test.param("Info", 200),
        test.param("INFO", 200),
        test.param("info", 200),
        test.param("Warning", 300),
        test.param("WARNING", 300),
        test.param("warning", 300),
        test.param("warn", 300),
        test.param("Error", 400),
        test.param("ERROR", 400),
        test.param("error", 400),
        test.param("err", 400),
        test.param("Critical", 500),
        test.param("CRITICAL", 500),
        test.param("critical", 500),
        test.param("crit", 500),
        test.param(-100, nil),
        test.param("-100", nil),
        test.param("10.5", nil),
        test.param("foobar", nil),
    },
    function(name, level)
        test.assertEq(log.levelFromName(name), level)
    end
)

suite:case("Default log setup", function()
    local l = log.getLogger("foo")
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
        "[foo] CRITICAL: critical!\n"
        .. "[foo] ERROR: error!\n"
        .. "[foo] WARNING: warning!\n"
        .. "[foo] INFO: info!\n"
    )
end)

suite:case("Global log setup", function()
    bootloader.getBootloaderConfig().logLevels["foo"] = log.Level.Warning

    local l = log.getLogger("foo")
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
        "[foo] CRITICAL: critical!\n"
        .. "[foo] ERROR: error!\n"
        .. "[foo] WARNING: warning!\n"
    )
end)

suite:case("Local log setup", function()
    local l = log.getLogger("foo")
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
        "[foo] CRITICAL: critical!\n"
        .. "[foo] ERROR: error!\n"
        .. "[foo] WARNING: warning!\n"
    )
end)

suite:case("Log all levels", function()
    local l = log.getLogger("foo")
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
        "[foo] CRITICAL: critical!\n"
        .. "[foo] ERROR: error!\n"
        .. "[foo] WARNING: warning!\n"
        .. "[foo] INFO: info!\n"
        .. "[foo] DEBUG: debug!\n"
        .. "[foo] TRACE: trace!\n"
    )
end)

suite:case("Parent logger", function()
    log.getLogger("foo"):setLevel(log.Level.Warning)

    local l = log.getLogger("foo.bar")
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
        "[foo.bar] CRITICAL: critical!\n"
        .. "[foo.bar] ERROR: error!\n"
        .. "[foo.bar] WARNING: warning!\n"
    )
end)

suite:case("Parent logger override", function()
    log.getLogger("foo"):setLevel(log.Level.Warning)

    local l = log.getLogger("foo.bar")
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
        "[foo.bar] CRITICAL: critical!\n"
        .. "[foo.bar] ERROR: error!\n"
        .. "[foo.bar] WARNING: warning!\n"
        .. "[foo.bar] INFO: info!\n"
    )
end)
