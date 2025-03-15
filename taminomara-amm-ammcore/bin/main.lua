local bootloader = require "ammcore.bootloader"
local nick = require "ammcore.nick"
local log = require "ammcore.log"

local config = bootloader.getBootloaderConfig()

if not config.prog then
    config.prog = computer.getInstance().nick:gsub("#.*$", ""):match("^%s*(.-)%s*$")
end
if type(config.prog) ~= "string" then
    error("config.prog is not a string")
elseif config.prog:len() == 0 then
    error("config.prog is not defined")
end

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
