local log               = require "ammcore/util/log"
local resolver          = require "ammcore/pkg/resolver"
local packageName       = require "ammcore/pkg/packageName"
local version           = require "ammcore/pkg/version"
local localProvider     = require "ammcore/pkg/providers/local"
local githubProvider    = require "ammcore/pkg/providers/github"
local aggregateProvider = require "ammcore/pkg/providers/aggregate"
local fin               = require "ammcore/util/fin"

local ns                = {}

local logger            = log.Logger:New()

--- Get package provider with locally installed packages.
---
--- @return ammcore.pkg.provider.Provider
function ns.getInstalledPackages()
    return localProvider.LocalProvider:New(".amm_packages/lib", false)
end

--- Get package provider with local dev packages.
---
--- @return ammcore.pkg.providers.local.LocalProvider
function ns.getDevPackages()
    return localProvider.LocalProvider:New(".", true)
end

--- Scan `AMM_PACKAGES` and dev packages to get root requirements.
---
--- @param devPackages ammcore.pkg.providers.local.LocalProvider
--- @return table<string, ammcore.pkg.version.VersionSpec>
function ns.gatherRootRequirements(devPackages)
    local rootRequirements = devPackages:getRootRequirements()
    if AMM_PACKAGES then
        if type(AMM_PACKAGES) ~= "table" then
            error("BootloaderError: AMM_PACKAGES is not a table")
        end
        for _, req in ipairs(AMM_PACKAGES) do
            if type(req) ~= "string" then
                error("BootloaderError: invalid package requirement in AMM_PACKAGES: " .. req)
            end

            local name, spec = req:match("^([%w_-]*)(.*)$")

            if not packageName.parseFullPackageName(name) then
                error("BootloaderError: invalid package name in AMM_PACKAGES: " .. name)
            end

            local parsedSpec
            local ok, err = pcall(function() parsedSpec = version.parseSpec(spec) end)
            if not ok then
                error("BootloaderError: invalid package requirement in AMM_PACKAGES: " .. name .. ": " .. err)
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
--- @param devPackages ammcore.pkg.provider.Provider
--- @param installedPackages ammcore.pkg.provider.Provider
--- @return number nUpdated number of updated packages
--- @return number nInstalled number of freshly installed packages
function ns.install(rootRequirements, devPackages, installedPackages)
    local githubPackages = githubProvider.GithubProvider:New()
    local _ <close> = fin.defer(githubPackages.saveCache, githubPackages)

    local provider = aggregateProvider.AggregateProvider:New({
        devPackages, installedPackages, githubPackages
    })

    local resolvedPackages = resolver.resolve(rootRequirements, provider)

    local nUpdated, nInstalled = 0, 0

    if filesystem.exists(".amm_packages/staging") then
        filesystem.remove(".amm_packages/staging", true)
    end
    filesystem.createDir(".amm_packages/staging", true)

    for _, pkg in ipairs(resolvedPackages) do
        if not pkg.isInstalled then
            local _, foundInstalledPackage = installedPackages:findPackageVersions(pkg.name)
            if foundInstalledPackage then
                nUpdated = nUpdated + 1
            else
                nInstalled = nInstalled + 1
            end

            local stagingPath = filesystem.path(".amm_packages/staging", pkg.name)
            local destinationPath = filesystem.path(".amm_packages/lib", pkg.name)

            logger:info("Installing package %s==%s", pkg.name, pkg.version)
            pkg:install(stagingPath)

            if filesystem.exists(destinationPath) then
                filesystem.remove(destinationPath, true)
            end

            logger:debug("Moving %s -> %s", stagingPath, destinationPath)
            filesystem.move(stagingPath, destinationPath)
        end
    end

    filesystem.remove(".amm_packages/staging", true)

    return nUpdated, nInstalled
end

--- Check local installation and update it if needed.
---
--- @returns boolean didUpdate `true` if any packages were updated, and restart is required.
function ns.checkAndUpdate()
    local devPackages = ns.getDevPackages()
    local installedPackages = ns.getInstalledPackages()

    local rootRequirements = ns.gatherRootRequirements(devPackages)

    if not ns.verify(rootRequirements, devPackages, installedPackages) then
        logger:info("Updating installed packages")
        local nUpdated, nInstalled = ns.install(rootRequirements, devPackages, installedPackages)
        logger:info("Updated %s packages, installed %s packages", nUpdated, nInstalled)
    else
        logger:info("Packages are up-to-date")
    end
end

return ns
