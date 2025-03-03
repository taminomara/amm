local pkg               = require "ammcore.pkg.index"
local eepromTemplate    = require "ammcore.templates.eeprom"
local bootloader        = require "ammcore.bootloader"
local aggregateProvider = require "ammcore.pkg.providers.aggregate"

pkg.checkAndUpdate(false)

local config = bootloader.getBootloaderConfig()

if not config.packages then
    config.packages = {}
end
do
    local foundAmmReq = false
    for _, req in ipairs(config.packages) do
        if req:match("^taminomara-amm-ammcore") then
            foundAmmReq = true
            break
        end
    end
    if not foundAmmReq then
        local provider = aggregateProvider.AggregateProvider:New({
            pkg.getDevPackages(),
            pkg.getInstalledPackages(),
        })
        local ammPkgs, found = provider:findPackageVersions("taminomara-amm-ammcore")
        if found and #ammPkgs == 1 then
            table.insert(
                config.packages,
                string.format("taminomara-amm-ammcore ~ %s", ammPkgs[1].version:up())
            )
        end
    end
end

computer.setEEPROM(eepromTemplate.formatServerEeprom("ammcore.bin.server"))

print("AMM server successfully installed.")

computer.reset()
