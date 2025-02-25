local class            = require "ammcore/util/class"
local provider         = require "ammcore/pkg/provider"
local ammPackageJson   = require "ammcore/pkg/ammPackageJson"
local version          = require "ammcore/pkg/version"
local packageName      = require "ammcore/pkg/packageName"
local package          = require "ammcore/pkg/packageVersion"

--- Local package provider.
local ns               = {}

--- Package version that was found on the hard drive.
---
--- @class ammcore.pkg.package.LocalPackageVersion: ammcore.pkg.package.PackageVersion
ns.LocalPackageVersion = class.create("LocalPackageVersion", package.PackageVersion)

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param provider ammcore.pkg.providers.local.LocalProvider
---
--- @generic T: ammcore.pkg.package.LocalPackageVersion
--- @param self T
--- @return T
function ns.LocalPackageVersion:New(name, version, provider)
    self = package.PackageVersion.New(self, name, version, provider)

    self.availableLocally = true

    --- Requirements parsed from local storage.
    ---
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self.requirements = {}

    --- Dev requirements parsed from local storage.
    ---
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self.devRequirements = {}

    return self
end

function ns.LocalPackageVersion:getRequirements()
    return self.requirements
end

function ns.LocalPackageVersion:getDevRequirements()
    return self.devRequirements
end

--- Implements a provider that loads packages from a directory
--- (usually `/.amm_packages` or `/`).
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
                local ver, requirements, devRequirements = ammPackageJson.parseFromFile(pkgPath)
                local pkg = ns.LocalPackageVersion:New(name, ver, self)
                pkg.requirements = requirements
                pkg.devRequirements = devRequirements
                pkg.isDevMode = isDev
                self._packages[name] = pkg
            end
        end
    end

    return self
end

--- Get all top-level packages as requirements.
---
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.LocalProvider:getRootRequirements()
    local reqs = {}
    for name, pkg in pairs(self._packages) do
        reqs[name] = version.VersionSpec:New(pkg.version)
    end
    return reqs
end

function ns.LocalProvider:findPackageVersions(name)
    local pkg = self._packages[name]
    if pkg then
        return { pkg }, true
    else
        return {}, false
    end
end

return ns
