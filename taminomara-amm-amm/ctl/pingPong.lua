local class = require "ammcore.clas"
local controller = require "amm.lib.controller"

--- Inter-controller messaging example.
local pingPong = {}

--- Ping: sends a ping.
---
--- @class pingPong.Ping: controller.Controller
pingPong.Ping = class.create("Ping", controller.Controller)

pingPong.Ping.CODE = "Amm.Ping"

--- @param addr string?
--- @param cookie string?
function pingPong.Ping:New(addr, cookie)
    self = controller.Controller.New(self)
    self.addr = addr or AMM_BROADCAST
    self.cookie = cookie or "1"
    return self
end

function pingPong.Ping:_start()
    print(self.cookie, "Broadcasting ping")
    self:apiFor(pingPong.Pong, self.addr):ping(self.cookie)
    print(self.cookie, "Done broadcasting ping")
end

pingPong.Ping:MessageHandler("pong", function(self, msg, cookie)
    print(self.cookie, "Got pong from " .. msg.addr .. "@" .. msg.code, cookie)
end)

--- Pong: responds to pings.
---
--- @class pingPong.Pong: controller.Controller
pingPong.Pong = class.create("Pong", controller.Controller)

pingPong.Pong.CODE = "Amm.Pong"

--- @param cookie string?
function pingPong.Pong:New(cookie)
    self = controller.Controller.New(self)
    self.cookie = cookie or "2"
    return self
end

pingPong.Pong:MessageHandler("ping", function(self, msg, cookie)
    print(self.cookie, "Got ping from " .. msg.addr .. "@" .. msg.code, cookie)
    print(self.cookie, "Sending pong")
    self:sendMessage(msg.addr, msg.code, "pong", cookie)
    print(self.cookie, "Done sending pong")
end)

return pingPong
