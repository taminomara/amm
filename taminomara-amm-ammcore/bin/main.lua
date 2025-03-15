local bootloader = require "ammcore.bootloader"
local nick = require "ammcore.nick"
local log = require "ammcore.log"

local config = bootloader.getBootloaderConfig()

local parsedNick = nick.parse(computer.getInstance().nick)

if not config.prog then
    config.prog = parsedNick:getPos(1, tostring)
end
if type(config.prog) ~= "string" then
    error("config.prog is not a string")
elseif config.prog:len() == 0 then
    error("config.prog is not defined")
end

do
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
