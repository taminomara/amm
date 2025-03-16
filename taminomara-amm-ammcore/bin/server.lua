local bootloader = require "ammcore.bootloader"
local pkg = require "ammcore.pkg"
local log = require "ammcore.log"
local defer = require "ammcore.defer"

local logger = log.Logger:New()

local config = bootloader.getBootloaderConfig()

local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]
if not networkCard then
    error("no network card detected")
end

config.netCodeServerPort = config.netCodeServerPort or 0x1CD --[[ @as integer ]]
if type(config.netCodeServerPort) ~= "number" then
    error(string.format("config.netCodeServerPort has invalid value %s", config.netCodeServerPort))
end

local updated = pkg.checkAndUpdate(false)
if updated then
    computer.reset()
end

-- Prepare a network card.
event.listen(networkCard)
networkCard:open(config.netCodeServerPort)

local handlers = {}

--- @param sender string
--- @param port integer
--- @param message string
--- @param path string
function handlers.getCode(_, _, sender, port, message, path)
    if type(path) ~= "string" then
        logger:warning("invalid argument 'path' for message %q from %s: %s", message, sender, path)
        networkCard:send(sender, port, "rcvCode", path, nil, nil)
        return
    end

    networkCard:send(sender, port, "rcvCode", path, bootloader.findModuleCode(path))
end

function handlers.reset()
    -- do nothing
end

event.registerListener(
    event.filter { sender = networkCard, event = "NetworkMessage", values = { port = config.netCodeServerPort } },
    function(event, _, sender, port, message, ...)
        logger:debug("Request %s:%s %q", sender, port, message)
        local handler = handlers[message]
        if handler then
            local ok, err = defer.xpcall(handler, event, _, sender, port, message, ...)
            if not ok then
                logger:error("error when processing message %q from %s: %s", message, sender, err)
            end
        else
            logger:warning("got an unknown message %q from %s", message, sender)
        end
    end
)

logger:info("Code server is listening on port %s", config.netCodeServerPort)

networkCard:broadcast(config.netCodeServerPort, "reset")

event.loop()
