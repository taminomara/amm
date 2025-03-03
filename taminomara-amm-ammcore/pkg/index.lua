local log               = require "ammcore.util.log"
local resolver          = require "ammcore.pkg.resolver"
local packageName       = require "ammcore.pkg.packageName"
local version           = require "ammcore.pkg.version"
local localProvider     = require "ammcore.pkg.providers.local"
local githubProvider    = require "ammcore.pkg.providers.github"
local aggregateProvider = require "ammcore.pkg.providers.aggregate"
local fin               = require "ammcore.util.fin"
local bootloader        = require "ammcore.bootloader"

local ns                = {}

local logger            = log.Logger:New()

--- Get package provider with locally installed packages.
---
--- @return ammcore.pkg.provider.Provider
function ns.getPackageProvider()
    local providers = {}

    local devRoot = bootloader.getDevRoot()
    if devRoot then
        table.insert(providers, localProvider.LocalProvider:New(devRoot, true))
    else
        logger:warning("config.devRoot is not set, dev package provider is not available")
    end

    local srvRoot = bootloader.getSrvRoot()
    if srvRoot then
        table.insert(providers, localProvider.LocalProvider:New(filesystem.path(srvRoot, "lib"), false))
    else
        logger:warning("config.srvRoot is not set, local package provider is not available")
    end

    local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[ @as FINInternetCard? ]]
    if internetCard then
        table.insert(providers, githubProvider.GithubProvider:New(internetCard))
    else
        logger:warning("no internet card detected, github package provider is not available")
    end

    return aggregateProvider.AggregateProvider:New(providers)
end

--- Scan `config.packages` and dev packages to get root requirements.
---
--- @param provider ammcore.pkg.provider.Provider
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.gatherRootRequirements(provider)
    local rootRequirements = {}

    local config = bootloader.getBootloaderConfig()
    if config.packages then
        if type(config.packages) ~= "table" then
            error("config.packages is not a table")
        end
        for _, req in ipairs(config.packages) do
            if type(req) ~= "string" then
                error(string.format("invalid package requirement in config.packages: %s", req))
            end

            local name, spec = req:match("^([%w_-]*)(.*)$")

            if not packageName.parseFullPackageName(name) then
                error(string.format("invalid package name in config.packages: %s", name))
            end

            local parsedSpec
            local ok, err = pcall(function() parsedSpec = version.parseSpec(spec) end)
            if not ok then
                error(string.format("invalid package requirement in config.packages: %s: %s", name, err))
            end

            if rootRequirements[name] then
                rootRequirements[name] = rootRequirements[name] .. parsedSpec
            else
                rootRequirements[name] = parsedSpec
            end
        end
    end

    local localPackages = provider:getLocalPackages()
    for _, pkg in ipairs(localPackages) do
        if pkg.isDevMode then
            local spec = version.VersionSpec:New(pkg.version)
            if rootRequirements[pkg.name] then
                rootRequirements[pkg.name] = rootRequirements[pkg.name] .. spec
            else
                rootRequirements[pkg.name] = spec
            end
        end
    end

    if not rootRequirements["taminomara-amm-ammcore"] then
        rootRequirements["taminomara-amm-ammcore"] = version.parseSpec("*")
    end

    return rootRequirements
end

--- Check if all requirements are satisfied by the locally installed packages.
---
--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec>
--- @param provider ammcore.pkg.provider.Provider
--- @return boolean
function ns.verify(rootRequirements, provider)
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    local allRequirements = {}
    --- @type table<string, ammcore.pkg.package.PackageVersion>
    local allPkgs = {}

    do
        local packages = {}
        for name, versionSpec in pairs(rootRequirements) do
            table.insert(packages, name)
            allRequirements[name] = versionSpec
        end

        while #packages > 0 do
            local name = table.remove(packages)

            if allPkgs[name] then
                goto continue
            end

            local pkgs, found = provider:findPackageVersions(name, false)
            if not found or #pkgs ~= 1 then
                return false
            end

            local pkg = pkgs[1]
            if not pkg.isInstalled then
                return false
            end

            allPkgs[name] = pkg

            do
                local requirements = pkg:getAllRequirements()
                for name, spec in pairs(requirements) do
                    table.insert(packages, name)
                    if allRequirements[name] then
                        allRequirements[name] = allRequirements[name] .. spec
                    else
                        allRequirements[name] = spec
                    end
                end
            end

            ::continue::
        end
    end

    for name, pkgVer in pairs(allPkgs) do
        if allRequirements[name] and not allRequirements[name]:matches(pkgVer.version) then
            return false
        end
    end

    return true
end

--- Resolve and install packages.
---
--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec>
--- @param provider ammcore.pkg.provider.Provider
--- @param updateAll boolean
--- @param includeRemotePackages boolean
--- @return number nUpgraded
--- @return number nDowngraded
--- @return number nInstalled
--- @return number nUninstalled
--- @return number nRebuilt
function ns.install(rootRequirements, provider, updateAll, includeRemotePackages)
    local srvRoot = assert(bootloader.getSrvRoot(), "can't install paclages because config.srvRoot is not set")

    local resolvedPackages = resolver.resolve(rootRequirements, provider, updateAll, includeRemotePackages)

    local nUpgraded, nDowngraded, nInstalled, nUninstalled, nRebuilt = 0, 0, 0, 0, 0

    local packagesPath = filesystem.path(srvRoot, "lib")
    if not filesystem.exists(packagesPath) then
        assert(filesystem.createDir(packagesPath, true))
    elseif not filesystem.isDir(packagesPath) then
        error(string.format("not a directory: %s", packagesPath))
    end

    local isResolved = {}

    for _, pkg in ipairs(resolvedPackages) do
        isResolved[pkg.name] = true

        if not pkg.isInstalled then
            local installed, foundInstalledPackage = provider:findPackageVersions(pkg.name, false)

            local opetaion = ""
            if foundInstalledPackage and #installed == 1 then
                if pkg.version > installed[1].version then
                    opetaion = string.format(" (upgrade from %s)", installed[1].version)
                    nUpgraded = nUpgraded + 1
                elseif pkg.version == installed[1].version then
                    opetaion = " (rebuild)"
                    nRebuilt = nRebuilt + 1
                else
                    opetaion = string.format(" (downgrade from %s)", installed[1].version)
                    nDowngraded = nDowngraded + 1
                end
            else
                nInstalled = nInstalled + 1
            end

            local pkgStagingPath = filesystem.path(packagesPath, ".staging")
            local pkgDestinationPath = filesystem.path(packagesPath, pkg.name)

            if filesystem.exists(pkgStagingPath) then
                assert(filesystem.remove(pkgStagingPath, true))
            end

            logger:info("Installing package %s == %s%s", pkg.name, pkg.version, opetaion)
            pkg:install(pkgStagingPath)

            if filesystem.exists(pkgDestinationPath) then
                logger:debug("Removing %s", pkgDestinationPath)
                assert(filesystem.remove(pkgDestinationPath, true))
            end

            logger:debug("Moving %s -> %s", pkgStagingPath, pkgDestinationPath)
            assert(filesystem.rename(pkgStagingPath, pkg.name))
        end
    end

    for _, pkg in pairs(provider:getLocalPackages()) do
        if not isResolved[pkg.name] then
            logger:info("Uninstalling package %s", pkg.name)
            local destinationPath = filesystem.path(srvRoot, "lib", pkg.name)
            logger:debug("Removing %s", destinationPath)
            assert(filesystem.remove(destinationPath, true))
            nUninstalled = nUninstalled + 1
        end
    end

    return nUpgraded, nDowngraded, nInstalled, nUninstalled, nRebuilt
end

--- Check local installation and update it if needed.
---
--- @param updateAll boolean if `true`, force-install latest versions of all packages.
--- @returns boolean didUpdate `true` if any packages were updated, and restart is required.
function ns.checkAndUpdate(updateAll)
    local provider = ns.getPackageProvider()
    local rootRequirements = ns.gatherRootRequirements(provider)

    if updateAll or not ns.verify(rootRequirements, provider) then
        logger:info("Updating installed packages")
        local nUpgraded, nDowngraded, nInstalled, nUninstalled, nRebuilt = ns.install(rootRequirements, provider, updateAll, true)
        logger:info("Updating complete: %s upgraded, %s downgraded, %s installed, %s uninstalled, %s rebuilt", nUpgraded, nDowngraded, nInstalled, nUninstalled, nRebuilt)
        return true
    else
        logger:info("Packages are up-to-date")
        return false
    end
end

return ns
