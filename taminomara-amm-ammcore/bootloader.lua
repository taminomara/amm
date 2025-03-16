--- Bootloader implements the `require` function
--- and all necessary APIs for it to function.
---
--- .. autoobject:: require
---    :global:
---
--- !doctype module
--- @class ammcore.bootloader
local ns = {}

--- @type table<string, { loaded: boolean, value: any, realPath: string }>
local _modules = {}
do
    _modules["ammcore.bootloader"] = { loaded = true, value = ns, realPath = "<unknown>" }
end

--- @type table<string, string>
local _paths = {}

do
    _paths["EEPROM"] = "EEPROM"
    local path = debug.getinfo(1).source:match("^@(.-)$")
    if path then
        _paths[path] = "ammcore.bootloader"
        _modules["ammcore.bootloader"].realPath = path
    end
end

--- @type table<string, ammcore.pkg.package.PackageVersion>[]?
local localPackages = nil

--- A function that resolves file contents.
---
--- !doc private
--- @alias ammcore.bootloader._Bootloader fun(pathCandidates: string[]): string?, string?

--- @type ammcore.bootloader._Bootloader
local loader

--- A bootloader config.
---
--- @class ammcore.bootloader.BootloaderConfig: { [string]: unknown }
--- @field prog string? Program to run, parsed from computer's nick by default.
--- @field target "drive"|"net"|"bootstrap"|string Name of the loader that was used to load the code.
--- @field devRoot string? Directory for dev packages if one is configured.
--- @field srvRoot string? Directory for internal AMM files.
--- @field driveId string? Id of the hard drive that contains AMM files, used when `target` is ``drive``.
--- @field driveMountPoint string? Point where the hard drive with AMM files will be mounted, used when `target` is ``drive``.
--- @field netCodeServerAddr string? Address of the code server, used when `target` is ``net``.
--- @field netCodeServerPort integer? Port of the code server, used when `target` is ``net``.
--- @field packages string[]? List of dependencies that should be installed before the code server starts.

--- @type ammcore.bootloader.BootloaderConfig
local bootloaderConfig

--- @type table<string, fun(config: ammcore.bootloader.BootloaderConfig): ammcore.bootloader._Bootloader>
local _loaders = {}

--- @param config ammcore.bootloader.BootloaderConfig
--- @return ammcore.bootloader._Bootloader
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
        filesystem.path(config.srvRoot, "lib/taminomara-amm-%s"),
        filesystem.path(config.srvRoot, "lib/%s"),
    }

    --- @type table<string, string|false>
    local pkgIndex = {}

    --- @type fun(path: string): string
    local function readFile(path)
        local fd = filesystem.open(path, "r")
        local _ <close> = setmetatable({}, { __close = function() fd:close() end })
        local content = ""
        while true do
            local chunk = fd:read(1024)
            if not chunk or chunk:len() == 0 then
                break
            end
            content = content .. chunk
        end
        return content
    end

    --- @type fun(pkg: string): string?
    local function resolvePackagePath(pkg)
        local pkgPath = pkgIndex[pkg]
        if pkgPath then
            return pkgPath
        elseif pkgPath == false then
            return nil
        end

        for _, template in ipairs(pathTemplates) do
            local candidatePkgPath = string.format(template, pkg)
            if filesystem.exists(candidatePkgPath) then
                pkgIndex[pkg] = candidatePkgPath
                return candidatePkgPath
            end
        end

        pkgIndex[pkg] = false
        return nil
    end

    --- @type ammcore.bootloader._Bootloader
    return function(pathCandidates)
        for _, pathCandidate in ipairs(pathCandidates) do
            pathCandidate = filesystem.path(2, pathCandidate)

            -- Locate package.
            local pkg, path = pathCandidate:match("^([^/]*)/(.*)$")

            if not pkg or pkg:len() == 0 then
                goto continue
            end

            local pkgPath = resolvePackagePath(pkg)
            if not pkgPath then
                goto continue
            end

            local realPath = filesystem.path(pkgPath, path)
            if filesystem.exists(realPath) and filesystem.isFile(realPath) then
                return readFile(realPath), realPath
            end

            ::continue::
        end

        return nil, nil
    end
end

--- @param config ammcore.bootloader.BootloaderConfig
--- @return ammcore.bootloader._Bootloader
function _loaders.net(config)
    -- Find a network card.
    local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]
    if not networkCard then
        error("no network card detected")
    end

    -- Check config.
    if type(config.netCodeServerAddr) ~= "string" then
        error(string.format("config.netCodeServerAddr has invalid value %s", config.netCodeServerAddr))
    end
    if type(config.netCodeServerPort) ~= "number" then
        error(string.format("config.netCodeServerPort has invalid value %s", config.netCodeServerPort))
    end

    -- Prepare a network card.
    event.listen(networkCard)
    networkCard:open(config.netCodeServerPort)

    event.registerListener(
        event.filter { sender = networkCard, event = "NetworkMessage", values = { port = config.netCodeServerPort } },
        function(event, _, sender, port, message)
            if message == "reset" then
                computer.reset()
            end
        end
    )

    --- @type ammcore.bootloader._Bootloader
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
        local e, sender, port, msg, responseCandidates, code, realPath
        while true do
            local now = computer.millis()
            if now > deadline then
                error("timeout while waiting for response from a code server")
            end
            e, _, sender, port, msg, responseCandidates, code, realPath = event.pull(now - deadline)
            if
                e == "NetworkMessage"
                and sender == config.netCodeServerAddr
                and port == config.netCodeServerPort
                and msg == "rcvCode"
                and responseCandidates == pathCandidatesStr
            then
                break
            end
        end

        return code, realPath
    end
end

if require then
    computer.log(2, "[ammcore.bootloader] WARNING: 'require' function is already present")
end

--- @param mod string
--- @return string? canonical module name
--- @return string[] candidates for file search
local function canonizeModName(mod)
    if type(mod) ~= "string" then
        error(string.format("expected a string, got %s", type(mod)), 3)
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

--- Load the given module, return any value returned by it.
---
--- If module returns `nil`, it is replaced with `true`.
---
--- Besides that value, `require` also returns as a second result
--- the loader data returned by the searcher, which indicates how `require`
--- found the module. For instance, if the module came from a file,
--- this loader data is the file path.
---
--- @param modname string module path.
--- @return unknown # module contents.
--- @return unknown realPath where this module comes from (usually a `string`).
function require(modname) --- @diagnostic disable-line: lowercase-global
    return ns._require(modname)
end

--- @package
--- @param modname string module path.
--- @param noWarnings boolean? disable warnings about requiring modules from foreign packages.
--- @return unknown # module contents.
--- @return unknown realPath where this module comes from (usually a `string`).
function ns._require(modname, noWarnings)
    if not loader then
        error("'require' called before 'init'", 2)
    end

    local mod, pathCandidates = canonizeModName(modname)

    if not mod then
        error(string.format("can't require a module by its full path name %s", modname), 2)
    end

    if not _modules[mod] then
        local code, realPath
        code, realPath = loader(pathCandidates)
        if not code or not realPath then
            error(string.format("no module named %s", mod), 2)
        end

        if localPackages and not noWarnings then
            local requiringMod = ns.getMod(2):match("^[^.]*")
            local requiredMod = mod:match("^[^.]*")

            if requiringMod ~= requiredMod then
                local requiringPkg = nil
                if localPackages["taminomara-amm-" .. requiringMod] then
                    requiringPkg = localPackages["taminomara-amm-" .. requiringMod]
                elseif localPackages[requiringMod] then
                    requiringPkg = localPackages[requiringMod]
                end
                if requiringPkg then
                    local requirements = requiringPkg:getAllRequirements()
                    if not requirements[requiredMod] and not requirements["taminomara-amm-" .. requiredMod] then
                        computer.log(
                            2,
                            string.format(
                                "[ammcore.bootloader] WARNING: Module %s requires modules from %s, but %s is not listed as its dependency",
                                requiringMod,
                                requiredMod,
                                requiredMod
                            )
                        )
                    end
                end
            end
        end

        if _paths[realPath] then
            computer.log(
                2,
                string.format(
                    "[ammcore.bootloader] WARNING: The same lua file is required with different names: %s and %s",
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

        _modules[mod] = { loaded = true, value = codeFn() or true }
    elseif not _modules[mod].loaded then
        error(string.format("circular import in %s", mod), 2)
    end

    return _modules[mod].value, _modules[mod].realPath
end

--- Initialize and install the global `require` function.
---
--- @param config ammcore.bootloader.BootloaderConfig bootloader config.
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
        loader = config.target --[[ @as ammcore.bootloader._Bootloader ]]
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

    local pkg = require "ammcore.pkg"
    local provider = pkg.getPackageProvider(true)
    localPackages = {}
    for _, package in ipairs(provider:getLocalPackages()) do
        localPackages[package.name] = package
    end
end

--- Find and return a file by its path.
---
--- If given an array of strings, then the first found file is returned.
--- For example, `findModuleCode({ "a/b/_index.lua", "a/b.lua" })` will try
--- `"a/b/_index.lua"` first, then `"a/b.lua"`. It will return contents
--- of the first file that exists.
---
--- Note: code is not cached. If target loader is 'net', this call will issue
--- a request to a code server. If target loader is 'drive' and the code has changed
--- since it was last loaded, this function will return the new version of the code.
---
--- @param path string|string[] file path, including its extension.
--- @return string? code module code.
--- @string string? realPath actual path to the `.lua` file that contains the code.
function ns.findModuleCode(path)
    if type(path) == "string" then
        local pathCandidatesStr = path
        path = {}
        for candidate in pathCandidatesStr:gmatch("[^:]+") do
            table.insert(path, candidate)
        end
    end
    return loader(path)
end

--- Get name of the loader that was used to load the code.
---
--- @return "drive"|"net"|"bootstrap"|string
function ns.getLoaderKind()
    assert(loader, "'getLoaderKind' called before 'init'", 2)
    return bootloaderConfig.target
end

--- Get bootloader config.
---
--- @return ammcore.bootloader.BootloaderConfig config config that was used to init the bootloader.
function ns.getBootloaderConfig()
    assert(loader, "'getBootloaderConfig' called before 'init'", 2)
    return bootloaderConfig
end

--- Get directory for dev packages if one is configured.
---
--- Return `nil` if bootloader target is not `drive`.
---
--- @return string? devRoot directory where dev packages are installed.
function ns.getDevRoot()
    assert(loader, "'getDevRoot' called before 'init'", 2)
    return bootloaderConfig.devRoot
end

--- Get directory for internal AMM files.
---
--- Return `nil` if bootloader target is not `drive`.
---
--- @return string? srvRoot directory where AMM stores its internal data, including installed modules.
function ns.getSrvRoot()
    assert(loader, "'getSrvRoot' called before 'init'", 2)
    return bootloaderConfig.srvRoot
end

--- Given a real file path (as returned by `findModuleCode`), look up associated module name.
---
--- @param realPath string real path to a file, as returned by `findModuleCode` or `ammcore._util.debug.getFile`.
--- @return string?
function ns.getModuleByRealPath(realPath)
    assert(loader, "'getModuleByRealPath' called before 'init'", 2)
    return _paths[realPath]
end

--- Get module name at stack frame ``n``.
---
--- @param n integer? number of stack frame from the top of the stack. By default, return module of the calling frame.
--- @return string module module name.
function ns.getMod(n)
    return ns.getModuleByRealPath(ns.getFile((n or 1) + 1)) or "<unknown>"
end

--- Get file name at stack frame ``n``.
---
--- @param n integer? number of stack frame from the top of the stack. By default, return file of the calling frame.
--- @return string file file name.
function ns.getFile(n)
    return debug.getinfo((n or 1) + 1).source:match("^@(.-)$") or "<unknown>"
end

--- Get current line number at stack frame ``n``.
---
--- @param n integer? number of stack frame from the top of the stack. By default, return line at the calling frame.
--- @return integer line line number.
function ns.getLine(n)
    return debug.getinfo((n or 1) + 1).currentline or 1
end

--- Get current location at stack frame ``n``.
---
--- @param n integer? number of stack frame from the top of the stack. By default, return location of the calling frame.
--- @return string location location, consists of file name and line number.
function ns.getLoc(n)
    local loc = string.format(
        "%s:%s",
        ns.getFile((n or 1) + 1),
        ns.getLine((n or 1) + 1)
    )
    return loc
end

return ns
