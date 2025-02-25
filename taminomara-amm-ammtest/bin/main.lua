local test = require "ammtest/test"
local nick = require "ammcore/util/nick"

local parsed = nick.parse(computer.getInstance().nick)

local name
local tag = parsed:getOne("tag", tostring)
if tag then
    name = tag:match("^([^/]*)")
end

test.main(name)
