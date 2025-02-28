local nick              = require "ammcore/util/nick"
local packageName       = require "ammcore/pkg/packageName"
local localProvider     = require "ammcore/pkg/providers/local"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"
local json              = require "ammcore/contrib/json"
local version           = require "ammcore/pkg/version"
local log               = require "ammcore/util/log"
local build             = require "ammcore/pkg/packageBuilder"
local array             = require "ammcore/util/array"
local bootloader        = require "ammcore/bootloader"

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
    tag = tagArg:match("^/refs/tags/(.*)$")
    if not tag then error(string.format("invalid release tag %s", tag), 0) end
end

local name, ver
do
    name, ver = tag:match("^(.*)/v(.*)$")
    if not name or not ver then error(string.format("invalid release tag %s", tag), 0) end
end

local isValid, packageUser, packageRepo = packageName.parseFullPackageName(name)
if not isValid then
    error(string.format("invalid release tag %s", tag), 0)
elseif not packageUser or not packageRepo then
    error(string.format("invalid release tag %s: not a github package", tag), 0)
elseif packageUser ~= user or packageRepo ~= repo then
    error(string.format("invalid release tag %s: package name does not match repo name", tag), 0)
end

do
    local parsedVer
    local ok, err = pcall(function() parsedVer = version.parse(ver) end)
    if not ok then
        error(string.format("invalid release version %s: %s", tag, err), 0)
    end
    ver = tostring(parsedVer) -- canonize
end

print(string.format("Building %s == %s", name, ver))

local devRoot = assert(bootloader.getDevRoot())
local buildDir = filesystem.path(devRoot, "build")

local devProvider = localProvider.LocalProvider:Dev()
local pkgs, found = devProvider:findPackageVersions(name)
if not found or #pkgs ~= 1 then
    error(string.format("could not find a dev package named %s", name), 0)
end

local pkg = pkgs[1]

local metaData = pkg:serialize()
metaData.version = ver
local buildData = metaData.build or {}
local metaDataJson = json.encode(metaData)

if not filesystem.exists(buildDir) then
    filesystem.createDir(buildDir, true)
elseif not filesystem.isDir(buildDir) then
    error(string.format("not a directory: %s", buildDir), 0)
end

logger:info("Writing build/ammpackage.json")

filesystemHelpers.writeFile(filesystem.path(buildDir, "ammpackage.json"), metaDataJson)

logger:info("Writing build/package")

local builder = build.PackageBuilder:New(name, tostring(version))

local allowedFiles = buildData.files or array.insertMany(
    {"*.lua", "README*", "LICENSE*", "!_build.lua", "!_test/*"},
    buildData.addFiles or {}
)

builder:copyDir(name, "", allowedFiles, true)
build.callBuildScript(name, builder)
builder:addFile("_version.lua", "return [[" .. tostring(pkg.version) .. "]]\n", true)
builder:addFile(".ammpackage.json", metaDataJson, true)

filesystemHelpers.writeFile(filesystem.path(buildDir, "package"), builder:build())

print(string.format("Successfully built %s == %s", name, pkg.version))
