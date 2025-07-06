--- @namespace ammcore.pkg.providers.aggregate

local class = require "ammcore.class"
local provider = require "ammcore.pkg.provider"
local fun = require "ammcore.fun"

local ns = {}

--- A provider that combines results from other providers.
---
--- @class AggregateProvider: ammcore.pkg.provider.Provider
ns.AggregateProvider = class.create("AggregateProvider", provider.Provider)

--- @param providers ammcore.pkg.provider.Provider[]
function ns.AggregateProvider:__init(providers)
    provider.Provider.__init(self)

    --- @private
    --- @type ammcore.pkg.provider.Provider[]
    self._providers = providers
end

--- @return ammcore.pkg.package.PackageVersion[]
function ns.AggregateProvider:getLocalPackages()
    local pkgs = {}
    for _, provider in ipairs(self._providers) do
        fun.a.extend(pkgs, provider:getLocalPackages())
    end
    return pkgs
end

--- @param name string
--- @param includeRemotePackages boolean
--- @return ammcore.pkg.providers.local.LocalPackageVersion[]
--- @return boolean
function ns.AggregateProvider:findPackageVersions(name, includeRemotePackages)
    local versions, found = {}, false

    for _, provider in ipairs(self._providers) do
        local pVersions, pFound = provider:findPackageVersions(name, includeRemotePackages)
        found = found or pFound
        for _, pVersion in ipairs(pVersions) do
            if pVersion.isDevMode then
                -- Dev mode always overrides other package versions.
                return { pVersion }, true
            end
            table.insert(versions, pVersion)
        end
    end

    return versions, found
end

function ns.AggregateProvider:finalize()
    for _, provider in ipairs(self._providers) do
        provider:finalize()
    end
end

return ns
