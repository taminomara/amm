local filesystemHelpers = require "ammcore.util.filesystemHelpers"
local class             = require "ammcore.util.class"
local log               = require "ammcore.util.log"
local packageJson       = require "ammcore.pkg.packageJson"
local json              = require "ammcore.contrib.json"

--- Build script API.
local ns                = {}

local logger            = log.Logger:New()

--- Creates and unpacks package archives.
---
--- @class ammcore.pkg.packageBuilder.PackageArchiver: class.Base
ns.PackageArchiver      = class.create("PackageArchiver")

--- @param name string
--- @param version ammcore.pkg.version.Version
---
--- @generic T: ammcore.pkg.packageBuilder.PackageArchiver
--- @param self T
--- @return T
function ns.PackageArchiver:New(name, version)
    self = class.Base.New(self)

    --- Name of the package that is being built.
    ---
    --- @type string
    self.name = name

    --- Version of the package that is being built.
    ---
    --- @type ammcore.pkg.version.Version
    self.version = version

    return self
end

--- Construct builder from a packaged archive data (i.e. the result of `build`).
---
--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param data string
function ns.PackageArchiver:FromArchive(name, version, data)
    self = self:New(name, version)

    local fn, err = load("return " .. data, "<package archive>", "bt", {})
    if not fn then
        error(string.format("failed unpacking %s == %s: %s", self.name, self.version, err), 0)
    end

    self._outputFiles = fn()

    self:_verify()

    return self
end

--- Unpack the package to the given directory.
---
--- @param pkgRoot string
function ns.PackageArchiver:unpack(pkgRoot)
    self:_verify()

    local filenames = {}
    for path in pairs(self._outputFiles) do
        table.insert(filenames, path)
    end
    table.sort(filenames)

    for _, filename in ipairs(filenames) do
        local content = self._outputFiles[filename]
        local filePath = filesystem.path(pkgRoot, filesystem.path(2, filename))
        local fileDir = filePath:match("^(.*)/[^/]*$")
        if not filesystem.exists(fileDir) then
            logger:trace("Creating %s", fileDir)
            assert(filesystem.createDir(fileDir, true))
        end
        logger:trace("Writing %s", filePath)
        filesystemHelpers.writeFile(filePath, content)
    end
end

--- @protected
function ns.PackageArchiver:_verify()
    if type(self._outputFiles) ~= "table" then
        error(string.format("failed unpacking %s == %s: invalid archive data %s", self.name, self.version, self._outputFiles))
    end

    for filename, contents in pairs(self._outputFiles) do
        if type(filename) ~= "string" then
            error(string.format("failed unpacking %s == %s: invalid file name %s", self.name, self.version, filename))
        end
        if type(contents) ~= "string" then
            error(string.format("failed unpacking %s == %s: invalid file contents for file %s", self.name, self.version,
                filename))
        end
        if filename ~= filesystem.path(2, filename) then
            error(string.format("failed unpacking %s == %s: got a non-normalized file name %s", self.name, self.version,
                filename))
        end
    end

    local metadata = self._outputFiles[".ammpackage.json"]
    if not metadata then
        error(string.format(
            "failed unpacking %s == %s: file .ammpackage.json not found",
            self.name, self.version
        ), 0)
    end

    local parserMetadata
    do
        local ok, err = pcall(function() parserMetadata = json.decode(metadata) end)
        if not ok then
            error(string.format("failed unpacking %s == %s: invalid .ammpackage.json: %s", self.name, self.version, err))
        end
    end

    local version, _, _, data = packageJson.parse(
        parserMetadata,
        string.format(".ammpackage.json from archive %s == %s", self.name, self.version)
    )
    if data.name ~= self.name then
        error(string.format(
            "failed unpacking %s == %s: name from package contents doesn't match name from package metadata",
            self.name, self.version
        ), 0)
    end
    if version ~= self.version then
        error(string.format(
            "failed unpacking %s == %s: version from package contents doesn't match version from package metadata",
            self.name, self.version
        ), 0)
    end
end

--- Get read-only view of table that maps package filenames to their contents.
---
--- @return table<string, string>
function ns.PackageArchiver:getCode()
    return setmetatable(
        {},
        {
            __index = self._outputFiles,
            __newindex = function() error("this table is read-only") end,
            __pairs = function(self) return pairs(getmetatable(self).__index) end
        }
    )
end

--- Compile the package distribution and return it as a string.
---
--- @return string
function ns.PackageArchiver:build()
    self:_verify()

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

--- Manages files that will end up in the final package distribution.
---
--- @class ammcore.pkg.packageBuilder.PackageBuilder: ammcore.pkg.packageBuilder.PackageArchiver
ns.PackageBuilder = class.create("PackageBuilder", ns.PackageArchiver)

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param devRoot string
--- @param pkgRoot string
---
--- @generic T: ammcore.pkg.packageBuilder.PackageBuilder
--- @param self T
--- @return T
function ns.PackageBuilder:New(name, version, devRoot, pkgRoot)
    self = ns.PackageArchiver.New(self, name, version)

    --- Root directory of the dev installation.
    ---
    --- @type string
    self.devRoot = devRoot

    --- Root directory of the package.
    ---
    --- @type string
    self.pkgRoot = pkgRoot

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
--- @param override boolean? whether to override existing files.
function ns.PackageBuilder:copyDir(src, dst, override)
    if type(src) ~= "string" then error("expected src to be a string, got %s", src) end
    if type(dst) ~= "string" then error("expected dst to be a string, got %s", dst) end

    src = filesystem.path(self.devRoot, src)

    if not filesystem.exists(src) then
        error("directory does not exist: " .. src)
    end
    if not filesystem.isDir(src) then
        error("not a directory: " .. src)
    end

    self:_travelDir(src, dst, override)
end

--- Copy a file to the package.
---
--- @param src string file source, relative to the dev root.
--- @param dst string file destination, relative to the package root.
--- @param override boolean?
function ns.PackageBuilder:copyFile(src, dst, override)
    if type(src) ~= "string" then error("expected src to be a string, got %s", src) end
    if type(dst) ~= "string" then error("expected dst to be a string, got %s", dst) end

    src = filesystem.path(self.devRoot, src)

    if not filesystem.exists(src) then
        error(string.format("file does not exist: %s", src))
    end
    if not filesystem.isFile(src) then
        error(string.format("not a file: %s", src))
    end

    src = filesystem.path(1, src)
    dst = filesystem.path(2, dst)

    if override or not self._outputFiles[dst] then
        logger:trace("Adding %s -> %s%s", src, dst, self._outputFiles[dst] and " [override]" or "")
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
        logger:trace("Adding <generated> -> %s%s", dst, self._outputFiles[dst] and " [override]" or " ")
        self._outputFiles[dst] = contents
    end
end

--- @private
--- @param src string
--- @param dst string
--- @param override boolean?
function ns.PackageBuilder:_travelDir(src, dst, override)
    for _, name in ipairs(filesystem.children(src)) do
        local src = filesystem.path(1, src, name)
        local dst = filesystem.path(2, dst, name)
        if filesystem.isFile(src) then
            if override or not self._outputFiles[dst] then
                logger:trace("Adding %s -> %s%s", src, dst, self._outputFiles[dst] and " [override]" or "")
                self._outputFiles[dst] = filesystemHelpers.readFile(src)
            end
        elseif filesystem.isDir(src) then
            self:_travelDir(src, dst, override)
        end
    end
end

return ns
