local nick              = require "ammcore.util.nick"
local packageName       = require "ammcore.pkg.packageName"
local localProvider     = require "ammcore.pkg.providers.local"
local filesystemHelpers = require "ammcore.util.filesystemHelpers"
local json              = require "ammcore.contrib.json"
local version           = require "ammcore.pkg.version"
local log               = require "ammcore.util.log"
local bootloader        = require "ammcore.bootloader"

local logger            = log.Logger:New()

local parsed            = nick.parse(computer.getInstance().nick)

local user, repo
do
    local repoArg = parsed:getOne("repo", tostring)
    if not repoArg then error("no github repo specified", 0) end
    user, repo = repoArg:match("^(.*)/(.*)$")
    if not user or not repo then error(string.format("invalid github repo %s", repoArg)) end
end

local tag
do
    local tagArg = parsed:getOne("tag", tostring)
    if not tagArg then error("no installation tag specified", 0) end
    tag = tagArg:match("^refs/tags/(.*)$")
    if not tag then error(string.format("invalid release tag %s", tagArg), 0) end
end

local name, ver = tag:match("^(.*)/v(.*)$")
if not name or not ver then error(string.format("invalid release tag %s", tag), 0) end

local isValid, packageUser, packageRepo = packageName.parseFullPackageName(name)
if not isValid then
    error(string.format("invalid release tag %s", tag), 0)
elseif not packageUser or not packageRepo then
    error(string.format("invalid release tag %s: not a github package", tag), 0)
elseif packageUser ~= user or packageRepo ~= repo then
    error(string.format("invalid release tag %s: package name does not match repo name", tag), 0)
end

local packageVer
do
    local ok, err = pcall(function() packageVer = version.parse(ver) end)
    if not ok then
        error(string.format("invalid release version %s: %s", tag, err), 0)
    end
end

print(string.format("Building %s == %s", name, packageVer))

local devRoot = assert(bootloader.getDevRoot(), "config.devRoot is not set")

local buildDir = filesystem.path(devRoot, "build")
if not filesystem.exists(buildDir) then
    assert(filesystem.createDir(buildDir, true), "failed creating build directory")
elseif not filesystem.isDir(buildDir) then
    error(string.format("not a directory: %s", buildDir), 0)
end

local devProvider = localProvider.LocalProvider:New(devRoot, true)
local pkgs, found = devProvider:findPackageVersions(name, false)
if not found or #pkgs ~= 1 then
    error(string.format("couldn't find a dev package named %s", name), 0)
end

local pkg = pkgs[1]

pkg:overrideVersion(packageVer)

logger:info("Writing build/ammpackage.json")
filesystemHelpers.writeFile(filesystem.path(buildDir, "ammpackage.json"), json.encode(pkg.data))

logger:info("Writing build/package")
filesystemHelpers.writeFile(filesystem.path(buildDir, "package"), pkg:build())

print(string.format("Successfully built %s == %s", name, packageVer))
