local log = require "ammcore/util/log"
local packageName = require "ammcore/pkg/packageName"
if not AMM_BOOT_CONFIG then
    AMM_BOOT_CONFIG = {}
end
if not AMM_BOOT_CONFIG.prog then
    AMM_BOOT_CONFIG.prog = computer.getInstance().nick:gsub("#.*$", ""):gsub("^%s*", ""):gsub("%s*$", "")
end
if AMM_BOOT_CONFIG.prog and not type(AMM_BOOT_CONFIG.prog) == "string" then
    error("BootloaderError: AMM_BOOT_CONFIG.prog is not a string")
end
if not AMM_BOOT_CONFIG.prog or AMM_BOOT_CONFIG.prog:len() == 0 then
    error("BootloaderError: AMM_BOOT_CONFIG.prog is not defined")
end

local localProvider = require "ammcore/pkg/providers/local"
local aggregateProvider = require "ammcore/pkg/providers/aggregate"
local githubProvider = require "ammcore/pkg/providers/github"
local version = require "ammcore/pkg/version"
local api = require "ammcore/pkg/api"

local logger = log.Logger:New()

do
    local devPackages = localProvider.LocalProvider:New("/", true)
    local localPackages = localProvider.LocalProvider:New("/.amm_packages", true)

    local rootRequirements = devPackages:getRootRequirements()
    if AMM_PACKAGES then
        if type(AMM_PACKAGES) ~= "table" then
            error("BootloaderError: AMM_PACKAGES is not a table")
        end
        for name, spec in pairs(AMM_PACKAGES) do
            if type(name) ~= "string" then
                error("BootloaderError: invalid package name in AMM_PACKAGES: " .. tostring(name))
            end
            if not packageName.parseFullPackageName(name) then
                error("BootloaderError: invalid package name in AMM_PACKAGES: " .. name)
            end
            if type(name) ~= "string" then
                error("BootloaderError: invalid package requirement in AMM_PACKAGES: " .. name)
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
        rootRequirements["taminomara-amm-ammcore"] = version.parseSpec("~=1.0")
    end

    local provider = aggregateProvider.AggregateProvider:New({ devPackages, localPackages })
    if not api.verify(rootRequirements, provider) then
        logger:info("Updating installed packages")

        local githubPackaages = githubProvider.GithubProvider:New()
        local provider = aggregateProvider.AggregateProvider:New({ devPackages, localPackages, githubPackaages })

        api.install(rootRequirements, provider)

        logger:info("Installed packages successfully updated, reboot is required")

        computer.reset()
    else
        logger:debug("Packages are up-to-date")
    end
end

logger:info("Booting %s", AMM_BOOT_CONFIG.prog)

require(AMM_BOOT_CONFIG.prog)
