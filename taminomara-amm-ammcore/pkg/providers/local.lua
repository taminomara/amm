local class = require "ammcore.util.class"
local provider = require "ammcore.pkg.provider"
local ammPackageJson = require "ammcore.pkg.packageJson"
local packageName = require "ammcore.pkg.packageName"
local package = require "ammcore.pkg.packageVersion"
local builder = require "ammcore.pkg.builder"
local json = require "ammcore.contrib.json"

--- Local package provider.
local ns = {}

--- Package version that was found on the hard drive.
---
--- @class ammcore.pkg.providers.local.LocalPackageVersion: ammcore.pkg.package.PackageVersion
ns.LocalPackageVersion = class.create("LocalPackageVersion", package.PackageVersion)

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param provider ammcore.pkg.providers.local.LocalProvider
--- @param data ammcore.pkg.ammPackageJson.AmmPackageJson
--- @param installationRoot string
--- @param packageRoot string
---
--- @generic T: ammcore.pkg.providers.local.LocalPackageVersion
--- @param self T
--- @return T
function ns.LocalPackageVersion:New(name, version, provider, data, installationRoot, packageRoot)
    self = package.PackageVersion.New(self, name, version, provider)

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
    --- @type ammcore.pkg.ammPackageJson.AmmPackageJson
    self.data = data

    --- Root directory containing all packages.
    ---
    --- @type string
    self.installationRoot = installationRoot

    --- Root directory of the package.
    ---
    --- @type string
    self.packageRoot = packageRoot

    return self
end

--- Override package version with a new one.
---
--- @param ver ammcore.pkg.version.Version
function ns.LocalPackageVersion:overrideVersion(ver)
    self.version = ver
    self.data.version = tostring(ver)
end

function ns.LocalPackageVersion:getRequirements()
    return self.requirements
end

function ns.LocalPackageVersion:getDevRequirements()
    return self.devRequirements
end

function ns.LocalPackageVersion:build()
    local builder = builder.PackageBuilder:New(
        self.name, self.version, self.installationRoot, self.packageRoot
    )

    builder:copyDir(self.packageRoot, ".", true)
    if self.isDevMode then
        builder:addFile(".ammpackage.json", json.encode(self.data), true)
    end

    return builder:build()
end

--- Implements a provider that loads packages from a directory
--- (usually `/.amm/packages` or `/`).
---
--- @class ammcore.pkg.providers.local.LocalProvider: ammcore.pkg.provider.Provider
ns.LocalProvider = class.create("LocalProvider", provider.Provider)

--- @param root string
--- @param isDev boolean
---
--- @generic T: ammcore.pkg.providers.local.LocalProvider
--- @param self T
--- @return T
function ns.LocalProvider:New(root, isDev)
    self = provider.Provider.New(self)

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
                local ver, requirements, devRequirements, data = ammPackageJson.parseFromFile(pkgPath)
                if data.name ~= name then
                    error(string.format("package name from %s doesn't match the directory name", pkgPath), 0)
                end
                local pkg = ns.LocalPackageVersion:New(name, ver, self, data, root, path)
                pkg.requirements = requirements
                pkg.devRequirements = devRequirements
                pkg.isDevMode = isDev
                self._packages[name] = pkg
            end
        end
    end

    return self
end

--- @return ammcore.pkg.providers.local.LocalPackageVersion[]
function ns.LocalProvider:getLocalPackages()
    local pkgs = {}
    for _, pkg in pairs(self._packages) do
        table.insert(pkgs, pkg)
    end
    return pkgs
end

--- @param name string
--- @param includeRemotePackages boolean
--- @return ammcore.pkg.providers.local.LocalPackageVersion[]
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
