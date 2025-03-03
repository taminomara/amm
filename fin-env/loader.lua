local _lfs = require "lfs"
local _http_request = require "http.request"

local _print = print
local _xpcall = xpcall
local _debug = debug
local _io = io --- @diagnostic disable-line: undefined-global
local _os = os --- @diagnostic disable-line: undefined-global

local _ENV = {
    _VERSION = _VERSION,
    assert = assert,
    collectgarbage = collectgarbage,
    error = error,
    getmetatable = getmetatable,
    ipairs = ipairs,
    load = load,
    next = next,
    pairs = pairs,
    pcall = pcall,
    print = print,
    rawequal = rawequal,
    rawget = rawget,
    rawlen = rawlen,
    rawset = rawset,
    select = select,
    setmetatable = setmetatable,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    coroutine = coroutine,
    math = math,
    string = string,
    table = table,
}

_G = _ENV

function xpcall(fn, ...)
    local args = { ... }
    local res
    local ok, err = _xpcall(function() res = { fn(table.unpack(args)) } end, debug.traceback)
    if not ok then
        if type(err) == "string" then
            local message, trace = err:match("^(.*)\nstack traceback:\n(.*)$")
            return false, { message = message or err, trace = trace or "" }
        else
            return false, { message = err, trace = "" }
        end
    else
        return true, table.unpack(res)
    end
end

local function request(_, url, method, data, ...)
    local req = _http_request.new_from_uri(url)
    req.headers:upsert(":method", method)
    req:set_body(data)
    for i = 1, select("#", ...) / 2 do
        req.headers:append(select(i, ...), select(i + 1, ...))
    end

    local headers, stream = req:go()
    local body = stream:get_body_as_string()

    local res = { tonumber(headers:get(":status")), body }
    for name, value in headers:each() do
        table.insert(res, name)
        table.insert(res, value)
    end

    return {
        _res = res,
        await = function(self) return self:get() end,
        get = function(self) return table.unpack(self._res) end,
        poll = function(self) return true, 0 end,
        canGet = function(self) return true end,
    }
end

local function ni(mod)
    return function()
        computer.panic("Not implemented in this environment: " .. mod)
    end
end

-- debug ----------------------------------------------------------------

debug = {}

debug.traceback = _debug.traceback

debug.getinfo = _debug.getinfo

-- objects --------------------------------------------------------------

local FINInternetCard = {}

FINInternetCard.request = request
FINInternetCard.hash = 0x12345
FINInternetCard.internalName = nil
FINInternetCard.internalPath = nil
FINInternetCard.nick = ""
FINInternetCard.id = ""
FINInternetCard.isNetworkComponent = true
FINInternetCard.numPowerConnections = 0
FINInternetCard.numFactoryConnections = 0
FINInternetCard.numFactoryOutputConnections = 0
FINInternetCard.location = nil
FINInternetCard.scale = nil
FINInternetCard.rotation = nil
FINInternetCard.getPowerConnectors = ni("FINInternetCard:getPowerConnectors")
FINInternetCard.getFactoryConnectors = ni("FINInternetCard:getFactoryConnectors")
FINInternetCard.getPipeConnectors = ni("FINInternetCard:getPipeConnectors")
FINInternetCard.getInventories = ni("FINInternetCard:getInventories")
FINInternetCard.getComponents = ni("FINInternetCard:getComponents")
FINInternetCard.getNetworkConnectors = ni("FINInternetCard:getNetworkConnectors")
FINInternetCard.getHash = ni("FINInternetCard:getHash")
FINInternetCard.getType = ni("FINInternetCard:getType")
FINInternetCard.isA = ni("FINInternetCard:isA")

local ComputerCase = {}
ComputerCase.hash = 0x12346
ComputerCase.internalName = nil
ComputerCase.internalPath = nil
ComputerCase.nick = ""
ComputerCase.id = ""
ComputerCase.isNetworkComponent = true
ComputerCase.stopComputer = ni("ComputerCase.stopComputer")
ComputerCase.startComputer = ni("ComputerCase.startComputer")
ComputerCase.getState = ni("ComputerCase.getState")
ComputerCase.getLog = ni("ComputerCase.getLog")
ComputerCase.numPowerConnections = 0
ComputerCase.numFactoryConnections = 0
ComputerCase.numFactoryOutputConnections = 0
ComputerCase.location = nil
ComputerCase.scale = nil
ComputerCase.rotation = nil
ComputerCase.getPowerConnectors = ni("ComputerCase:getPowerConnectors")
ComputerCase.getFactoryConnectors = ni("ComputerCase:getFactoryConnectors")
ComputerCase.getPipeConnectors = ni("ComputerCase:getPipeConnectors")
ComputerCase.getInventories = ni("ComputerCase:getInventories")
ComputerCase.getComponents = ni("ComputerCase:getComponents")
ComputerCase.getNetworkConnectors = ni("ComputerCase:getNetworkConnectors")
ComputerCase.getHash = ni("ComputerCase:getHash")
ComputerCase.getType = ni("ComputerCase:getType")
ComputerCase.isA = ni("ComputerCase:isA")

-- classes --------------------------------------------------------------

classes = {}

classes.FINInternetCard = FINInternetCard

-- component ------------------------------------------------------------

component = {}

component.proxy = ni("component.proxy")

component.findComponent = ni("component.findComponent")

-- computer -------------------------------------------------------------

computer = {}

function computer.skip()
    -- nothing to do here
end

function computer.magicTime()
    return _os.time()
end

function computer.getMemory()
    return 0, 0
end

function computer.getInstance()
    return ComputerCase
end

function computer.getPCIDevices(type)
    if not type or type == classes.FINInternetCard then
        return { classes.FINInternetCard }
    else
        return {}
    end
end

computer.media = nil

function computer.millis()
    return _os.clock() / 1000
end

function computer.reset()
    _os.exit(15)
end

function computer.stop()
    _os.exit(0)
end

function computer.setEEPROM(eeprom)
    computer.log(0, string.format("New EEPROM:\n%s", eeprom))
end

function computer.getEEPROM()
    return ""
end

function computer.beep() end

function computer.panic(err)
    computer.log(4, err)
    _os.exit(1)
end

function computer.textNotification()
    -- nothing to do here
end

function computer.attentionPing()
    -- nothing to do here
end

function computer.time()
    return _os.time()
end

function computer.promote()
    -- nothing to do here
end

function computer.demote()
    -- nothing to do here
end

function computer.isPromoted()
    return false
end

local _verbosity = {
    [0] = "\x1b[2m",
    [1] = "\x1b[0m",
    [2] = "\x1b[33m",
    [3] = "\x1b[31m",
    [4] = "\x1b[31m",
}

function computer.log(verbosity, message)
    print(_verbosity[verbosity] .. tostring(message) .. "\x1b[0m")
end

-- event ----------------------------------------------------------------

event = {}

event.listen = ni("event.listen")

event.listening = ni("event.listening")

event.pull = ni("event.pull")

event.ignore = ni("event.ignore")

event.ignoreAll = ni("event.ignoreAll")

event.clear = ni("event.clear")

event.filter = ni("event.filter")

event.registerListener = ni("event.registerListener")

event.queue = ni("event.queue")

event.waitFor = ni("event.waitFor")

event.loop = ni("event.loop")

-- filesystem -----------------------------------------------------------

filesystem = {}

--- @type table<string, any>
local mountPoints = {}

--- @param path string
--- @return string
local function normpath(path)
    local p = {}
    for dir in path:gmatch("([^/]+)") do
        if dir == "." then
            -- nothing
        elseif dir == ".." then
            if #p > 0 then
                table.remove(p)
            end
        else
            table.insert(p, dir)
        end
    end
    return table.concat(p, "/")
end

--- @param path string
--- @return any, string
local function findFs1(path)
    path = normpath(path)
    local prefix = ""
    local postfix = ""
    local foundFs
    for root, fs in pairs(mountPoints) do
        if root == "" then
            if prefix:len() == 0 then
                postfix = "./" .. path
                foundFs = fs
            end
        elseif (path .. "/"):sub(1, root:len() + 1) == (root .. "/") then
            if root:len() >= prefix:len() then
                prefix = root
                postfix = "./" .. path:sub(root:len() + 2)
                foundFs = fs
            end
        end
    end

    if not foundFs then
        error("path " .. path .. " is not on any mounted drive")
    end

    return foundFs, postfix
end

--- @param ... string
--- @return any fs
--- @return string ...
local function findFs(...)
    local foundFs
    local results = {}
    for _, path in ipairs({ ... }) do
        local fs, path = findFs1(path)
        if foundFs and fs ~= foundFs then
            error("Paths are on different file systems")
        end
        foundFs = fs
        table.insert(results, path)
    end
    if not foundFs then
        error("No paths were provided")
    end
    return foundFs, table.unpack(results)
end

local devFs = {
    drives = {}
}

function devFs:open(path, mode)
    error("This operation is not supported for /dev file system")
end

function devFs:createDir(path, recursive)
    error("This operation is not supported for /dev file system")
end

function devFs:remove(path, recusive)
    error("This operation is not supported for /dev file system")
end

function devFs:move(from, to)
    error("This operation is not supported for /dev file system")
end

function devFs:rename(path, name)
    error("This operation is not supported for /dev file system")
end

function devFs:exists(path)
    return self.drives[path:gsub("%./", "")] and true or false
end

function devFs:children(path)
    if path ~= "./" then
        error("This operation is not supported for /dev file system")
    end
    local children = {}
    for drive, _ in pairs(self.drives) do
        table.insert(children, drive)
    end
    table.sort(children)
    return children
end

function devFs:isFile(path)
    return false
end

function devFs:isDir(path)
    return false
end

function devFs:isNode(path)
    return self:exists(path)
end

local localFs = {}
localFs.__index = localFs
localFs.__name = "localFs"

function localFs:open(path, mode)
    path = filesystem.path(self.root, path)
    return _io.open(path, mode)
end

function localFs:createDir(path, recursive)
    path = filesystem.path(self.root, path)
    if recursive then
        local p = ""
        for component in path:gmatch("([^/]+)") do
            p = p .. component .. "/"
            if not _lfs.attributes(p, "mode") then
                local ok, err, code = _lfs.mkdir(p)
                if not ok then
                    return ok, err, code
                end
            end
        end
        return true
    else
        return _lfs.mkdir(path)
    end
end

function localFs:remove(path, recusive)
    path = filesystem.path(self.root, path)
    if self:isDir(path) then
        if recusive then
            for _, name in ipairs(self:children(path)) do
                if not self:remove(path .. "/" .. name, true) then
                    return false
                end
            end
        end
        return _lfs.rmdir(path)
    else
        return _os.remove(path)
    end
end

function localFs:move(from, to)
    if from == "./" or to == "./" then
        return false, "can't move file system root"
    else
        from, to = filesystem.path(self.root, from), filesystem.path(self.root, to)
        return _os.rename(from, to)
    end
end

function localFs:rename(path, name)
    if path == "./" then
        return false, "can't rename file system root"
    elseif name == "" or name:match("/") then
        return false, "name can't be empty or contain slashes"
    else
        return self:move(path, path:gsub("[^/]+$", name))
    end
end

function localFs:exists(path)
    path = filesystem.path(self.root, path)
    return _lfs.attributes(path, "mode") ~= nil
end

function localFs:children(path)
    path = filesystem.path(self.root, path)
    local res = {}
    for name in _lfs.dir(path) do
        if name ~= "." and name ~= ".." then
            table.insert(res, name)
        end
    end
    return res
end

function localFs:isFile(path)
    path = filesystem.path(self.root, path)
    return _lfs.attributes(path, "mode") == "file"
end

function localFs:isDir(path)
    path = filesystem.path(self.root, path)
    return _lfs.attributes(path, "mode") == "directory"
end

function localFs:isNode(path)
    return self:isFile(path) or self:isDir(path)
end

function filesystem.open(path, mode)
    local fs, path = findFs(path)
    return fs:open(path, mode)
end

function filesystem.createDir(path, recursive)
    local fs, path = findFs(path)
    return fs:createDir(path, recursive)
end

function filesystem.remove(path, recusive)
    local fs, path = findFs(path)
    return fs:remove(path, recusive)
end

function filesystem.move(from, to)
    local fs, from = findFs(from, to)
    return fs:move(from, to)
end

function filesystem.rename(path, name)
    local fs, path = findFs(path)
    return fs:rename(path, name)
end

function filesystem.exists(path)
    local fs, path = findFs(path)
    return fs:exists(path)
end

function filesystem.children(path)
    local fs, path = findFs(path)
    return fs:children(path)
end

function filesystem.isFile(path)
    local fs, path = findFs(path)
    return fs:isFile(path)
end

function filesystem.isDir(path)
    local fs, path = findFs(path)
    return fs:isDir(path)
end

function filesystem.isNode(path)
    local fs, path = findFs(path)
    return fs:isNode(path)
end

function filesystem.mount(device, mountPoint)
    local fs, drive = findFs(device)
    drive = drive:gsub("^%./", "")
    if not fs.drives or not fs.drives[drive] then
        error(string.format("%s is not a device", device))
    end
    mountPoints[normpath(mountPoint)] = setmetatable({ root = fs.drives[drive] }, localFs)
    return true
end

function filesystem.unmount(mountPoint)
    mountPoints[normpath(mountPoint)] = nil
    return true
end

function filesystem.initFileSystem(path)
    mountPoints[normpath(path)] = devFs
    return true
end

function filesystem.path(conversion, ...)
    local components = { ... }
    if type(conversion) == "string" then
        table.insert(components, 1, conversion)
        conversion = nil
    end

    local res = ""
    for _, component in ipairs(components) do
        if component:match("^/") then
            res = ""
        elseif res:len() > 0 and not res:match("/$") then
            res = res .. "/"
        end
        res = res .. component
    end

    if not conversion then
        return res
    elseif conversion == 0 then
        return (res:match("^/") or "") .. normpath(res)
    elseif conversion == 1 then
        return "/" .. normpath(res)
    elseif conversion == 2 then
        return normpath(res)
    elseif conversion == 3 then
        error("Conversion is not implemented")
    elseif conversion == 4 then
        error("Conversion is not implemented")
    elseif conversion == 5 then
        error("Conversion is not implemented")
    else
        error("Unknown conversion " .. tostring(conversion))
    end
end

filesystem.doFile = ni("filesystem.doFile")

filesystem.loadFile = ni("filesystem.loadFile")

filesystem.analyzePath = ni("filesystem.analyzePath")

filesystem.meta = ni("filesystem.meta")

filesystem.makeFileSystem = ni("filesystem.makeFileSystem")

filesystem.removeFileSystem = ni("filesystem.removeFileSystem")

-- future ---------------------------------------------------------------

future = {}

future.async = ni("future.async")

future.join = ni("future.join")

future.sleep = ni("future.sleep")

future.addTask = ni("future.addTask")

future.run = ni("future.run")

future.loop = ni("future.loop")

future.tasks = {}

async = ni("async")

sleep = function()
    -- nothing to do here
end

-- main -----------------------------------------------------------------

local function main(...)
    local remoteLoad = false
    local readingArgs = true
    local irlSrvRoot = "./.amm"
    local irlDevRoot = "./"

    local function usage()
        print("Usage: loader.lua [-h] [--remote] [--srv-root=<path>] [--dev-root=<path>] [--] <nick>")
        print("arguments:")
        print("  --remote    run amm in bootloader mode")
        print("  --srv-root  directory that is mapped to amm packages directory (default './.amm')")
        print("  --dev-root  directory that is mapped to dev packages directory (default './')")
        print("  nick        computer nick")
        print("note:")
        print("  use -- to separate flags from nick")
    end

    local flag, value

    local function cliError(msg, ...)
        usage()
        computer.panic(string.format(msg, ...))
    end
    local function hasValue()
        if not value then cliError("flag %s requires a value", flag) end
    end
    local function hasNoValue()
        if value then cliError("flag %s shouldn't have a value", flag) end
    end

    do
        local sep = ""
        for _, arg in ipairs({ ... }) do
            if readingArgs and arg == "--" then
                readingArgs = false
            elseif readingArgs and arg:sub(1, 1) == "-" then
                flag = arg:match("^%-%-?([%w_-]+)")
                value = arg:match("^%-%-?[%w_-]+=(.*)$")
                if flag == "remote" then
                    hasNoValue()
                    remoteLoad = true
                elseif flag == "srv-root" then
                    hasValue()
                    irlSrvRoot = value:gsub("/+$", "") .. "/"
                elseif flag == "dev-root" then
                    hasValue()
                    irlDevRoot = value:gsub("/+$", "") .. "/"
                else
                    cliError("unknown flag %s", flag)
                end
            else
                ComputerCase.nick = ComputerCase.nick .. sep .. arg
                sep = " "
            end
        end
    end

    local bootloaderApi

    local config = {
        devRoot = "/mnt/devRoot/",
        srvRoot = "/mnt/srvRoot/",
    }

    devFs.drives["devRoot"] = irlDevRoot
    devFs.drives["srvRoot"] = irlSrvRoot

    filesystem.initFileSystem("/dev")

    filesystem.mount("/dev/devRoot", config.devRoot)
    if not filesystem.exists(config.devRoot) then
        filesystem.createDir(config.devRoot, true)
    end
    filesystem.mount("/dev/srvRoot", config.srvRoot)
    if not filesystem.exists(config.srvRoot) then
        filesystem.createDir(config.srvRoot, true)
    end

    if remoteLoad then
        -- Download bootstrap code.
        local res, code = request(nil, "https://taminomara.github.io/amm/bootstrap.lua", "GET", ""):await()
        if not res then
            error("Failed fetching AMM loader: couldn't connect to server")
        elseif res ~= 200 then
            error("Failed fetching AMM loader: error " .. tostring(res))
        end

        -- Compile bootstrap code.
        local fn, err = load(code, "<bootstrap>", "bt", _ENV)
        if not fn then
            error("Failed parsing AMM loader: " .. tostring(err))
        end

        -- Init loader.
        bootloaderApi = fn(config)
    else
        config.target = "drive"

        local path
        local candidates = {
            filesystem.path(config.devRoot, "taminomara-amm-ammcore/bootloader.lua"),
            filesystem.path(config.srvRoot, "lib/taminomara-amm-ammcore/bootloader.lua"),
        }
        for _, candidate in ipairs(candidates) do
            if filesystem.exists(candidate) then
                path = candidate
                break
            end
        end

        if not path then
            error("Can't find loader")
        end

        local code = filesystem.open(path, "r"):read("a")

        local fn, err = load(code, "@" .. path, "bt", _ENV)
        if not fn then
            error(string.format("ImportError: failed to parse %s: %s", path, err))
        end

        bootloaderApi = fn()
    end

    bootloaderApi.init(config)
    require("ammcore.bin.main")
end

local ok, err = _xpcall(main, _debug.traceback, ...)
if not ok then
    computer.log(4, err)
    _os.exit(1)
end
