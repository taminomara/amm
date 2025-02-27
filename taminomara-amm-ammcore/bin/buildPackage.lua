local nick              = require "ammcore/util/nick"
local packageName       = require "ammcore/pkg/packageName"
local localProvider     = require "ammcore/pkg/providers/local"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"
local json              = require "ammcore/contrib/json"
local version           = require "ammcore/pkg/version"
local log               = require "ammcore/util/log"
local build             = require "ammcore/pkg/packageBuilder"

local logger            = log.Logger:New()

local parsed            = nick.parse(computer.getInstance().nick)

local user              = parsed:getOne("user", tostring)
if not user then error("No github user specified") end

local repo = parsed:getOne("repo", tostring)
if not repo then error("No github repo specified") end

local tag = parsed:getOne("tag", tostring)
if not tag then error("No installation tag specified") end

local name, ver = tag:match("^(.*)/v(.*)$")
if not name or not ver then
    error("Invalid release tag " .. tag)
end

logger:info("Building %s==%s", name, ver)

local isValid, packageUser, packageRepo = packageName.parseFullPackageName(name)
if not isValid then
    error("Invalid release tag " .. tag)
elseif not packageUser or not packageRepo then
    error("Invalid release tag " .. tag .. ": not a github package")
elseif packageUser ~= user or packageRepo ~= repo then
    error("Invalid release tag " .. tag .. ": package does not match repo")
end

do
    local parsedVer
    local ok, err = pcall(function() parsedVer = version.parse(ver) end)
    if not ok then
        error("Invalid release version " .. tag .. ": " .. err)
    end
    ver = tostring(parsedVer) -- canonize
end

local devProvider = localProvider.LocalProvider:New("/", true)
local pkgs, found = devProvider:findPackageVersions(name)
if not found or #pkgs ~= 1 then
    error("Could not find a dev package named " .. name)
end

local pkg = pkgs[1]

local metaData = pkg:serialize()
metaData.version = ver
local buildData = metaData.build or {}
local metaDataJson = json.encode(metaData)

filesystem.createDir("build/", true)

logger:info("Writing build/ammpackage.json")

filesystemHelpers.writeFile("build/ammpackage.json", metaDataJson)

logger:info("Writing build/package")

local builder = build.PackageBuilder:New(name, tostring(version))
builder:copyDir(name, "", buildData.files or {"*.lua"}, true)
if buildData.script then
    build.callBuildScript(name, buildData.script, builder)
end
builder:addFile("_version.lua", "return [[" .. tostring(pkg.version) .. "]]\n", true)
builder:addFile(".ammpackage.json", metaDataJson, true)

filesystemHelpers.writeFile("build/package", builder:build())

logger:info("Successfully built %s==%s", name, pkg.version)
