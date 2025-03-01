--- Implements the `require` function and code loaders.
local ns = {}

--- @type table<string, { loaded: boolean, value: any }>
local _modules = {}
do
    _modules["ammcore.bootloader"] = { loaded = true, value = ns }
end

--- @type table<string, string>
local _paths = {}
do
    _paths["EEPROM"] = "EEPROM"
    local path = debug.getinfo(1).source:match("^@(.-)$")
    if path then
        _paths[path] = "ammcore.bootloader"
    end
end

local _loaders = {}

local loader
local bootloaderConfig

function _loaders.drive(config)
    if type(config.devRoot) ~= "string" then
        error(string.format("config.devRoot has invalid value %s", config.devRoot))
    elseif not filesystem.exists(config.devRoot) or not filesystem.isDir(config.devRoot) then
        error(string.format("config.devRoot does not exist or not a directory: %s", config.devRoot))
    end

    if not config.srvRoot then
        error(string.format("config.srvRoot has invalid value %s", config.srvRoot))
    elseif type(config.srvRoot) ~= "string" then
        error("config.srvRoot is not a string")
    elseif not filesystem.exists(config.srvRoot) or not filesystem.isDir(config.srvRoot) then
        error(string.format("config.srvRoot does not exist or not a directory: %s", config.srvRoot))
    end

    local pathTemplates = {
        filesystem.path(config.devRoot, "taminomara-amm-%s"),
        filesystem.path(config.devRoot, "%s"),
        filesystem.path(config.srvRoot, "packages/taminomara-amm-%s"),
        filesystem.path(config.srvRoot, "packages/%s"),
    }

    --- @type fun(pathCandidates: string[]): string?, string?
    return function(pathCandidates)
        for _, path in ipairs(pathCandidates) do
            path = filesystem.path(2, path)

            -- Locate package.
            local pkg = path:match("^([^/]*)")
            if not pkg or pkg:len() == 0 then
                goto continue
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
                goto continue
            end

            local code = ""

            local fd = filesystem.open(realPath, "r")
            local _ <close> = setmetatable({}, { __close = function() fd:close() end })

            while true do
                local chunk = fd:read(1024)
                if not chunk or chunk:len() == 0 then
                    return code, realPath
                end
                code = code .. chunk
            end

            ::continue::
        end

        return nil, nil
    end
end

function _loaders.net(config)
    -- Find a network card.
    local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]
    if not networkCard then
        error("no network card detected")
    end

    -- Prepare a network card.
    event.listen(networkCard)
    networkCard:open(0x1CD)

    -- Check config.
    if type(config.netCodeServerAddr) ~= "string" then
        error(string.format("config.netCodeServerAddr has invalid value %s", config.netCodeServerAddr))
    end
    if type(config.netCodeServerPort) ~= "number" then
        error(string.format("config.netCodeServerPort has invalid value %s", config.netCodeServerPort))
    end

    event.registerListener(
        event.filter { sender = networkCard, event = "NetworkMessage", values = { port = config.netCodeServerPort } },
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

    --- @type fun(pathCandidates: string[]): string?, string?
    return function(pathCandidates)
        local pathCandidatesStr = table.concat(pathCandidates, ":")

        networkCard:send(
            config.netCodeServerAddr,
            config.netCodeServerPort,
            "getCode",
            pathCandidatesStr
        )

        -- Wait for response.
        local deadline = computer.millis() + 500
        local event, sender, port, msg, responseCandidates, code, realPath
        while true do
            local now = computer.millis()
            if now > deadline then
                error("timeout while waiting for response from a code server")
            end
            event, _, sender, port, msg, responseCandidates, code, realPath = event.pull(now - deadline)
            if (
                    event == "NetworkMessage"
                    and sender == config.netCodeServerAddr
                    and port == config.netCodeServerPort
                    and msg == "rcvCode"
                    and responseCandidates == pathCandidatesStr
                ) then
                break
            end
        end

        return code, realPath
    end
end

if require then
    computer.log(2, "BootloaderWarning: 'require' function is already present")
end

--- @param mod string
--- @return string? canonical module name
--- @return string[] candidates for file search
local function canonizeModName(mod)
    if type(mod) ~= "string" then
        error(string.format("expected a string, got %s", type(mod)), 2)
    end
    if mod:match("/") then
        return nil, { filesystem.path(2, mod) }
    else
        mod = mod:gsub("%.+", "."):gsub("%.+$", "")
        if mod:match("^%.") then
            error("relative imports are not supported", 3)
        elseif mod:len() == 0 then
            error("got an empty module path", 3)
        end
        local shortAmmMod = mod:match("^taminomara%-amm%-(.*)$")
        if shortAmmMod then
            mod = shortAmmMod
        end
        local path = mod:gsub("%.", "/")
        return mod, { path .. ".lua", path .. "/_index.lua" }
    end
end

--- Find and load a lua module.
---
--- @param required string
function require(required)
    if not loader then
        error("'require' called before 'init'", 2)
    end

    local mod, pathCandidates = canonizeModName(required)

    if not mod then
        error(string.format("can't require a module by its full path name %s", required))
    end

    if not _modules[mod] then
        local code, realPath
        code, realPath = loader(pathCandidates)
        if not code then
            error(string.format("no module named %s", mod), 2)
        end

        if _paths[realPath] then
            computer.log(
                2,
                string.format(
                    "The same lua file is required with different names: %s and %s",
                    mod,
                    _paths[realPath]
                )
            )
        end

        _modules[mod] = { loaded = false }
        _paths[realPath] = mod

        local codeFn, err = load(code, "@" .. realPath, "t", _ENV)
        if not codeFn then
            error(string.format("syntax error in %s: %s", realPath, err), 2)
        end

        _modules[mod] = { loaded = true, value = codeFn() }
    elseif not _modules[mod].loaded then
        error(string.format("circular import in %s", mod), 2)
    end

    return _modules[mod].value
end

--- Initializes and installs the global `require` function.
function ns.init(config)
    if loader then
        error("loader is already installed")
    end

    if not config then
        error("config is not defined")
    elseif not config.target then
        error("config.target is not defined")
    end

    if type(config.target) == "function" then
        loader = config.target
        config.target = "bootstrap"
    elseif type(config.target) == "string" then
        if not _loaders[config.target] then
            error(string.format("config.target has invalid value %s", config.target))
        end
        loader = _loaders[config.target](config)
    else
        error("config.target should be a string")
    end

    bootloaderConfig = config
end

--- Find and return a file by its path.
---
--- Note: code is not cached. If target loader is 'net', this call will issue
--- a request to a code server. If target loader is 'drive' and the code has changed
--- since it was last loaded, this function will return the new version of the code.
---
--- @param pathCandidates string[] module path
--- @return string? module code
--- @string string? realPath actual path to the `.lua` file that contains the code
function ns.findModuleCode(pathCandidates)
    return loader(pathCandidates)
end

--- Get loader that was used to load the code.
---
--- @return "drive"|"net"|"bootstrap"|string
function ns.getLoaderKind()
    assert(loader, "'getLoaderKind' called before 'init'", 2)
    return bootloaderConfig.target
end

--- Get directory for dev packages.
---
--- @return table
function ns.getBootloaderConfig()
    assert(loader, "'getBootloaderConfig' called before 'init'", 2)
    return bootloaderConfig
end

--- Get directory for dev packages.
---
--- @return string?
function ns.getDevRoot()
    assert(loader, "'getDevRoot' called before 'init'", 2)
    return bootloaderConfig.devRoot
end

--- Get directory for internal AMM files.
---
--- @return string?
function ns.getSrvRoot()
    assert(loader, "'getSrvRoot' called before 'init'", 2)
    return bootloaderConfig.srvRoot
end

--- Given a real file path (as returned by `getFile`), look up associated module name.
---
--- @param realPath string
--- @return string?
function ns.getModuleByRealPath(realPath)
    assert(loader, "'getModuleByRealPath' called before 'init'", 2)
    return _paths[realPath]
end

return ns
