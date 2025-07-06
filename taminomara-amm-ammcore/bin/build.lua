local nick = require "ammcore.nick"
local packageName = require "ammcore.pkg.packageName"
local localProvider = require "ammcore.pkg.providers.local"
local fsh = require "ammcore.fsh"
local json = require "ammcore._contrib.json"
local version = require "ammcore.pkg.version"
local log = require "ammcore.log"
local bootloader = require "ammcore.bootloader"

if bootloader.getLoaderKind() ~= "drive" then
    computer.panic("Program \".build\" only works with drive loader")
end

local logger = log.getLogger()

local devRoot = assert(bootloader.getDevRoot(), "config.devRoot is not set")
local devProvider = localProvider.LocalProvider(devRoot, true)

local parsed = nick.parse(computer.getInstance().nick)
local packages = parsed:getAll("package", tostring)

if #packages == 0 then
    error("no packages were provided")
end

-- Parse repo.
local repoArg = parsed:getOne("repo", tostring)
if not repoArg then
    error("no github repo specified", 0)
end
local user, repo = repoArg:match("^(.*)/(.*)$")
if not user or not repo then
    error(string.format("invalid github repo %s", repoArg))
end

-- Parse packages.
local built = {}
for _, package in ipairs(packages) do
    -- Parse github tag.
    package = package:gsub("^refs/tags/", "")
    local name, verTxt = package:match("^(.*)/v(.*)$")
    if not name or not verTxt then
        name, verTxt = package, nil
    end

    if built[name] then
        goto continue
    end
    built[name] = true

    -- Check package name.
    local isValid, packageUser, packageRepo = packageName.parseFullPackageName(name)
    if not isValid then
        error(string.format("invalid package %s", package), 0)
    elseif not packageUser or not packageRepo then
        error(string.format("invalid package %s: not a github package", package), 0)
    elseif packageUser ~= user or packageRepo ~= repo then
        error(string.format("invalid package %s: package name does not match repo name", package), 0)
    end

    -- Check package version.
    local ver
    if verTxt then
        local ok, err = pcall(function() ver = version.parse(verTxt) end)
        if not ok then
            error(string.format("invalid release version %s: %s", verTxt, err), 0)
        end
    end

    -- Find package.
    local pkgs, ok = devProvider:findPackageVersions(name, false)
    local pkg = pkgs[1]
    if not ok or #pkgs ~= 1 or not pkg then
        error(string.format("can't find dev package %s", package))
    end
    -- Set package version, if any.
    if ver then
        pkg:overrideVersion(ver)
    end

    -- Build package.
    local buildDir = filesystem.path(devRoot, "build", pkg.name)
    if not filesystem.exists(buildDir) then
        assert(filesystem.createDir(buildDir, true), "failed creating build directory")
    elseif not filesystem.isDir(buildDir) then
        error(string.format("not a directory: %s", buildDir), 0)
    end

    print(string.format("Building %s == %s", pkg.name, pkg.version))

    logger:info("Writing %s/ammpackage.json", buildDir)
    fsh.writeFile(filesystem.path(buildDir, "ammpackage.json"), json.encode(pkg.data))

    logger:info("Writing %s/package", buildDir)
    fsh.writeFile(filesystem.path(buildDir, "package"), pkg:build())

    print(string.format("Successfully built %s == %s", pkg.name, pkg.version))

    ::continue::
end
