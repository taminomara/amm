--- @namespace ammcore.pkg.providers.local

local class = require "ammcore.class"
local provider = require "ammcore.pkg.provider"
local packageJson = require "ammcore.pkg.packageJson"
local packageName = require "ammcore.pkg.packageName"
local package = require "ammcore.pkg.package"
local builder = require "ammcore.pkg.builder"
local json = require "ammcore._contrib.json"
local fsh = require "ammcore.fsh"

local ns = {}

--- Package version that was found on the hard drive.
---
--- @class LocalPackageVersion: ammcore.pkg.package.PackageVersion
ns.LocalPackageVersion = class.create("LocalPackageVersion", package.PackageVersion)

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param data ammcore.pkg.packageJson.PackageJson
--- @param installationRoot string
--- @param packageRoot string
function ns.LocalPackageVersion:__init(name, version, data, installationRoot, packageRoot)
    package.PackageVersion.__init(self, name, version)

    self.isInstalled = true

    --- Requirements parsed from local storage.
    ---
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self.requirements = {}

    --- Dev requirements parsed from local storage.
    ---
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self.devRequirements = {}

    --- Raw package data.
    ---
    --- @type ammcore.pkg.packageJson.PackageJson
    self.data = data

    --- Root directory containing all packages.
    ---
    --- @type string
    self.installationRoot = installationRoot

    --- Root directory of the package.
    ---
    --- @type string
    self.packageRoot = packageRoot
end

--- Override package version with a new one.
---
--- @param ver ammcore.pkg.version.Version
function ns.LocalPackageVersion:overrideVersion(ver)
    self.version = ver
    self.data.version = tostring(ver)
end

function ns.LocalPackageVersion:getMetadata()
    return self.data
end

function ns.LocalPackageVersion:getRequirements()
    return self.requirements
end

function ns.LocalPackageVersion:getDevRequirements()
    return self.devRequirements
end

function ns.LocalPackageVersion:build()
    local builder = builder.PackageBuilder(
        self.name, self.version, self.installationRoot, self.packageRoot
    )

    builder:copyDir(self.packageRoot, ".", true)
    if self.isDevMode then
        local buildScript = self.data._buildScript
        if buildScript then
            builder:runBuildScript(buildScript)
        end
        builder:addFile(".ammpackage.json", json.encode(self.data), true)
    end

    return builder:build()
end

--- Implements a provider that loads packages from a directory
--- (usually `/.amm/packages` or `/`).
---
--- @class LocalProvider: ammcore.pkg.provider.Provider
ns.LocalProvider = class.create("LocalProvider", provider.Provider)

--- @param root string
--- @param isDev boolean
function ns.LocalProvider:__init(root, isDev)
    provider.Provider.__init(self)

    --- @private
    --- @type string
    self._root = root

    --- @private
    --- @type table<string, ammcore.pkg.package.PackageVersion>
    self._packages = {}

    if filesystem.exists(root) then
        for _, name in ipairs(filesystem.children(root)) do
            local nameIsValid = packageName.parseFullPackageName(name)
            local path = filesystem.path(root, name)
            local pkgPath = filesystem.path(path, ".ammpackage.json")
            if nameIsValid and filesystem.isDir(path) and filesystem.exists(pkgPath) then
                local ver, requirements, devRequirements, data = packageJson.parseFromFile(pkgPath)
                if data.name ~= name then
                    error(string.format("package name from %s doesn't match the directory name", pkgPath), 0)
                end
                local pkg = ns.LocalPackageVersion(name, ver, data, root, path)
                pkg.requirements = requirements
                pkg.devRequirements = devRequirements
                pkg.isDevMode = isDev
                self._packages[name] = pkg
            end
        end
    end
end

--- @return LocalPackageVersion[]
function ns.LocalProvider:getLocalPackages()
    local pkgs = {}
    for _, pkg in pairs(self._packages) do
        table.insert(pkgs, pkg)
    end
    return pkgs
end

--- @param name string
--- @param includeRemotePackages boolean
--- @return LocalPackageVersion[]
--- @return boolean
function ns.LocalProvider:findPackageVersions(name, includeRemotePackages)
    local pkg = self._packages[name]
    if pkg then
        return { pkg }, true
    else
        return {}, false
    end
end

return ns
