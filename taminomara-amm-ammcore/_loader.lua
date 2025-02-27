--- Implements the `require` function and code loaders.
local ns = {}

--- @private
--- @type table<string, { loaded: boolean, value: any }>
local _modules = {}
_modules["ammcore/_loader.lua"] = { loaded = true, value = ns }

local _loaders = {}

function _loaders.drive()
    -- Locate a hard drive.
    filesystem.initFileSystem("/dev")
    if not AMM_BOOT_CONFIG.driveId then
        error("BootloaderError: EEPROM must setup AMM_BOOT_CONFIG.driveId")
    elseif type(AMM_BOOT_CONFIG.driveId) ~= "string" then
        error(string.format("BootloaderError: AMM_BOOT_CONFIG.driveId has invalid value %s", AMM_BOOT_CONFIG.driveId))
    elseif not filesystem.exists(filesystem.path("/dev", AMM_BOOT_CONFIG.driveId)) then
        error(string.format("BootloaderError: no hard drive with id %s", AMM_BOOT_CONFIG.driveId))
    end

    -- Mount a hard drive.
    filesystem.mount(filesystem.path("/dev", AMM_BOOT_CONFIG.driveId), "/")

    local pathTemplates = { "/taminomara-amm-%s", "/%s", "/.amm_packages/lib/taminomara-amm-%s", "/.amm_packages/lib/%s" }

    --- @type fun(path: string): string?, string?
    return function(path)
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

        return code, realPath
    end
end

function _loaders.net()
    -- Find a network card.
    local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]
    if not networkCard then
        error("BootloaderError: no network card detected")
    end

    -- Prepare a network card.
    event.listen(networkCard)
    networkCard:open(0x1CD)

    event.registerListener(
        event.filter { sender = networkCard, event = "NetworkMessage", values = { port = 0x1CD } },
        function(event, _, sender, port, message)
            if message == "reset" then
                local shouldCancelReset = false
                --- @diagnostic disable-next-line: undefined-global
                if AMM_ON_NETBOOT_RESET then
                    --- @diagnostic disable-next-line: undefined-global
                    shouldCancelReset = AMM_ON_NETBOOT_RESET()
                end
                if not shouldCancelReset then
                    computer.reset()
                end
            end
        end
    )

    -- Check config.
    if not AMM_BOOT_CONFIG.netCodeServerAddr then
        error("BootloaderError: EEPROM must setup AMM_BOOT_CONFIG.netCodeServerAddr")
    elseif type(AMM_BOOT_CONFIG.netCodeServerAddr) ~= "string" then
        error(string.format("BootloaderError: AMM_BOOT_CONFIG.netCodeServerAddr has invalid value %s",
            AMM_BOOT_CONFIG.netCodeServerAddr))
    end

    --- @type fun(path: string): string?, string?
    return function(path)
        networkCard:send(AMM_BOOT_CONFIG.netCodeServerAddr, 0x1CD, "get", path)

        -- Wait for response.
        local deadline = computer.millis() + 500
        local event, sender, port, message, filename, code, realPath
        while true do
            local now = computer.millis()
            if now > deadline then
                error("BootloaderError: timeout while waiting for response from a code server")
            end
            event, _, sender, port, message, filename, code, realPath = event.pull(now - deadline)
            if (
                    event == "NetworkMessage"
                    and sender == AMM_BOOT_CONFIG.netCodeServerAddr
                    and port == 0x1CD
                    and message == "rcv"
                    and filename == path
                ) then
                break
            end
        end

        return code, realPath
    end
end

local loader
local loaderKind

if require then
    computer.log(2, "BootloaderWarning: `require` function is already present")
end

--- Find and load a lua module.
---
--- @param path string
function require(path)
    if not loader then
        error("BootloaderError: `require` called before `init`", 2)
    end

    if type(path) ~= "string" then
        error("ImportError: expected a string, got " .. type(path), 2)
    end
    path = filesystem.path(2, path)
    if not path:match("%.lua$") then
        path = path .. ".lua"
    end
    local shortAmmMod = path:match("^taminomara-amm-([^/]*)")
    if shortAmmMod then
        error(string.format("ImportError: use 'require %q' instead", shortAmmMod), 2)
    end

    if not _modules[path] then
        local code, realPath = loader(path)
        if not code then
            error(string.format("ImportError: no module named %s", path), 2)
        end

        _modules[path] = { loaded = false }

        local codeFn, err = load(code, realPath, "bt", _ENV)
        if not codeFn then
            error(string.format("Syntax error in %s: %s", realPath, err), 2)
        end

        _modules[path] = { loaded = true, value = codeFn() }
    elseif not _modules[path].loaded then
        error("ImportError: circular import in " .. path, 2)
    end

    return _modules[path].value
end

--- Initializes and installs the global `require` function.
function ns.init(config)
    if loader then
        error("BootloaderError: Loader is already installed.")
    end

    config = config or AMM_BOOT_CONFIG

    if not config then
        error("BootloaderError: config is not defined")
    elseif not config.target then
        error("BootloaderError: config.target is not defined")
    end

    if type(config.target) == "function" then
        loader = config.target
        loaderKind = "bootstrap"
    elseif type(config.target) == "string" then
        if not _loaders[config.target] then
            error(string.format("BootloaderError: config.target has invalid value %s", config.target))
        end
        loader = _loaders[config.target]()
        loaderKind = config.target
    else
        error("BootloaderError: config.target should be a string")
    end
end

--- @return "drive"|"net"|"bootstrap"|string
function ns.getLoaderKind()
    return loaderKind
end

return ns
