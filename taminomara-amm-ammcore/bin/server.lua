local bootloader = require "ammcore.bootloader"
local pkg = require "ammcore.pkg"
local log = require "ammcore.log"
local defer = require "ammcore.defer"
local json = require "ammcore._contrib.json"

if bootloader.getLoaderKind() ~= "drive" then
    computer.panic("Program \".server\" only works with drive loader")
end

local logger = log.Logger:New()

local config = bootloader.getBootloaderConfig()

local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]
if not networkCard then
    error("no network card detected")
end

config.bootPort = config.bootPort or 0x1CD
if type(config.bootPort) ~= "number" then
    error(string.format("config.bootPort has invalid value %s", config.bootPort))
end

local provider = pkg.getPackageProvider()
if not pkg.verify(pkg.gatherRootRequirements(provider), provider) then
    logger:error("Local packages require an update")
    computer.stop()
end

-- Prepare a network card.
event.listen(networkCard)
networkCard:open(config.bootPort)

local serverApi = bootloader.getServerApi()

local handlers = {}

--- @param sender string
--- @param port integer
function handlers.lsPkg(_, _, sender, port)
    local data = {}
    for name, pkg in pairs(serverApi:lsPkg()) do
        data[name] = pkg:getMetadata()
    end
    networkCard:send(sender, port, "rcvPkg", json.encode(data))
end

--- @param sender string
--- @param port integer
--- @param path string
function handlers.getCode(_, _, sender, port, _, path)
    if type(path) ~= "string" then
        logger:warning("Invalid argument 'path' for message \"getCode\" from %s: %s", sender, path)
        networkCard:send(sender, port, "rcvCode", path, nil, nil)
        return
    end

    local candidates = {}
    for candidate in path:gmatch("[^:]+") do
        table.insert(candidates, candidate)
    end

    networkCard:send(sender, port, "rcvCode", path, serverApi:getCode(candidates))
end

--- @param sender string
--- @param port integer
function handlers.getAmmCoreVersion(_, _, sender, port)
    local ver = serverApi:getAmmCoreVersion()
    networkCard:send(sender, port, "rcvAmmCoreVersion", tostring(ver))
end

--- @param sender string
--- @param port integer
function handlers.getAmmCoreCode(_, _, sender, port)
    local ver, code = serverApi:getAmmCoreCode()
    networkCard:send(sender, port, "rcvAmmCoreCode", tostring(ver), code)
end

function handlers.reset()
    -- do nothing
end

event.registerListener(
    event.filter { sender = networkCard, event = "NetworkMessage", values = { port = config.bootPort } },
    function(event, _, sender, port, message, ...)
        logger:debug("Request from %s:%s %q %s", sender, port, message, { ... })
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

logger:info("Code server is listening on port %s", config.bootPort)

networkCard:broadcast(config.bootPort, "reset")

event.loop()
