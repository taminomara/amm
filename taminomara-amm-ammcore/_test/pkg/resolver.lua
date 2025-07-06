--- @namespace ammcore._test.pkg.resolver.

local resolver = require "ammcore.pkg.resolver"
local test = require "ammtest"
local provider = require "ammcore.pkg.provider"
local class = require "ammcore.class"
local localProvider = require "ammcore.pkg.providers.local"
local version = require "ammcore.pkg.version"

local suite = test.safeSuite()

--- @class TestProvider: ammcore.pkg.provider.Provider
local TestProvider = class.create("TestProvider", provider.Provider)

--- @param packages table<string, table<string, {[string]: string, _local?: boolean, _broken?: boolean}>>
function TestProvider:__init(packages)
    provider.Provider.__init(self)

    --- @type table<string, ammcore.pkg.package.PackageVersion[]>
    self.packages = {}

    for name, versions in pairs(packages) do
        self.packages[name] = {}
        for ver, requirements in pairs(versions) do
            local pkg = localProvider.LocalPackageVersion(
                name, version.parse(ver), { name = name, version = ver }, "/", "/"
            )
            pkg.isInstalled = requirements._local and true or false
            if requirements._broken then
                ---@diagnostic disable-next-line: duplicate-set-field
                pkg.getRequirements = function() error("broken", 0) end
            end
            for reqName, spec in pairs(requirements) do
                if reqName:sub(1, 1) ~= "_" then
                    pkg.requirements[reqName] = version.parseSpec(spec)
                end
            end
            table.insert(self.packages[name], pkg)
        end
    end
end

function TestProvider:findPackageVersions(name)
    if self.packages[name] then
        return self.packages[name], true
    else
        return {}, false
    end
end

--- @param got ammcore.pkg.package.PackageVersion[]
--- @param expected table<string, string>
local function checkResolved(got, expected)
    local gotVersions = {}
    for _, ver in ipairs(got) do
        gotVersions[ver.name] = ver.version
    end
    local expectedVersions = {}
    for name, ver in pairs(expected) do
        expectedVersions[name] = version.parse(ver)
    end
    test.assertDeepEq(gotVersions, expectedVersions)
end

suite:case("ok", function()
    local provider = TestProvider({
        baz = {
            ["1"] = {},
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, false, false)
    checkResolved(res, { baz = "1" })
end)

suite:case("ok unknown", function()
    local provider = TestProvider({
        foo = {
            ["1"] = { bar = "2" },
            ["2"] = { bar = "2", unknown = "1" },
        },
        bar = {
            ["1"] = {},
            ["2"] = {},
        },
        baz = {
            ["1"] = { foo = "*" },
            ["2"] = { foo = "*" },
            ["3"] = { foo = "*" },
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, false, false)
    checkResolved(res, { baz = "3", foo = "1", bar = "2" })
end)

suite:case("prefer higher", function()
    local provider = TestProvider({
        baz = {
            ["1"] = {},
            ["2"] = {},
            ["3"] = {},
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, false, false)
    checkResolved(res, { baz = "3" })
end)

suite:case("prefer local", function()
    local provider = TestProvider({
        baz = {
            ["1"] = {},
            ["2"] = { _local = true },
            ["3"] = {},
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, false, false)
    checkResolved(res, { baz = "2" })
end)

suite:case("prefer higher if update requested", function()
    local provider = TestProvider({
        baz = {
            ["1"] = {},
            ["2"] = { _local = true },
            ["3"] = {},
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, true, false)
    checkResolved(res, { baz = "3" })
end)

suite:case("ok large", function()
end)

suite:case("ok exclusions", function()
end)

suite:case("ok middle", function()
end)

suite:case("ok unused tail", function()
    local provider = TestProvider({
        foo = {
            ["1"] = {},
            ["2"] = { bar = "1" },
        },
        bar = {
            ["1"] = {},
        },
        baz = {
            ["1"] = { foo = "1" },
            ["2"] = { foo = "2", bar = "2" },
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, false, false)
    checkResolved(res, { baz = "1", foo = "1" })
end)

suite:case("ok broken", function()
    local provider = TestProvider({
        baz = {
            ["1"] = {},
            ["2"] = { _broken = true },
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, false, false)
    checkResolved(res, { baz = "1" })
end)

suite:case("ok broken dep", function()
    local provider = TestProvider({
        foo = {
            ["1"] = {},
            ["2"] = { _broken = true },
        },
        baz = {
            ["1"] = { foo = "*" },
            ["2"] = { foo = "*" },
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider, false, false)
    checkResolved(res, { baz = "2", foo = "1" })
end)

suite:case("broken", function()
    local provider = TestProvider({
        baz = {
            ["1"] = { _broken = true },
            ["2"] = { _broken = true },
        },
    })

    test.assertError(
        resolver.resolve,
        { { baz = version.parseSpec("*") }, provider },
        "Version baz == . can'be used because it was skipped"
    )
end)

suite:case("broken dep", function()
    local provider = TestProvider({
        foo = {
            ["1"] = { _broken = true },
            ["2"] = { _broken = true },
        },
        baz = {
            ["1"] = { foo = "*" },
        },
    })

    test.assertError(
        resolver.resolve,
        { { baz = version.parseSpec("*") }, provider },
        "Version foo == . can'be used because it was skipped"
    )
end)

suite:case("circular", function()
end)

suite:case("circular fail", function()
end)

suite:case("not found", function()
end)

suite:case("not found one", function()
end)

suite:case("conflict", function()
    local provider = TestProvider({
        foo = {
            ["1"] = { bar = "1" },
        },
        bar = {
            ["1"] = {},
            ["2"] = {},
        },
        baz = {
            ["1"] = { bar = ">=2", foo = "1" },
        },
    })

    test.assertError(
        resolver.resolve,
        { { baz = version.parseSpec("*") }, provider },
        "Can't find appropriate version for package bar"
    )
end)

suite:case("root requirements not satisfied", function()
    local provider = TestProvider({
        baz = {
            ["1"] = {},
            ["2"] = {},
        },
    })

    test.assertError(
        resolver.resolve,
        { { baz = version.parseSpec(">=3") }, provider },
        "Can't find appropriate version for package baz"
    )
end)
