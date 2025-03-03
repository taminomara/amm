local bootloader = require "ammcore.bootloader"

local config = bootloader.getBootloaderConfig()

if not config.prog then
    config.prog = computer.getInstance().nick:gsub("#.*$", ""):gsub("^%s*", ""):gsub("%s*$", "")
end
if config.prog and not type(config.prog) == "string" then
    error("config.prog is not a string")
end
if not config.prog or config.prog:len() == 0 then
    error("config.prog is not defined")
end

local nick = require "ammcore.util.nick"
local log = require "ammcore.util.log"

do
    local parsedNick = nick.parse(computer.getInstance().nick)
    local level = parsedNick:getOne("logLevel", tostring)
    if level then
        local levelInt = log.levelFromName(level)
        if not levelInt then
            error(string.format("unknown log level %s", level))
        end
        AMM_LOG_LEVELS[""] = levelInt
    end
end

print("Booting " .. config.prog)

require(config.prog)
