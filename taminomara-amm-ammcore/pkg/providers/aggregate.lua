local class = require "ammcore.util.class"
local provider = require "ammcore.pkg.provider"

local ns = {}

--- A provider that combines results from other providers.
---
--- @class ammcore.pkg.providers.aggregate.AggregateProvider: ammcore.pkg.provider.Provider
ns.AggregateProvider = class.create("AggregateProvider", provider.Provider)

--- @param providers ammcore.pkg.provider.Provider[]
---
--- @generic T: ammcore.pkg.providers.aggregate.AggregateProvider
--- @param self T|ammcore.pkg.providers.aggregate.AggregateProvider
--- @return T
function ns.AggregateProvider:New(providers)
    self = provider.Provider.New(self)

    --- @private
    --- @type ammcore.pkg.provider.Provider[]
    self._providers = providers

    return self
end

function ns.AggregateProvider:findPackageVersions(name)
    local versions, found = {}, false

    for _, provider in ipairs(self._providers) do
        local pVersions, pFound = provider:findPackageVersions(name)
        found = found or pFound
        for _, pVersion in ipairs(pVersions) do
            if pVersion.isDevMode then
                -- Dev mode always overrides other package versions.
                return {pVersion}, true
            end
            table.insert(versions, pVersion)
        end
    end

    return versions, found
end

return ns
