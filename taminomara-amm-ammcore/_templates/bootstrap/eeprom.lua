--- This code will load AMM and initialize the computer.

--- Configuration for loading source code.
local config = {
    --- Program to run, parsed from computer's nick by default.
    prog = [[{ prog }]],
    -- prog = "ammcore/bin/installPackages", -- to check and install new packages
    -- prog = "ammcore/bin/updatePackages", -- to update all packages to the latest version

    --- Where to find the program: either `drive` or `net`.
    target = [[{ target }]],
--[[{ configExtras }]]}

-- Implementation

local loaders = {}

--- @type fun(path: string): string?, string?
function loaders.drive(path)
    -- Locate a hard drive.
    filesystem.initFileSystem("/dev")
    if not config.driveId then
        local devices = filesystem.children("/dev")
        if #devices == 0 then
            error("no hard drive detected")
        elseif #devices > 1 then
            error("multiple hard drives detected, config.driveId is required")
        end
        config.driveId = devices[1]
    elseif type(config.driveId) ~= "string" then
        error(string.format("config.driveId has invalid value %s", config.driveId))
    elseif not filesystem.exists(filesystem.path("/dev", config.driveId)) then
        error(string.format("no hard drive with id %s", config.driveId))
    end

    config.driveMountPoint = config.driveMountPoint or [[{ defaultDriveMountPoint }]]
    if type(config.driveMountPoint) ~= "string" then
        error(string.format("config.driveMountPoint has invalid value %s", config.driveMountPoint))
    end
    config.devRoot = config.devRoot or [[{ defaultDevRoot }]]
    if type(config.devRoot) ~= "string" then
        error(string.format("config.devRoot has invalid value %s", config.devRoot))
    end
    config.srvRoot = config.srvRoot or [[{ defaultSrvRoot }]]
    if type(config.srvRoot) ~= "string" then
        error(string.format("config.srvRoot has invalid value %s", config.srvRoot))
    end

    -- Mount a hard drive and create roots.
    filesystem.mount(filesystem.path("/dev", config.driveId), config.driveMountPoint)
    filesystem.createDir(config.devRoot, true)
    filesystem.createDir(config.srvRoot, true)

    local pathTemplates = {
        filesystem.path(config.devRoot, "taminomara-amm-%s"),
        filesystem.path(config.devRoot, "%s"),
        filesystem.path(config.srvRoot, "packages/taminomara-amm-%s"),
        filesystem.path(config.srvRoot, "packages/%s"),
    }

    -- Locate package.
    local pkg = path:match("^(.-)/")
    if not pkg or pkg:len() == 0 then
        return nil
    end
    local realPath = nil
    for _, template in ipairs(pathTemplates) do
        if filesystem.exists(string.format(template, pkg)) then
            realPath = string.format(template, path) .. ".lua"
            break
        end
    end

    -- Locate file.
    if not realPath or not (filesystem.exists(realPath) and filesystem.isFile(realPath)) then
        return nil
    end

    local code = ""

    local fd = filesystem.open(realPath, "r")
    local _ <close> = setmetatable({}, { __close = function() fd:close() end })

    while true do
        local chunk = fd:read(1024)
        if not chunk or chunk:len() == 0 then
            break
        end
        code = code .. chunk
    end

    return code, realPath
end

--- @type fun(path: string): string?, string?
function loaders.net(path)
    -- Find a network card.
    local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]
    if not networkCard then
        error("no network card detected")
    end

    config.netCodeServerPort = config.netCodeServerPort or [[{ defaultNetCodeServerPort }]] --[[ @as integer ]]
    if type(config.netCodeServerPort) ~= "number" then
        error(string.format("config.netCodeServerPort has invalid value %s", config.netCodeServerPort))
    end

    -- Prepare a network card.
    event.listen(networkCard)
    networkCard:open(config.netCodeServerPort)

    -- Send request for loader code.
    if not config.netCodeServerAddr then
        networkCard:broadcast(config.netCodeServerPort, "get", path)
    elseif type(config.netCodeServerAddr) ~= "string" then
        error(string.format("config.netCodeServerAddr has invalid value %s",
            config.netCodeServerAddr))
    else
        networkCard:send(config.netCodeServerAddr, config.netCodeServerPort, "get", path)
    end

    -- Wait for response.
    local deadline = computer.millis() + 500
    local event, sender, port, message, filename, code, realPath
    while true do
        local now = computer.millis()
        if now > deadline then
            error("timeout while waiting for response from a code server")
        end
        event, _, sender, port, message, filename, code, realPath = event.pull(now - deadline)
        if (
                event == "NetworkMessage"
                and (not config.netCodeServerAddr or sender == config.netCodeServerAddr)
                and port == config.netCodeServerPort
                and message == "rcv"
                and filename == path
            ) then
            if code then
                break
            else
                computer.log(0, string.format("[EEPROM] Response from code server %s: file not found", sender))
            end
        end
    end

    -- Got a response.
    config.netCodeServerAddr = sender
    print("[EEPROM] Using code server %s", sender)

    return code, realPath
end

if not config then
    error("config is not defined")
elseif not config.target then
    error("config.target is not defined")
elseif not loaders[config.target] then
    error(string.format("config.target has invalid value %s", config.target))
else
    local path = "ammcore/bootloader"
    local code, realPath = loaders[config.target](path)

    if not code then
        error(string.format("no module named %s", path))
    end

    -- Compile loader code.
    local fn, err = load(code, "@" .. realPath)
    if not fn then
        error(string.format("failed parsing %s: %s", realPath, err))
    end

    -- Init loader.
    local bootloaderApi = fn()
    bootloaderApi.init(config)

    -- Run the program.
    require("ammcore/bin/main")
end
