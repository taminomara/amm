local class             = require "ammcore/util/class"

local ns                = {}

--- Represents a single package version.
---
--- @class ammcore.pkg.package.PackageVersion: class.Base
ns.PackageVersion = class.create("PackageVersion")

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param provider ammcore.pkg.provider.Provider
---
--- @generic T: ammcore.pkg.package.PackageVersion
--- @param self T
--- @return T
function ns.PackageVersion:New(name, version, provider)
    self = class.Base.New(self)

    --- Name of the package.
    ---
    --- @type string
    self.name = name

    --- Version of the package.
    ---
    --- @type ammcore.pkg.version.Version
    self.version = version

    --- Provider which found this version.
    ---
    --- @type ammcore.pkg.provider.Provider
    self.provider = provider

    --- True if provider has code for this package cached locally.
    ---
    --- @type boolean
    self.availableLocally = false

    --- Indicates that this version is installed in dev mode.
    ---
    --- @type boolean
    self.isDevMode = false

    return self
end

--- Get or fetch requirements for this version.
---
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.PackageVersion:getRequirements()
    error("Not implemented")
end

--- Get or fetch dev requirements for this version.
---
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.PackageVersion:getDevRequirements()
    error("Not implemented")
end

--- Return a table that can be serialized to `ammpackage.json`.
---
--- @return table
function ns.PackageVersion:serialize()
    local data = {
        version = tostring(self.version),
        requirements = {},
        devRequirements = {},
    }
    for name, spec in pairs(self:getRequirements()) do
        data.requirements[name] = tostring(spec)
    end
    for name, spec in pairs(self:getDevRequirements()) do
        data.devRequirements[name] = tostring(spec)
    end
    return data
end

return ns
