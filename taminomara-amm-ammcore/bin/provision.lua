local pkg = require "ammcore.pkg"
local serverTemplate = require "ammcore._templates.server"
local eepromTemplate = require "ammcore._templates.eeprom"
local bootloader = require "ammcore.bootloader"
local log = require "ammcore.log"
local builder = require "ammcore.pkg.builder"

local logger = log.getLogger()

local config = bootloader.getBootloaderConfig()

if not config.packages then
    config.packages = {}
end

if config.target == "drive" then
    pkg.checkAndUpdate(false)
else
    local root = filesystem.path(bootloader.getSrvRoot(), "lib/taminomara-amm-ammcore")
    local version, archive = bootloader.getServerApi():getAmmCoreCode()
    local archiver = builder.PackageArchiver:FromArchive("taminomara-amm-ammcore", version, archive)
    logger:info("Writing local version of ammcore to %s", root)
    archiver:unpack(root)
end

-- serverTemplate.writeServerTemplate(bootloader.getDevRoot())
computer.setEEPROM(eepromTemplate.formatEeprom())

print("Computer successfully provisioned.")
