local log = require "ammcore.log"
local resolver = require "ammcore.pkg.resolver"
local packageName = require "ammcore.pkg.packageName"
local version = require "ammcore.pkg.version"
local localProvider = require "ammcore.pkg.providers.local"
local githubProvider = require "ammcore.pkg.providers.github"
local aggregateProvider = require "ammcore.pkg.providers.aggregate"
local bootloader = require "ammcore.bootloader"
local fun = require "ammcore.fun"

--- API for AMM package manager.
---
--- .. warning::
---
---    This API is unstable and may change in the future. Do not use it.
---
--- !doctype module
--- @class ammcore.pkg
local ns = {}

local logger = log.Logger:New()

--- Get package provider with locally installed packages.
---
--- @param silent boolean? don't emit warnings if provider is unavailable.
--- @return ammcore.pkg.provider.Provider provider a package provider.
function ns.getPackageProvider(silent)
    local providers = {}

    local devRoot = bootloader.getDevRoot()
    if devRoot then
        table.insert(providers, localProvider.LocalProvider:New(devRoot, true))
    elseif not silent then
        logger:warning("config.devRoot is not set, dev package provider is not available")
    end

    local srvRoot = bootloader.getSrvRoot()
    if srvRoot then
        table.insert(providers, localProvider.LocalProvider:New(filesystem.path(srvRoot, "lib"), false))
    elseif not silent then
        logger:warning("config.srvRoot is not set, local package provider is not available")
    end

    local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[ @as FINInternetCard? ]]
    if internetCard then
        table.insert(providers, githubProvider.GithubProvider:New(internetCard))
    elseif not silent then
        logger:warning("no internet card detected, github package provider is not available")
    end

    return aggregateProvider.AggregateProvider:New(providers)
end

--- Scan `config.packages` and dev packages to get root requirements.
---
--- @param provider ammcore.pkg.provider.Provider a package provider.
--- @return table<string, ammcore.pkg.version.VersionSpec> map from package name to requirement spec for the package.
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

            local name, specTxt = req:match("^([%w_-]*)(.*)$")

            if not packageName.parseFullPackageName(name) then
                error(string.format("invalid package name in config.packages: %s", name))
            end

            local spec
            local ok, err = pcall(function() spec = version.parseSpec(specTxt) end)
            if not ok then
                error(string.format("invalid package requirement in config.packages: %s: %s", name, err))
            end

            if rootRequirements[name] then
                rootRequirements[name] = rootRequirements[name] .. spec
            else
                rootRequirements[name] = spec
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
    -- if not rootRequirements["taminomara-amm-ammtest"] then
    --     rootRequirements["taminomara-amm-ammtest"] = version.parseSpec("*")
    -- end
    -- if not rootRequirements["taminomara-amm-ammgui"] then
    --     rootRequirements["taminomara-amm-ammgui"] = version.parseSpec("*")
    -- end

    return rootRequirements
end

--- Check if all requirements are satisfied by the locally installed packages.
---
--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec> root requirements (see `gatherRootRequirements`).
--- @param provider ammcore.pkg.provider.Provider a package provider.
--- @return boolean ok `true` if ``rootRequirements`` are satisfied by installed packages.
function ns.verify(rootRequirements, provider)
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    local allRequirements = {}
    --- @type table<string, ammcore.pkg.package.PackageVersion>
    local allPkgs = {}

    do
        local pkgNamesStack = {}
        for name, spec in pairs(rootRequirements) do
            table.insert(pkgNamesStack, name)
            allRequirements[name] = spec
        end

        while #pkgNamesStack > 0 do
            local name = table.remove(pkgNamesStack)

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
                fun.t.updateWith(allRequirements, pkg:getAllRequirements(), function(l, r)
                    return l .. r
                end)
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
--- If ``updateAll`` is `true`, resolver will install the newest available versions
--- of all packages. Otherwise, it will prefer already installed versions
--- if they don't conflict with requirements.
---
--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec> root requirements (see `gatherRootRequirements`).
--- @param provider ammcore.pkg.provider.Provider a package provider.
--- @param updateAll boolean update local packages even if current versions don't conflict with requirements.
--- @param includeRemotePackages boolean allow package to fetch packages from github or other remote source.
--- @return number nUpgraded number of upgraded packages.
--- @return number nDowngraded number of downgraded packages.
--- @return number nInstalled number of freshly installed packages.
--- @return number nUninstalled number uninstalled packages that were no longer needed.
--- @return number nRebuilt number of dev packages that were rebuilt.
function ns.install(rootRequirements, provider, updateAll, includeRemotePackages)
    local srvRoot = assert(bootloader.getSrvRoot(), "can't install packages because config.srvRoot is not set")

    local resolvedPackages = resolver.resolve(rootRequirements, provider, updateAll, includeRemotePackages)

    local nUpgraded, nDowngraded, nInstalled, nUninstalled, nRebuilt = 0, 0, 0, 0, 0

    local pkgsPath = filesystem.path(srvRoot, "lib")
    if not filesystem.exists(pkgsPath) then
        assert(filesystem.createDir(pkgsPath, true))
    elseif not filesystem.isDir(pkgsPath) then
        error(string.format("not a directory: %s", pkgsPath))
    end

    local isResolved = {}

    for _, pkg in ipairs(resolvedPackages) do
        isResolved[pkg.name] = true

        if not pkg.isInstalled then
            -- Check if another version is installed?
            local installedVersions, foundInstalled = provider:findPackageVersions(pkg.name, false)
            local operation = ""
            if foundInstalled and #installedVersions == 1 then
                if pkg.version > installedVersions[1].version then
                    operation = string.format(" (upgrade from %s)", installedVersions[1].version)
                    nUpgraded = nUpgraded + 1
                elseif pkg.version == installedVersions[1].version then
                    operation = " (rebuild)"
                    nRebuilt = nRebuilt + 1
                else
                    operation = string.format(" (downgrade from %s)", installedVersions[1].version)
                    nDowngraded = nDowngraded + 1
                end
            else
                nInstalled = nInstalled + 1
            end

            local pkgStagingPath = filesystem.path(pkgsPath, ".staging")
            local pkgDestinationPath = filesystem.path(pkgsPath, pkg.name)

            if filesystem.exists(pkgStagingPath) then
                assert(filesystem.remove(pkgStagingPath, true))
            end

            logger:info("Installing package %s == %s%s", pkg.name, pkg.version, operation)
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
--- @param updateAll boolean update local packages even if current versions don't conflict with requirements.
--- @returns boolean didUpdate `true` if any packages were updated, and restart is required.
function ns.checkAndUpdate(updateAll)
    local provider = ns.getPackageProvider()
    local rootRequirements = ns.gatherRootRequirements(provider)

    if updateAll or not ns.verify(rootRequirements, provider) then
        logger:info("Updating installed packages")
        local nUpgraded, nDowngraded, nInstalled, nUninstalled, nRebuilt = ns.install(
            rootRequirements, provider, updateAll, true
        )
        logger:info(
            "Updating complete: %s upgraded, %s downgraded, %s installed, %s uninstalled, %s rebuilt",
            nUpgraded, nDowngraded, nInstalled, nUninstalled, nRebuilt
        )
        return true
    else
        logger:info("Packages are up-to-date")
        return false
    end
end

return ns
