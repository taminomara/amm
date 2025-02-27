--- This code will load AMM and initialize the computer.

--[[{ if prog ~= "ammcore.bin.server" }]]
--- Name of this computer, used for monitoring.
AMM_FACTORY_NAME = [[{ factoryName }]]

--[[{ end }]]
--[[{ if prog == "ammcore.bin.server" }]]
--- Packages to install in addition to the loader system.
AMM_PACKAGES = {
    --[[{ for _, package in ipairs(packages) }]]
    [ [[{ package.name }]] ] = [[{ package.version }]],
    --[[{ end }]]
}

--- If set to `true`, AMM will do a clean install of all packages.
AMM_PKG_FORCE_CLEAN_INSTALL = false

--[[{ end }]]
--- Configuration for loading source code.
AMM_BOOT_CONFIG = {
    --- Program to run, parsed from computer's nick by default.
    prog = [[{ prog }]],

    --- Where to find the program: either `drive` or `net`.
    target = [[{ target }]],

    --[[{ if target == "drive" }]]
    --- Id of the hard drive which contains the code.
    --- Required if `target = "drive"` and computer has multiple hard drives.
    driveId = [[{ driveId }]],

    --[[{ end }]]
    --[[{ if target == "net" }]]
    --- Address of the server which serves the code.
    --- By default, the first code server that responds is used.
    netCodeServerAddr = [[{ netCodeServerAddr }]],
    --[[{ end }]]
}




AMM_BOOT_CONFIG = {target = "drive"}

-- Implementation

local loaders = {}

--- @type fun(path: string): string?
function loaders.drive(path)
    -- Locate a hard drive.
    if not filesystem.initFileSystem("/dev") then
        error("BootloaderError: failed to init /dev")
    end
    if not AMM_BOOT_CONFIG.driveId then
        local devices = filesystem.children("/dev")
        if #devices == 0 then
            error("BootloaderError: no hard drive detected")
        elseif #devices > 1 then
            error("BootloaderError: multiple hard drives detected, AMM_BOOT_CONFIG.driveId is required")
        end
        AMM_BOOT_CONFIG.driveId = devices[1]
    elseif type(AMM_BOOT_CONFIG.driveId) ~= "string" then
        error(string.format("BootloaderError: AMM_BOOT_CONFIG.driveId has invalid value %s", AMM_BOOT_CONFIG.driveId))
    elseif not filesystem.exists(filesystem.path("/dev", AMM_BOOT_CONFIG.driveId)) then
        error(string.format("BootloaderError: no hard drive with id %s", AMM_BOOT_CONFIG.driveId))
    end

    -- Mount a hard drive.
    filesystem.mount(filesystem.path("/dev", AMM_BOOT_CONFIG.driveId), "/")

    local pathTemplates = { "/taminomara-amm-%s", "/%s", "/.amm_packages/lib/taminomara-amm-%s", "/.amm_packages/lib/%s" }

    -- Locate package.
    local pkg = path:match("^(.-)/")
    if not pkg or pkg:len() == 0 then
        return nil
    end
    local realPath = nil
    for _, template in ipairs(pathTemplates) do
        if filesystem.exists(string.format(template, pkg)) then
            realPath = string.format(template, path)
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

    -- Cleanup: loader will mount everything by itself.
    filesystem.unmount("/")

    return code
end

--- @type fun(path: string): string?
function loaders.net(path)
    -- Find a network card.
    local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]
    if not networkCard then
        error("BootloaderError: no network card detected")
    end

    -- Prepare a network card.
    event.listen(networkCard)
    networkCard:open(0x1CD)

    -- Send request for loader code.
    if not AMM_BOOT_CONFIG.netCodeServerAddr then
        networkCard:broadcast(0x1CD, "get", path)
    elseif type(AMM_BOOT_CONFIG.netCodeServerAddr) ~= "string" then
        error(string.format("BootloaderError: AMM_BOOT_CONFIG.netCodeServerAddr has invalid value %s",
            AMM_BOOT_CONFIG.netCodeServerAddr))
    else
        networkCard:send(AMM_BOOT_CONFIG.netCodeServerAddr, 0x1CD, "get", path)
    end

    -- Wait for response.
    local deadline = computer.millis() + 500
    local event, sender, port, message, filename, code
    while true do
        local now = computer.millis()
        if now > deadline then
            error("BootloaderError: timeout while waiting for response from a code server")
        end
        event, _, sender, port, message, filename, code = event.pull(now - deadline)
        if (
                event == "NetworkMessage"
                and (not AMM_BOOT_CONFIG.netCodeServerAddr or sender == AMM_BOOT_CONFIG.netCodeServerAddr)
                and port == 0x1CD
                and message == "rcv"
                and filename == path
            ) then
            if code then
                break
            else
                computer.log(0, string.format("Response from code server %s: file not found", sender))
            end
        end
    end

    -- Got a response.
    AMM_BOOT_CONFIG.netCodeServerAddr = sender
    computer.log(0, string.format("Using code server %s", sender))

    return code
end

if not AMM_BOOT_CONFIG then
    error("BootloaderError: AMM_BOOT_CONFIG is not defined")
elseif not AMM_BOOT_CONFIG.target then
    error("BootloaderError: AMM_BOOT_CONFIG.target is not defined")
elseif not loaders[AMM_BOOT_CONFIG.target] then
    error(string.format("BootloaderError: AMM_BOOT_CONFIG.target has invalid value %s", AMM_BOOT_CONFIG.target))
else
    local path = "ammcore/_loader.lua"
    local code = loaders[AMM_BOOT_CONFIG.target](path)

    if not code then
        error(string.format("ImportError: no module named %s", path))
    end

    -- Compile loader code.
    local fn, err = load(code, path)
    if not fn then
        error(string.format("ImportError: failed to parse %s: %s", path, err))
    end

    -- Init loader.
    local bootloaderApi = fn()
    bootloaderApi.init()

    -- Run the program.
    require("ammcore/bin/main")
end
