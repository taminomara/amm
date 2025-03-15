local test = require "ammtest"
local nick = require "ammcore.nick"

local parsed = nick.parse(computer.getInstance().nick)

local name
local tag = parsed:getOne("tag", tostring)
if tag then
    name = tag:match("^/refs/tags/([^/]*)")
end

test.main(name)
