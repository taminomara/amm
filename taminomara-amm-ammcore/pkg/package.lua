--- @namespace ammcore.pkg.package

local class = require "ammcore.class"
local builder = require "ammcore.pkg.builder"
local fun = require "ammcore.fun"
local version = require("ammcore.pkg.version")

--- Data about available packages and their versions.
local ns = {}

--- Represents a single package version.
---
--- @class PackageVersion: ammcore.class.Base
ns.PackageVersion = class.create("PackageVersion")

--- @param name string package name.
--- @param version ammcore.pkg.version.Version package version.
function ns.PackageVersion:__init(name, version)
    --- Name of the package.
    ---
    --- @type string
    self.name = name

    --- Version of the package.
    ---
    --- @type ammcore.pkg.version.Version
    self.version = version

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
end

--- Get or fetch package metadata.
---
--- @return ammcore.pkg.packageJson.PackageJson package metadata.
function ns.PackageVersion:getMetadata()
    error("not implemented")
end

--- Get or fetch requirements for this version.
---
--- @return table<string, ammcore.pkg.version.VersionSpec> requirements production requirements for this version.
function ns.PackageVersion:getRequirements()
    error("not implemented")
end

--- Get or fetch dev requirements for this version.
---
--- @return table<string, ammcore.pkg.version.VersionSpec> devRequirements development requirements for this version.
function ns.PackageVersion:getDevRequirements()
    error("not implemented")
end

--- Get or fetch requirements for this version. Add dev requirements
--- if this is a dev package.
---
--- This function caches its results to avoid re-fetching requirements.
---
--- @return table<string, ammcore.pkg.version.VersionSpec> allRequirements all requirements for this version.
function ns.PackageVersion:getAllRequirements()
    if not self._allRequirements then
        self._allRequirements = {}

        fun.t.updateWith(self._allRequirements, self:getRequirements(), version.VersionSpec.concat)

        if self.isDevMode then
            fun.t.updateWith(self._allRequirements, self:getDevRequirements(), version.VersionSpec.concat)
        end
    end

    return self._allRequirements
end

--- Download this package and return the package archive.
---
--- You can use results of this operation with package builder to unpack the archive.
---
--- @return string archive package archive, see `ammcore.pkg.builder.PackageArchiver` for more info.
function ns.PackageVersion:build()
    error("not implemented")
end

--- Download and install this package to the given directory.
---
--- @param packageRoot string package installation directory, see `ammcore.pkg.builder.PackageArchiver.unpack` for more info.
function ns.PackageVersion:install(packageRoot)
    local archive = self:build()
    local builder = builder.PackageArchiver:FromArchive(self.name, self.version, archive)
    builder:unpack(packageRoot)
end

return ns
