local pkg = require "ammcore.pkg"
local serverTemplate = require "ammcore._templates.server"
local eepromTemplate = require "ammcore._templates.eeprom"
local bootloader = require "ammcore.bootloader"

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
        local provider = pkg.getPackageProvider()
        local ammPkgs, found = provider:findPackageVersions("taminomara-amm-ammcore", false)
        if found and #ammPkgs == 1 then
            table.insert(
                config.packages,
                string.format("taminomara-amm-ammcore ~ %s", ammPkgs[1].version:up())
            )
        end
    end
end

serverTemplate.writeServerTemplate(assert(bootloader.getDevRoot(), "config.devRoot is not set"))
computer.setEEPROM(eepromTemplate.formatServerEeprom("ammcore.bin.server"))

print("AMM server successfully installed.")

computer.reset()
