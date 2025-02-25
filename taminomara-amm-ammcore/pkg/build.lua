local filesystemHelpers = require "ammcore/util/filesystemHelpers"

--- Build script API.
local ns = {}

--- Global object available in the build script (`_build.lua`).
---
--- Build script is called when the package is being built to customize
--- final contents of the package.
---
--- @class ammcore.pkg.build.Build
local Build = {}

Build.__index = Build

--- Name of the package that is being built.
---
--- @type string
Build.name = nil

--- Version of the package that is being built.
---
--- @type string
Build.version = nil

--- Do not mess with this. But if you do, make sure that all paths are normalized
--- via `filesystem.path(2, ...)`.
---
--- @private
--- @type table<string, string>
Build.__outputFiles = nil

--- Copy a directory to the package.
---
--- @param src string directory source, relative to the repository root.
--- @param dst string directory destination, relative to the package root.
--- @param pat string pattern for files to include. Defaults to `"%.lua$"`, i.e. all lua files.
--- @param override boolean? whether to override existing files.
function Build:copyDir(src, dst, pat, override)
    pat = pat or "%.lua$"

    if type(src) ~= "string" then error("Expected a string, got %s", src) end
    if type(dst) ~= "string" then error("Expected a string, got %s", dst) end
    if type(pat) ~= "string" then error("Expected a string, got %s", pat) end

    if not filesystem.exists(src) then
        error("Directory does not exist: " .. src)
    end
    if not filesystem.isDir(src) then
        error("Not a directory: " .. src)
    end

    ns.travelDir(src, dst, pat, self.__outputFiles, override)
end

--- Copy a file to the package.
---
--- @param src string file source, relative to the repository root.
--- @param dst string file destination, relative to the package root.
--- @param override boolean?
function Build:copyFile(src, dst, override)
    if type(src) ~= "string" then error("Expected a string, got %s", src) end
    if type(dst) ~= "string" then error("Expected a string, got %s", dst) end

    if not filesystem.exists(src) then
        error("File does not exist: " .. src)
    end
    if not filesystem.isFile(src) then
        error("Not a file: " .. src)
    end

    src = filesystem.path(1, src)
    dst = filesystem.path(2, dst)

    if override or not self.__outputFiles[dst] then
        self.__outputFiles[dst] = filesystemHelpers.readFile(src)
    end
end

--- Add a file to the package.
---
--- @param dst string file destination, relative to the package root.
--- @param contents string file contents.
--- @param override boolean?
function Build:addFile(dst, contents, override)
    if type(dst) ~= "string" then error("Expected a string, got %s", dst) end
    if type(contents) ~= "string" then error("Expected a string, got %s", contents) end

    dst = filesystem.path(2, dst)

    if override or not self.__outputFiles[dst] then
        self.__outputFiles[dst] = contents
    end
end

if false then
    --- Global object available in the build script (`_build.lua`).
    ---
    --- Build script is called when the package is being built to customize
    --- final contents of the package.
    ---
    --- @type ammcore.pkg.build.Build
    build = nil
end

--- Travel directory and add all files that match the pattern to the `outputFiles`.
---
--- @param src string
--- @param dst string
--- @param pat string
--- @param outputFiles table<string, string>
--- @param override boolean?
function ns.travelDir(src, dst, pat, outputFiles, override)
    for _, name in ipairs(filesystem.children(src)) do
        local src = filesystem.path(1, src, name)
        local dst = filesystem.path(2, dst, name)
        if filesystem.isFile(src) then
            if string.match(src, pat) then
                if override or not outputFiles[dst] then
                    outputFiles[dst] = filesystemHelpers.readFile(src)
                end
            end
        elseif filesystem.isDir(src) then
            ns.travelDir(src, dst, pat, outputFiles, override)
        end
    end
end

--- Call the build script.
---
--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param outputFiles table<string, string>
function ns.callBuildScript(name, version, outputFiles)
    local buildScriptPath = filesystem.path(name, "_build.lua")

    if not filesystem.exists(buildScriptPath) then
        return
    end

    local build = setmetatable(
        { name = name, version = tostring(version), __outputFiles = outputFiles },
        Build
    )

    local env = {
        build = build,
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
    local fn, err = load(code, "<build script>", "bt", env)
    if not fn then
        error(string.format("BuildError: failed to parse %s: %s", buildScriptPath, err))
    end

    fn()
end

return ns
