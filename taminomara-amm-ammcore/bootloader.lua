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

--- A bootloader config.
---
--- @class ammcore.bootloader.BootloaderConfig: { [string]: unknown }
local BootloaderConfig = {}

--- Which program to run after the system is fully booted.
--- This can be any Lua package installed on your AMM code server.
---
--- Some standard programs include:
---
--- - ".help" -- print this message and stop the computer;
--- - ".eeprom" -- do nothing and continue executing EEPROM;
---
--- On code server, these are also available:
---
--- - ".provision" -- install "ammcore" locally and replace EEPROM
---   with a default one. This will be the first program that you run
---   on a new computer.
--- - ".server" -- start code server;
--- - ".lspkg" -- list all locally installed packages;
--- - ".check" -- check integrity of installed packages;
--- - ".install" -- install packages from `config.packages`;
--- - ".upgrade" -- upgrade all packages to the latest version;
--- - "ammtest.bin.main" -- run unit tests on local dev packages.
---
--- If "prog" is not specified in the config, it is parsed from computer's nick.
--- If computer's nick is empty, ".eeprom" is implied.
---
--- .. note::
---
---    Starting program name with a dot is a shortcut for "ammcore.bin.<program>".
---
--- @type string?
BootloaderConfig.prog = nil

--- Where to find installed AMM packages. Available values are:
---
--- - "drive" will load AMM code from this computer's hard drive.
--- - "net" will fetch AMM code from another computer (a code server)
---   using NetBoot protocol.
---
--- Target is configured by EEPROM depending on specific computer's purpose.
--- It is required to initialize the bootloader.
---
--- @type "drive"|"net"
BootloaderConfig.target = nil

--- Only meaningful on code server. Directory with user code
--- (a.k.a. dev packages). Default is "/".
---
--- Dev root is always configured by EEPROM. It is required to initialize
--- the bootloader.
---
--- @type string Directory for dev packages if one is configured, used when `target` is ``drive``.
BootloaderConfig.devRoot = nil

--- Directory with internal AMM files. Default is "/.amm".
---
--- Srv root is always configured by EEPROM. It is required to initialize
--- the bootloader.
---
--- @type string
BootloaderConfig.srvRoot = nil

--- Id of a hard drive with AMM files.
---
--- This setting is used by EEPROM to mount a hard drive
--- and locate the bootstrap script. However, it might not be set if user
--- implemented a custom EEPROM version.
---
--- @type string?
BootloaderConfig.driveId = nil

--- Directory where hard drive will be mounted. Default is "/".
---
--- This setting is used by EEPROM to mount a hard drive
--- and locate the bootstrap script. However, it might not be set if user
--- implemented a custom EEPROM version.
---
--- @type string?
BootloaderConfig.mountPoint = nil

--- Address of the code server, used when tartet is "net".
---
--- By default it is discovered through a broadcast request.
---
--- @type string? Address of the code server, used when `target` is ``net``.
BootloaderConfig.bootAddr = nil

--- Port of the code server, used when tartet is "net". Default is "0x1CD".
---
--- @type integer? Port of the code server, used when `target` is ``net``.
BootloaderConfig.bootPort = nil

--- Only meaningful on code server. This setting lists all packages
--- that should be installed.
---
--- @type string[]?
BootloaderConfig.packages = nil

--- Configuration for loggers.
---
--- @type table<string, ammcore.log.Level> configuration for loggers.
BootloaderConfig.logLevels = nil

--- @type ammcore.server.ServerApi?
local serverApi
--- @type ammcore.bootloader.BootloaderConfig?
local bootloaderConfig
--- @type (fun(path: string[]): code: string | nil, realPath: string | nil)?
local coreModuleResolver = nil
--- @type table<string, ammcore.pkg.package.PackageVersion>?
local installedPackages
--- @type ammcore.log.Logger?
local logger

if require then
    computer.log(2, "[ammcore.bootloader] WARNING: 'require' function is already present")
end

--- @param coreCodeLocation table<string, string> | string
--- @return fun(path: string[]): code: string | nil, realPath: string | nil
local function makeCoreModuleResolver(coreCodeLocation)
    if type(coreCodeLocation) == "string" then
        return function(pathCandidates)
            for _, candidate in ipairs(pathCandidates) do
                candidate = filesystem.path(2, candidate)
                local realPath
                if candidate == "ammcore" or candidate:match("^ammcore/") then
                    realPath = candidate:gsub("^ammcore/?", "")
                elseif candidate == "taminomara-amm-ammcore" or candidate:match("^taminomara%-amm%-ammcore/") then
                    realPath = candidate:gsub("^taminomara%-amm%-ammcore/?", "")
                end
                if realPath then
                    realPath = filesystem.path(coreCodeLocation, realPath)
                    if filesystem.exists(realPath) then
                        local fd = filesystem.open(realPath, "r")
                        local _ <close> = setmetatable({}, { __close = function() fd:close() end })

                        local content = ""
                        while true do
                            local chunk = fd:read(120 * 1024)
                            if not chunk or chunk:len() == 0 then
                                break
                            end
                            content = content .. chunk
                        end

                        return content, realPath
                    end
                end
            end
        end
    else
        return function(pathCandidates)
            for _, candidate in ipairs(pathCandidates) do
                candidate = filesystem.path(2, candidate)
                local realPath
                if candidate == "ammcore" or candidate:match("^ammcore/") then
                    realPath = candidate:gsub("^ammcore/?", "")
                elseif candidate == "taminomara-amm-ammcore" or candidate:match("^taminomara%-amm%-ammcore/") then
                    realPath = candidate:gsub("^taminomara%-amm%-ammcore/?", "")
                end
                if realPath then
                    if coreCodeLocation[realPath] then
                        return coreCodeLocation[realPath], "bootstrap://" .. realPath
                    end
                end
            end
        end
    end
end

--- @param mod string
--- @return string
--- @return string[]
local function canonizeModName(mod)
    if type(mod) ~= "string" then
        error(string.format("expected a string, got %s", type(mod)), 3)
    end

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

--- Load the given module, run it, and forward any returned value.
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
    local mod, pathCandidates = canonizeModName(modname)

    if not _modules[mod] then
        local code, realPath
        if serverApi then
            code, realPath = serverApi:getCode(pathCandidates)
        elseif coreModuleResolver then
            code, realPath = coreModuleResolver(pathCandidates)
        else
            error("'require' called before 'main'")
        end
        if not code or not realPath then
            error(string.format("no module named %s", mod), 2)
        end

        if installedPackages and logger then
            local requiringMod = ns.getMod(2):match("^[^.]*")
            local requiringPkg = installedPackages["taminomara-amm-" .. requiringMod] or installedPackages[requiringMod]

            local requiredMod = mod:match("^[^.]*")
            local requiredPkg = installedPackages["taminomara-amm-" .. requiredMod] or installedPackages[requiredMod]

            if
                requiringPkg
                and requiredPkg
                and requiringPkg.name ~= requiredPkg.name
                and requiringPkg.name ~= "taminomara-amm-ammcore"
                and requiringPkg.name ~= "taminomara-amm-ammtest"
            then
                local requirements = requiringPkg:getAllRequirements()
                if not requirements[requiredPkg.name] then
                    logger:warning(
                        "Module %s requires modules from %s, but %s is not listed as its dependency",
                        requiringMod,
                        requiredMod,
                        requiredMod
                    )
                end
            elseif
                requiringPkg
                and requiredPkg
                and requiringPkg.name ~= requiredPkg.name
                and requiringPkg.name == "taminomara-amm-ammtest"
            then
                local requirements = requiredPkg:getDevRequirements()
                if not requirements["taminomara-amm-ammtest"] then
                    logger:warning(
                        "Module %s should add taminomara-amm-ammtest to its dev dependencies",
                        requiredMod
                    )
                end
            end
        end

        if logger and _paths[realPath] then
            logger:warning(
                "The same lua file is required with different names: %s and %s",
                mod,
                _paths[realPath]
            )
        end

        _modules[mod] = { loaded = false }
        _paths[realPath] = mod

        local codeFn, err = load(code, "@" .. realPath, "bt", _ENV)
        if not codeFn then
            error(string.format("syntax error in %s: %s", realPath, err), 2)
        end

        _modules[mod] = { loaded = true, value = codeFn() or true }
    elseif not _modules[mod].loaded then
        error(string.format("circular import in %s", mod), 2)
    end

    return _modules[mod].value, _modules[mod].realPath
end

--- @param coreCodeLocation table<string, string> | string
local function updateAmmCore(coreCodeLocation)
    assert(bootloaderConfig)
    assert(serverApi)
    assert(logger)

    if type(coreCodeLocation) ~= "string" then
        logger:trace("Not checking ammcore version because bootstrap is used")
        return
    end

    local pkg = require "ammcore.pkg"
    local builder = require "ammcore.pkg.builder"

    logger:trace("Checking ammcore version")

    local provider = pkg.getPackageProvider(true)
    local localCorePackage
    for _, package in ipairs(provider:getLocalPackages()) do
        if package.name == "taminomara-amm-ammcore" then
            localCorePackage = package
        end
    end
    if not localCorePackage or localCorePackage.packageRoot ~= coreCodeLocation then
        logger:warning(
            "Unable to update local ammcore version: directory %s does not belong to any package",
            coreCodeLocation
        )
        return
    end

    local remoteVersion = serverApi:getAmmCoreVersion()
    local localVersion = localCorePackage.version

    if remoteVersion ~= localVersion then
        if localCorePackage.isDevMode then
            logger:warning(
                "Unable to update local ammcore version: ammcore installed in dev mode",
                coreCodeLocation
            )
        else
            logger:info(
                "Updating local ammcore version: %s -> %s",
                localVersion,
                remoteVersion
            )

            local version, archive = serverApi:getAmmCoreCode()
            local archiver = builder.PackageArchiver:FromArchive("taminomara-amm-ammcore", version, archive)
            filesystem.remove(coreCodeLocation, true)
            archiver:unpack(coreCodeLocation)

            logger:info("Update successful, restarting")
            computer.reset()
        end
    else
        logger:trace("Using ammcore version %s", localVersion)
    end
end

local function initDrive()
    assert(coreModuleResolver)
    assert(bootloaderConfig)
    assert(logger)

    local localApi = require "ammcore.server.localApi"
    local pkg = require "ammcore.pkg"
    local provider = pkg.getPackageProvider(true)
    local packages = provider:getLocalPackages()

    logger:trace("Initializing local code server")

    serverApi = localApi.ServerApi:New(packages, coreModuleResolver)
    installedPackages = serverApi:lsPkg()

    logger:trace("Local code server initialized")
end

local function initNet()
    assert(coreModuleResolver)
    assert(bootloaderConfig)
    assert(logger)

    local remoteApi = require "ammcore.server.remoteApi"

    logger:trace("Initializing remote code server")

    local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard? ]]
    if not networkCard then
        error("config.target is net, but no network card present")
    end

    bootloaderConfig.bootPort = bootloaderConfig.bootPort or 0x1CD
    if type(bootloaderConfig.bootPort) ~= "number" then
        error(string.format("config.bootPort has invalid value %s", bootloaderConfig.bootPort))
    end

    if not bootloaderConfig.bootAddr then
        logger:trace("Discovering available code servers")

        event.listen(networkCard)
        networkCard:open(bootloaderConfig.bootPort)
        networkCard:broadcast(bootloaderConfig.bootPort, "getAmmCoreVersion")

        local deadline = computer.millis() + 2000
        local name, sender, port, receivedMessage
        while true do
            local now = computer.millis()
            if now > deadline then
                error("timeout while waiting for response from a code server")
            end

            name, _, sender, port, receivedMessage = event.pull(now - deadline)
            if
                name == "NetworkMessage"
                and port == bootloaderConfig.bootPort
                and receivedMessage == "rcvAmmCoreVersion"
            then
                bootloaderConfig.bootAddr = sender
                break
            end
        end
    end

    serverApi = remoteApi.ServerApi:New(
        networkCard,
        bootloaderConfig.bootAddr,
        bootloaderConfig.bootPort,
        2000,
        coreModuleResolver
    )
    installedPackages = serverApi:lsPkg()

    logger:trace("Remote code server initialized")
    logger:info("Using amm code server %s", bootloaderConfig.bootAddr)
end

--- Initialize and install the global `require` function,
--- then start a user script configured via computer's nick
--- or `config.prog <ammcore.bootloader.BootloaderConfig.prog>`.
---
--- @param config ammcore.bootloader.BootloaderConfig bootloader config.
--- @param coreCodeLocation table<string, string> | string code table from the bootstrap script.
function ns.main(config, coreCodeLocation)
    if serverApi then
        error("bootloader is already initialized")
    end

    if not config then
        error("config is not defined")
    elseif not config.target then
        error("config.target is not defined")
    end

    config.devRoot = filesystem.path(1, config.devRoot or "/")
    if type(config.devRoot) ~= "string" then
        error(string.format("config.devRoot has invalid value %s", config.devRoot))
    elseif not filesystem.exists(config.devRoot) or not filesystem.isDir(config.devRoot) then
        error(string.format("config.devRoot does not exist or not a directory: %s", config.devRoot))
    end

    config.srvRoot = filesystem.path(1, config.srvRoot or "/.amm")
    if type(config.srvRoot) ~= "string" then
        error(string.format("config.srvRoot has invalid value %s", config.srvRoot))
    elseif not filesystem.exists(config.srvRoot) or not filesystem.isDir(config.srvRoot) then
        error(string.format("config.srvRoot does not exist or not a directory: %s", config.srvRoot))
    end

    if not config.logLevels then
        config.logLevels = {}
    elseif type(config.logLevels) ~= "table" then
        error("config.logLevels should be a table")
    end
    for k, v in pairs(config.logLevels) do
        if type(k) ~= "string" or type(v) ~= "number" then
            error(string.format("invalid log level %s: %s", k, v))
        end
    end

    bootloaderConfig = config
    coreModuleResolver = makeCoreModuleResolver(coreCodeLocation)

    local nick = require "ammcore.nick"
    local log = require "ammcore.log"

    logger = log.Logger:New()

    local parsedNick = nick.parse(computer.getInstance().nick)
    do
        local level = parsedNick:getOne("logLevel", tostring)
        if level then
            local levelInt = log.levelFromName(level)
            if not levelInt then
                error(string.format("unknown log level %s", level))
            end
            config.logLevels[""] = config.logLevels[""] or levelInt
        else
            config.logLevels[""] = config.logLevels[""] or log.Level.Info
        end
    end

    if not config.prog then
        config.prog = parsedNick:getPos(1, tostring)
    end
    if not config.prog then
        logger:error(
            "AMM is unable to determine which program "
            .. "to run, and will hand execution back to EEPROM. If this is "
            .. "intended, set `config.prog=\".eeprom\"`."
        )
    elseif type(config.prog) ~= "string" then
        error("config.prog is not a string")
    elseif config.prog:len() == 0 then
        error("config.prog is empty")
    end
    if config.prog and config.prog:sub(1, 1) == "." then
        config.prog = "ammcore.bin" .. config.prog
    end

    if type(coreCodeLocation) == "string" then
        logger:debug("Using ammcore from %s", coreCodeLocation)
    else
        logger:debug("Using ammcore from bootstrap")
    end

    if config.target == "drive" then
        initDrive()
    elseif config.target == "net" then
        initNet()
        updateAmmCore(coreCodeLocation)
    end

    logger:trace("Bootloader config = %s", log.p(config))

    if config.prog then
        logger:debug("Booting %s", config.prog)
        require(config.prog)
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
--- @return string? realPath actual path to the `.lua` file that contains the code.
function ns.findModuleCode(path)
    assert(bootloaderConfig and serverApi, "'findModuleCode' called before 'main'", 2)
    return serverApi:getCode(path)
end

--- @return ammcore.server.ServerApi
function ns.getServerApi()
    assert(bootloaderConfig and serverApi, "'getServerApi' called before 'main'", 2)
    return serverApi
end

--- Get name of the loader that was used to load the code.
---
--- @return "drive"|"net"
function ns.getLoaderKind()
    assert(bootloaderConfig, "'getLoaderKind' called before 'main'", 2)
    return bootloaderConfig.target
end

--- Get bootloader config.
---
--- @return ammcore.bootloader.BootloaderConfig config config that was used to init the bootloader.
function ns.getBootloaderConfig()
    assert(bootloaderConfig, "'getBootloaderConfig' called before 'main'", 2)
    return bootloaderConfig
end

--- Get directory for dev packages if one is configured.
---
--- Return `nil` if bootloader target is not `drive`.
---
--- @return string devRoot directory where dev packages are installed.
function ns.getDevRoot()
    assert(bootloaderConfig, "'getDevRoot' called before 'main'", 2)
    return bootloaderConfig.devRoot
end

--- Get directory for internal AMM files.
---
--- Return `nil` if bootloader target is not `drive`.
---
--- @return string srvRoot directory where AMM stores its internal data, including installed modules.
function ns.getSrvRoot()
    assert(bootloaderConfig, "'getSrvRoot' called before 'main'", 2)
    return bootloaderConfig.srvRoot
end

--- Given a real file path (as returned by `findModuleCode`), look up associated module name.
---
--- @param realPath string real path to a file, as returned by `findModuleCode` or `ammcore._util.debug.getFile`.
--- @return string?
function ns.getModuleByRealPath(realPath)
    assert(bootloaderConfig, "'getModuleByRealPath' called before 'main'", 2)
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
