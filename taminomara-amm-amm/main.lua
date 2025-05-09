local manager = require "amm.lib.manager"
local nick = require "ammcore.nick"
local fin = require "ammcore._util.fin"
local class = require "ammcore.clas"
local controller = require "amm.lib.controller"

local parsedNick = nick.parse(computer.getInstance().nick)
local ctlPaths = parsedNick:getAll("ctl", tostring)

if not #ctlPaths then
    error("No controllers configured")
end

local manager = manager.Manager:New()

for _, ctlPath in ipairs(ctlPaths) do
    local path, name = ctlPath:match("^([%w%.]+)%.(%w+)$")
    if not path or not name then
        error(string.format("Invalid controller path %q", ctlPath))
    end

    local mod
    local ok, err = fin.xpcall(function() mod = require(path) end)
    if not ok then
        error(string.format("Invalid controller path %q: %s\n%s", ctlPath, err.message, err.trace))
    end
    if not mod then
        error(string.format("Invalid controller path %q: module %s is nil", ctlPath, path))
    end
    local ctl = mod[name]
    if not ctl then
        error(string.format("Invalid controller path %q: can't find class %s in module %s", ctlPath, name, path))
    end
    if not class.isChildOf(ctl, controller.Controller) then
        error(string.format("Invalid controller path %q: not a controller", ctlPath))
    end

    manager:addController(ctl:New())
end

manager:run()
