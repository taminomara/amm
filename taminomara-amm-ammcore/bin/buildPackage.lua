local nick = require "ammcore/util/nick"
local packageName = require "ammcore/pkg/packageName"
local localProvider       = require "ammcore/pkg/providers/local"
local filesystemHelpers   = require "ammcore/util/filesystemHelpers"
local json                = require "ammcore/contrib/json"
local version             = require "ammcore/pkg/version"
local log                 = require "ammcore/util/log"

local logger = log.Logger:New()

local parsed = nick.parse(computer.getInstance().nick)

local user = parsed:getOne("user", tostring)
if not user then error("No github user specified") end

local repo = parsed:getOne("repo", tostring)
if not repo then error("No github repo specified") end

local tag = parsed:getOne("tag", tostring)
if not tag then error("No installation tag specified") end

local name, ver = tag:match("^(.*)/v(.*)$")
if not name or not ver then
    error("Invalid release tag " .. tag)
end

logger:info("Building %s", name)

local isValid, packageUser, packageRepo = packageName.parseFullPackageName(name)
if not isValid then
    error("Invalid release tag " .. tag)
elseif not packageUser or not packageRepo then
    error("Invalid release tag " .. tag .. ": not a github package")
elseif packageUser ~= user or packageRepo ~= repo then
    error("Invalid release tag " .. tag .. ": package does not match repo")
end

local devProvider = localProvider.LocalProvider:New("/", true)
local pkgs, found = devProvider:findPackageVersions(name)
if not found or #pkgs ~= 1 then
    error("Could not find a dev package named " .. name)
end

local pkg = pkgs[1]
pkg.version = version.parse(ver)

filesystem.createDir("build/", true)

logger:info("Writing build/ammpackage.json")
filesystemHelpers.writeFile("build/ammpackage.json", json.encode(pkg:serialize()))

logger:info("Writing build/ammcode.tsv")
local escapes = {
    ["\a"]=[[\a]], ["\b"]=[[\b]], ["\f"]=[[\f]], ["\n"]=[[\n]], ["\r"]=[[\r]],
    ["\t"]=[[\t]], ["\v"]=[[\v]], ["\\"]=[[\\]], ["\'"]=[[\']], ["\""]=[[\"]],
}
local code = ""
local function writeFile(root)
    for _, name in ipairs(filesystem.children(root)) do
        local path = filesystem.path(2, root, name)
        if filesystem.isFile(path) then
            code = code .. path .. "\t" .. filesystemHelpers.readFile(path):gsub("\r\n", "\n"):gsub("[\a\b\f\n\r\t\v\\\'\"]", escapes) .. "\n"
        elseif filesystem.isDir(path) then
            writeFile(path)
        end
    end
end
writeFile(name)
code = code .. name .. "/_version.lua\treturn [[" .. tostring(pkg.version) .. "]]\n"

filesystemHelpers.writeFile("build/ammcode.tsv", code)

logger:info("Successfully built %s version %s", name, pkg.version)
