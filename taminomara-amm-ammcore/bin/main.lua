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

local log = require "ammcore/util/log"

local logger = log.Logger:New()

logger:info("Booting %s", AMM_BOOT_CONFIG.prog)

require(AMM_BOOT_CONFIG.prog)
