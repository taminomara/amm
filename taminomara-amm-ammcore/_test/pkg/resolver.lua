local resolver      = require "ammcore/pkg/resolver"
local test          = require "ammtest/index"
local provider      = require "ammcore/pkg/provider"
local class         = require "ammcore/util/class"
local localProvider = require "ammcore/pkg/providers/local"
local version       = require "ammcore/pkg/version"

local suite         = test.suite()

--- @class ammcore._test.pkg.resolver.TestProvider: ammcore.pkg.provider.Provider
local TestProvider  = class.create("TestProvider", provider.Provider)

--- @param packages table<string, table<string, {[string]: string, _local?: boolean}>>
---
--- @generic T: ammcore._test.pkg.resolver.TestProvider
--- @param self T
--- @return T
function TestProvider:New(packages)
    self = provider.Provider.New(self)

    --- @type table<string, ammcore.pkg.package.PackageVersion[]>
    self.packages = {}

    for name, versions in pairs(packages) do
        self.packages[name] = {}
        for ver, requirements in pairs(versions) do
            local pkg = localProvider.LocalPackageVersion:New(
                name, version.parse(ver), self, { name = name, version = ver }
            )
            pkg.isInstalled = requirements._local and true or false
            for reqName, spec in pairs(requirements) do
                if reqName ~= "_local" then
                    --- @diagnostic disable-next-line: param-type-mismatch
                    pkg.requirements[reqName] = version.parseSpec(spec)
                end
            end
            table.insert(self.packages[name], pkg)
        end
    end

    return self
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
end)

suite:case("prefer higher", function()
    local provider = TestProvider:New({
        baz = {
            ["1"] = {},
            ["2"] = {},
            ["3"] = {},
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider)
    checkResolved(res, { baz = "3" })
end)

suite:case("prefer local", function()
    local provider = TestProvider:New({
        baz = {
            ["1"] = {},
            ["2"] = { _local = true },
            ["3"] = {},
        },
    })

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider)
    checkResolved(res, { baz = "2" })
end)

suite:case("ok large", function()
end)

suite:case("ok exclusions", function()
end)

suite:case("ok middle", function()
end)

suite:case("ok unused tail", function()
    local provider = TestProvider:New({
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

    local res = resolver.resolve({ baz = version.parseSpec("*") }, provider)
    checkResolved(res, { baz = "1", foo = "1" })
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
    local provider = TestProvider:New({
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
    local provider = TestProvider:New({
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
