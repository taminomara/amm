local class = require "ammcore.clas"
local controller = require "amm.lib.controller"

--- Demo for stateful controllers and state observers.
local statusDemo = {}

--- Maintains an internal state counting button presses.
---
--- @class statusDemo.Controller: controller.Controller
statusDemo.Controller = class.create("Controller", controller.Controller)

statusDemo.Controller.CODE = "Amm.StatusController"

function statusDemo.Controller:_start()
    self.state = self:loadState() or 0

    local panelId = component.findComponent(classes.LargeControlPanel)[1]
    assert(panelId, "Couldn't find a control panel")

    local panel = component.proxy(panelId) --[[ @as LargeControlPanel ]]
    assert(panel, "Couldn't find a control panel")

    self.button = panel:getModule(0, 0)
    assert(self.button, "Button should be present at (0, 0)")

    event.listen(self.button)
    self:addListener(self.button, { name = "Trigger" }, function()
        self.state = self.state + 1
        self:saveState(self.state)
        self:notifySubscribers()
    end)
end

function statusDemo.Controller:getState()
    return self.state
end

--- Monitors controller's state.
---
--- @class statusDemo.Monitor: controller.MonitoringController
statusDemo.Monitor = class.create("Monitor", controller.MonitoringController)

statusDemo.Monitor.CODE = "Amm.StatusMonitor"

--- @param addr string?
function statusDemo.Monitor:New(addr)
    self = controller.Controller.New(self)
    self.addr = addr or AMM_LOOPBACK
    return self
end

function statusDemo.Monitor:_start()
    local panelId = component.findComponent(classes.LargeControlPanel)[1]
    assert(panelId, "Couldn't find a control panel")

    local panel = component.proxy(panelId) --[[ @as LargeControlPanel ]]
    assert(panel, "Couldn't find a control panel")

    self.secreen = panel:getModule(1, 0) --[[ @as LargeMicroDisplayModule ]]
    assert(self.secreen, "Large micro display should be present at (1, 0)")
    assert(self.secreen:isA(classes.LargeMicroDisplayModule))

    -- Request state and subscribe.
    self:requestState(self.addr, true)
end

function statusDemo.Monitor:_check()
    -- Refresh state and re-subscribe.
    self:requestState(self.addr, true)
end

function statusDemo.Monitor:onStateReceived(from, state)
    self.secreen:setText(tostring(
        (state.controllers[statusDemo.Controller.CODE] or {}).state
    )):await()
end

return statusDemo
