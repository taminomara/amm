local log = require "ammcore/util/log"
local localProvider = require "ammcore/pkg/providers/local"
local aggregateProvider = require "ammcore/pkg/providers/aggregate"
local githubProvider = require "ammcore/pkg/providers/github"
local version = require "ammcore/pkg/version"
local api = require "ammcore/pkg/api"
local packageName = require "ammcore/pkg/packageName"

local logger = log.Logger:New()

local devPackages = localProvider.LocalProvider:New("/", true)
local localPackages = localProvider.LocalProvider:New("/.amm_packages/lib", false)

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
    rootRequirements["taminomara-amm-ammcore"] = version.parseSpec("~=1.0")
end

local provider = aggregateProvider.AggregateProvider:New({ devPackages, localPackages })
if not api.verify(rootRequirements, provider) then
    logger:info("Updating installed packages")

    local githubPackaages = githubProvider.GithubProvider:New()
    local provider = aggregateProvider.AggregateProvider:New({ devPackages, localPackages, githubPackaages })

    api.install(rootRequirements, provider)
else
    logger:info("Packages are up-to-date")
end
