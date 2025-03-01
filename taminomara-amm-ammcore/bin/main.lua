if not AMM_BOOT_CONFIG then
    AMM_BOOT_CONFIG = {}
end
if not AMM_BOOT_CONFIG.prog then
    AMM_BOOT_CONFIG.prog = computer.getInstance().nick:gsub("#.*$", ""):gsub("^%s*", ""):gsub("%s*$", "")
end
if AMM_BOOT_CONFIG.prog and not type(AMM_BOOT_CONFIG.prog) == "string" then
    error("AMM_BOOT_CONFIG.prog is not a string")
end
if not AMM_BOOT_CONFIG.prog or AMM_BOOT_CONFIG.prog:len() == 0 then
    error("AMM_BOOT_CONFIG.prog is not defined")
end

local nick = require "ammcore.util.nick"
local log = require "ammcore.util.log"

do
    local parsedNick = nick.parse(computer.getInstance().nick)
    local level = parsedNick:getOne("logLevel", tostring)
    if level then
        if not log.Level[level] then
            error(string.format("unknown log level %s", level))
        end
        AMM_LOG_LEVELS[""] = log.Level[level]
    end
end

print("Booting " .. AMM_BOOT_CONFIG.prog)

require(AMM_BOOT_CONFIG.prog)
