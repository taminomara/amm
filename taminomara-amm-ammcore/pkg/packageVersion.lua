local class       = require "ammcore.util.class"
local packageBuilder = require "ammcore.pkg.packageBuilder"
local array          = require "ammcore.util.array"

local ns          = {}

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

    --- True if this package is already installed.
    ---
    --- @type boolean
    self.isInstalled = false

    --- Indicates that this version is installed in dev mode.
    ---
    --- @type boolean
    self.isDevMode = false

    --- Indicates that this is a broken version,
    --- and should not be considered for installation.
    ---
    --- Resolver marks versions as broken if they throw errors from `getRequirements`.
    ---
    --- @type boolean
    self.isBroken = false

    --- @private
    --- @type table<string, ammcore.pkg.version.VersionSpec>?
    self._allRequirements = nil

    return self
end

--- Get or fetch requirements for this version.
---
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.PackageVersion:getRequirements()
    error("not implemented")
end

--- Get or fetch dev requirements for this version.
---
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.PackageVersion:getDevRequirements()
    error("not implemented")
end

--- Download this package and return the package archive.
---
--- You can use results of this operation with package builder to unpack the archive.
---
--- @return string
function ns.PackageVersion:build()
    error("not implemented")
end

--- Download and install this package to the given directory.
---
--- @param packageRoot string
function ns.PackageVersion:install(packageRoot)
    local archive = self:build()
    local builder = packageBuilder.PackageArchiver:FromArchive(self.name, self.version, archive)
    builder:unpack(packageRoot)
end

--- Get or fetch requirements for this version. Add dev requirements
--- if this is a dev package.
---
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.PackageVersion:getAllRequirements()
    if not self._allRequirements then
        self._allRequirements = {}

        array.insertTable(self._allRequirements, self:getRequirements(), function (l, r)
            return l .. r
        end)

        if self.isDevMode then
            array.insertTable(self._allRequirements, self:getDevRequirements(), function (l, r)
                return l .. r
            end)
        end
    end

    return self._allRequirements
end

return ns
