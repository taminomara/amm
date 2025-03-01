local filesystemHelpers = require "ammcore.util.filesystemHelpers"
local glob              = require "ammcore.contrib.glob"
local class             = require "ammcore.util.class"
local log               = require "ammcore.util.log"
local bootloader        = require "ammcore.bootloader"

--- Build script API.
local ns = {}

local logger = log.Logger:New()

--- Manages files that will end up in the final package distribution.
---
--- @class ammcore.pkg.packageBuilder.PackageBuilder: class.Base
ns.PackageBuilder = class.create("PackageBuilder")

--- @param name string
--- @param version string
---
--- @generic T: ammcore.pkg.packageBuilder.PackageBuilder
--- @param self T
--- @return T
function ns.PackageBuilder:New(name, version)
    self = class.Base.New(self)

    --- Name of the package that is being built.
    ---
    --- @type string
    self.name = name

    --- Version of the package that is being built.
    ---
    --- @type string
    self.version = version

    --- Root directory of the dev installation.
    ---
    --- @type string
    self.devRoot = assert(bootloader.getDevRoot())

    --- Root directory of the package.
    ---
    --- @type string
    self.pkgRoot = filesystem.path(self.devRoot, name)

    --- Do not mess with this. But if you do, make sure that all paths are normalized
    --- via `filesystem.path(2, ...)` and relative to `pkgRoot`.
    ---
    --- @private
    --- @type table<string, string>
    self._outputFiles = {}

    return self
end

--- Copy a directory to the package.
---
--- @param src string directory source, relative to the development root.
--- @param dst string directory destination, relative to the package root.
--- @param pat string | string[] globs for files to include. Defaults to `*.lua`, i.e. all lua files.
--- @param override boolean? whether to override existing files.
function ns.PackageBuilder:copyDir(src, dst, pat, override)
    pat = pat or "*.lua"

    if type(src) ~= "string" then error("expected src to be a string, got %s", src) end
    if type(dst) ~= "string" then error("expected dst to be a string, got %s", dst) end

    src = filesystem.path(assert(bootloader.getDevRoot()), src)

    if not filesystem.exists(src) then
        error("directory does not exist: " .. src)
    end
    if not filesystem.isDir(src) then
        error("not a directory: " .. src)
    end

    self:_travelDir(src, dst, glob.compile(pat), override)
end

--- Copy a file to the package.
---
--- @param src string file source, relative to the dev root.
--- @param dst string file destination, relative to the package root.
--- @param override boolean?
function ns.PackageBuilder:copyFile(src, dst, override)
    if type(src) ~= "string" then error("expected src to be a string, got %s", src) end
    if type(dst) ~= "string" then error("expected dst to be a string, got %s", dst) end

    src = filesystem.path(assert(bootloader.getDevRoot()), src)

    if not filesystem.exists(src) then
        error(string.format("file does not exist: %s", src))
    end
    if not filesystem.isFile(src) then
        error(string.format("not a file: %s", src))
    end

    src = filesystem.path(1, src)
    dst = filesystem.path(2, dst)

    if override or not self._outputFiles[dst] then
        logger:debug("Include %s -> %s%s", src, dst, self._outputFiles[dst] and " [override]" or "")
        self._outputFiles[dst] = filesystemHelpers.readFile(src)
    end
end

--- Add a file to the package.
---
--- @param dst string file destination, relative to the package root.
--- @param contents string file contents.
--- @param override boolean?
function ns.PackageBuilder:addFile(dst, contents, override)
    if type(dst) ~= "string" then error("expected dst to be a string, got %s", dst) end
    if type(contents) ~= "string" then error("expected contents to be a string, got %s", contents) end

    dst = filesystem.path(2, dst)

    if override or not self._outputFiles[dst] then
        logger:debug("Write %s%s", dst, self._outputFiles[dst] and " [override]" or "")
        self._outputFiles[dst] = contents
    end
end

--- @private
--- @param src string
--- @param dst string
--- @param match fun(s: string): boolean
--- @param override boolean?
function ns.PackageBuilder:_travelDir(src, dst, match, override)
    for _, name in ipairs(filesystem.children(src)) do
        local src = filesystem.path(1, src, name)
        local dst = filesystem.path(2, dst, name)
        if filesystem.isFile(src) then
            if match(dst) then
                if override or not self._outputFiles[dst] then
                    logger:debug("Include %s -> %s%s", src, dst, self._outputFiles[dst] and " [override]" or "")
                    self._outputFiles[dst] = filesystemHelpers.readFile(src)
                end
            end
        elseif filesystem.isDir(src) then
            self:_travelDir(src, dst, match, override)
        end
    end
end

--- Get read-only view of table that maps package filenames to their contents.
---
--- @return table<string, string>
function ns.PackageBuilder:getCode()
    return setmetatable(
        {},
        {
            __index = self._outputFiles,
            __newindex = function () error("this table is read-only") end,
            __pairs = function (self) return pairs(getmetatable(self).__index) end
        }
    )
end

--- Compile the package distribution and return it as a string.
---
--- @return string
function ns.PackageBuilder:build()
    local code = {}
    local filenames = {}
    for path in pairs(self._outputFiles) do
        table.insert(filenames, path)
    end
    table.sort(filenames)
    for _, filename in ipairs(filenames) do
        table.insert(code, string.format("[%q]=%q", filename, self._outputFiles[filename]:gsub("\r\n", "\n")))
    end
    return string.format("{%s}", table.concat(code, ","))
end

if false then
    --- Global object available in the build script (`_build.lua`).
    ---
    --- Build script is called when the package is being built to customize
    --- final contents of the package.
    ---
    --- @type ammcore.pkg.packageBuilder.PackageBuilder
    builder = nil
end

--- Call the build script.
---
--- @param name string
--- @param builder ammcore.pkg.packageBuilder.PackageBuilder
function ns.callBuildScript(name, builder)
    local buildScriptPath = filesystem.path(assert(bootloader.getDevRoot()), name, "_build.lua")

    if not filesystem.exists(buildScriptPath) then
        return
    end

    local env = {
        builder = builder,
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
        xpcall = xpcall,
        debug = debug,
        filesystem = filesystem,
    }

    env._G = env

    local code = filesystemHelpers.readFile(buildScriptPath)
    local fn, err = load(code, "@" .. buildScriptPath, "t", env)
    if not fn then
        error(string.format("failed parsing %s: %s", buildScriptPath, err))
    end

    logger:debug("Running build script %s", buildScriptPath)
    fn()
end

return ns
