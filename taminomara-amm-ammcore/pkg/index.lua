local log               = require "ammcore/util/log"
local resolver          = require "ammcore/pkg/resolver"
local packageName       = require "ammcore/pkg/packageName"
local version           = require "ammcore/pkg/version"
local localProvider     = require "ammcore/pkg/providers/local"
local githubProvider    = require "ammcore/pkg/providers/github"
local aggregateProvider = require "ammcore/pkg/providers/aggregate"
local fin               = require "ammcore/util/fin"
local bootloader        = require "ammcore/bootloader"

local ns                = {}

local logger            = log.Logger:New()

--- Get package provider with locally installed packages.
---
--- @return ammcore.pkg.providers.local.LocalProvider
function ns.getInstalledPackages()
    return localProvider.LocalProvider:Local()
end

--- Get package provider with local dev packages.
---
--- @return ammcore.pkg.providers.local.LocalProvider
function ns.getDevPackages()
    return localProvider.LocalProvider:Dev()
end

--- Scan `AMM_PACKAGES` and dev packages to get root requirements.
---
--- @param devPackages ammcore.pkg.providers.local.LocalProvider
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.gatherRootRequirements(devPackages)
    local rootRequirements = devPackages:getRootRequirements()
    if AMM_PACKAGES then
        if type(AMM_PACKAGES) ~= "table" then
            error("AMM_PACKAGES is not a table")
        end
        for _, req in ipairs(AMM_PACKAGES) do
            if type(req) ~= "string" then
                error(string.format("invalid package requirement in AMM_PACKAGES: %s", req))
            end

            local name, spec = req:match("^([%w_-]*)(.*)$")

            if not packageName.parseFullPackageName(name) then
                error(string.format("invalid package name in AMM_PACKAGES: %s", name))
            end

            local parsedSpec
            local ok, err = pcall(function() parsedSpec = version.parseSpec(spec) end)
            if not ok then
                error(string.format("invalid package requirement in AMM_PACKAGES: %s: %s", name, err))
            end

            if rootRequirements[name] then
                rootRequirements[name] = rootRequirements[name] .. parsedSpec
            else
                rootRequirements[name] = parsedSpec
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
--- @param devPackages ammcore.pkg.provider.Provider
--- @param installedPackages ammcore.pkg.provider.Provider
--- @return boolean
function ns.verify(rootRequirements, devPackages, installedPackages)
    local provider = aggregateProvider.AggregateProvider:New({
        devPackages, installedPackages
    })

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

            local pkgs, found = provider:findPackageVersions(name)
            if not found or #pkgs ~= 1 then
                return false
            end

            local pkg = pkgs[1]

            allPkgs[name] = pkg

            do
                local requirements = pkg:getRequirements()
                for name, spec in pairs(requirements) do
                    table.insert(packages, name)
                    if allRequirements[name] then
                        allRequirements[name] = allRequirements[name] .. spec
                    else
                        allRequirements[name] = spec
                    end
                end
            end

            if pkg.isDevMode then
                local requirements = pkg:getDevRequirements()
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
--- @param rootRequirements any
--- @param devPackages ammcore.pkg.providers.local.LocalProvider
--- @param installedPackages ammcore.pkg.providers.local.LocalProvider
--- @param updateAll boolean?
--- @return number nUpgraded
--- @return number nDowngraded
--- @return number nInstalled
--- @return number nUninstalled
function ns.install(rootRequirements, devPackages, installedPackages, updateAll)
    local srvRoot = assert(bootloader.getSrvRoot())

    local githubPackages = githubProvider.GithubProvider:New()
    local _ <close> = fin.defer(githubPackages.saveCache, githubPackages)

    local provider = aggregateProvider.AggregateProvider:New({
        devPackages, installedPackages, githubPackages
    })

    local resolvedPackages = resolver.resolve(rootRequirements, provider, updateAll)

    local nUpgraded, nDowngraded, nInstalled, nUninstalled = 0, 0, 0, 0

    local stagingPath = filesystem.path(srvRoot, "staging")
    if filesystem.exists(stagingPath) then
        filesystem.remove(stagingPath, true)
    end
    filesystem.createDir(stagingPath, true)

    local installed = {}

    for _, pkg in ipairs(resolvedPackages) do
        installed[pkg.name] = true

        if not pkg.isInstalled then
            local installed, foundInstalledPackage = installedPackages:findPackageVersions(pkg.name)

            local opetaion = ""
            if foundInstalledPackage and #installed == 1 then
                if pkg.version > installed[1].version then
                    opetaion = string.format(" (upgrade from %s)", installed[1].version)
                    nUpgraded = nUpgraded + 1
                else
                    opetaion = string.format(" (downgrade from %s)", installed[1].version)
                    nDowngraded = nDowngraded + 1
                end
            else
                nInstalled = nInstalled + 1
            end

            local pkgStagingPath = filesystem.path(stagingPath, pkg.name)
            local destinationPath = filesystem.path(srvRoot, "packages", pkg.name)

            logger:info("Installing package %s == %s%s", pkg.name, pkg.version, opetaion)
            pkg:install(pkgStagingPath)

            if filesystem.exists(destinationPath) then
                filesystem.remove(destinationPath, true)
            end

            logger:debug("Moving %s -> %s", pkgStagingPath, destinationPath)
            filesystem.move(pkgStagingPath, destinationPath)
        end
    end

    for name, _ in pairs(installedPackages:getRootRequirements()) do
        if not installed[name] then
            logger:info("Uninstalling package %s", name)
            local destinationPath = filesystem.path(srvRoot, "packages", name)
            filesystem.remove(destinationPath, true)
            nUninstalled = nUninstalled + 1
        end
    end

    filesystem.remove(stagingPath, true)

    return nUpgraded, nDowngraded, nInstalled, nUninstalled
end

--- Check local installation and update it if needed.
---
--- @param updateAll boolean? if `true`, force-install latest versions of all packages.
--- @returns boolean didUpdate `true` if any packages were updated, and restart is required.
function ns.checkAndUpdate(updateAll)
    local devPackages = ns.getDevPackages()
    local installedPackages = ns.getInstalledPackages()

    local rootRequirements = ns.gatherRootRequirements(devPackages)

    if updateAll or not ns.verify(rootRequirements, devPackages, installedPackages) then
        logger:info("Updating installed packages")
        local nUpgraded, nDowngraded, nInstalled, nUninstalled = ns.install(rootRequirements, devPackages, installedPackages, updateAll)
        logger:info("Updating complete: %s upgraded, %s downgraded, %s installed, %s uninstalled", nUpgraded, nDowngraded, nInstalled, nUninstalled)
    else
        logger:info("Packages are up-to-date")
    end
end

return ns
