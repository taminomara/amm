local class        = require "ammcore.clas"
local array        = require "ammcore.fun._index"
local controlPanel = require "amm.lib.controlPanel"
local lc           = require "amm.ctl.lc"
local severity     = require "amm.lib.severity"
local controller   = require "amm.lib.controller"

-- Control panel for production lines.
local lcPanel      = {}

--- @enum lcPanel.Mode
lcPanel.Mode       = {
    NORMAL = 0,
    SEL_RECIPE = 1,
    SEL_RATE = 2,
}

--- Represents a control panel.
---
--- @class lcPanel.PanelState: ammcore.class.Base
local PanelState   = class.create("PanelState")

--- @param panel LargeControlPanel
--- @param manager lcPanel.LcPanel
--- @param errRep errorReporter.ErrorReporter
function PanelState:New(panel, manager, errRep)
    self = class.Base.New(self)

    --- @package
    --- @type LargeControlPanel
    self._panel = panel

    --- @package
    --- @type lcPanel.LcPanel
    self._manager = manager

    self.modules = self:checkModules(errRep)
    if not self.modules then
        return nil
    end
    self.modules.statusSignal:setColor(0, 0, 0, 0)
    self.modules.statusScreen.monospace = true
    self.modules.statusScreen.size = 18
    self.modules.modeScaleEncoder.min = -2
    self.modules.modeScaleEncoder.max = 4
    self.modules.modeScreen.monospace = true
    self.modules.modeScreen.size = 18

    --- @private
    --- @type lcPanel.Mode
    self._mode = lcPanel.Mode.NORMAL

    --- @private
    --- @type integer
    self._mfdScreen = 1

    --- @private
    --- @type fun(self: lcPanel.PanelState)[]
    self._mfdScreens = {}

    --- @package
    --- @type { name: string, hash: string }[]?
    self._recipes = {}

    --- @private
    --- @type integer
    self._recipeIndex = 1

    --- @private
    --- @type number
    self._targetPotential = 0

    --- @private
    --- @type integer
    self._rateTarget = 1

    self:setupEvents()

    return self
end

--- @param errRep errorReporter.ErrorReporter
function PanelState:checkModules(errRep)
    local panel = controlPanel.Panel:New(self._panel)

    local modules = {
        statusSignal = panel:getIndicator(1, 7),
        startButton = panel:getPushbutton(2, 7),
        stopButton = panel:getPushbutton(3, 7),
        statusScreen = panel:getTextDisplay(5, 7),
        buzzer = panel:getBuzzer(9, 8),
        muteButton = panel:getPushbutton(9, 7),
        modeSwitch = panel:getSwitch3Position(2, 6),
        mfdStateButton = panel:getPushbutton(5, 6),
        mfdIoButton = panel:getPushbutton(6, 6),
        mfdPrevButton = panel:getPushbutton(7, 6),
        mfdNextButton = panel:getPushbutton(8, 6),
        mfdScroll = panel:getEncoder(9, 6),

        modeRecipeButton = panel:getPushbutton(1, 4),
        modeRateButton = panel:getPushbutton(1, 3),
        modeScaleEncoder = panel:getPotentiometerWithDisplay(3, 4),
        modeSelectEncoder = panel:getEncoder(4, 4),
        modeZeroButton = panel:getPushbutton(3, 3),
        modeMaxButton = panel:getPushbutton(4, 3),
        modeScreen = panel:getTextDisplay(5, 3),
        modeAcceptButton = panel:getPushbutton(9, 4),
        modeResetButton = panel:getPushbutton(9, 3),

        pingsEnabled = panel:getSwitch2Position(3, 1),
        alarmEnabled = panel:getSwitch2Position(6, 1),
        pingButton = panel:getPushbutton(9, 1),
    }

    if not array.all(modules) then
        errRep:add("AMM_WRONG_PANEL_SETUP", nil, self._panel.location)
        for _, module in ipairs(self._panel:getModules()) do
            if module:isA(classes.IndicatorModule) then
                --- @cast module IndicatorModule
                severity.setObjectColor(module, severity.Severity.CRIT)
            end
        end
        return false
    end

    severity.alarm(modules.buzzer)

    return modules
end

function PanelState:setupEvents()
    self._manager:addListener(self.modules.startButton, { event = "trigger" }, function(_, _)
        self._manager._lineApi:start()
    end)

    self._manager:addListener(self.modules.stopButton, { event = "trigger" }, function(_, _)
        self._manager._lineApi:stop()
    end)

    self._manager:addListener(self.modules.muteButton, { event = "trigger" }, function(_, _)
        self._manager._managerApi:mute()
    end)

    self._manager:addListener(self.modules.mfdStateButton, { event = "trigger" }, function(_, _)
        self._mfdScreen = 1
        self:update()
    end)

    self._manager:addListener(self.modules.mfdIoButton, { event = "trigger" }, function(_, _)
        self._mfdScreen = 2
        if self._mfdScreen > #self._mfdScreens then
            self._mfdScreen = 1
        end
        self:update()
    end)

    self._manager:addListener(self.modules.mfdNextButton, { event = "trigger" }, function(_, _)
        self._mfdScreen = self._mfdScreen + 1
        if self._mfdScreen > #self._mfdScreens then
            self._mfdScreen = 1
        end
        self:update()
    end)

    self._manager:addListener(self.modules.mfdPrevButton, { event = "trigger" }, function(_, _)
        self._mfdScreen = self._mfdScreen - 1
        if self._mfdScreen < 1 then
            self._mfdScreen = #self._mfdScreens
        end
        self:update()
    end)

    self._manager:addListener(self.modules.modeRecipeButton, { event = "trigger" }, function(_, _)
        if self._manager._state.status ~= lc.Status.CRIT then
            self:stopEditing()
            self._mode = lcPanel.Mode.SEL_RECIPE
            self._recipes = nil
            self._recipeIndex = 1
            self._manager._lineApi:getRecipes()
            self:update()
        end
    end)

    self._manager:addListener(self.modules.modeRateButton, { event = "trigger" }, function(_, _)
        if self._manager._state.status ~= lc.Status.CRIT then
            if self._mode ~= lcPanel.Mode.SEL_RATE then
                self:stopEditing()
                self._mode = lcPanel.Mode.SEL_RATE
                self._targetPotential = self._manager._state.targetPotential
                self._rateTarget = 1
            elseif self._manager._state.recipe then
                local recipe = self._manager._state.recipe
                self._rateTarget = self._rateTarget + 1
                if self._rateTarget > #recipe.ingredients + #recipe.products then
                    self._rateTarget = 1
                end
            end
            self:update()
        end
    end)

    self._manager:addListener(self.modules.modeSelectEncoder, { event = "value" }, function(_, _, change)
        if self._mode == lcPanel.Mode.SEL_RECIPE then
            if self._recipes then
                self._recipeIndex = self._recipeIndex - change
                if self._recipeIndex > #self._recipes then self._recipeIndex = 1 end
                if self._recipeIndex < 1 then self._recipeIndex = #self._recipes end
                self:update()
            end
        elseif self._mode == lcPanel.Mode.SEL_RATE and self._manager._state.recipe then
            local recipe = self._manager._state.recipe
            local amount
            if self._rateTarget <= #recipe.ingredients then
                amount = recipe.ingredients[self._rateTarget]
            else
                amount = recipe.products[self._rateTarget - #recipe.ingredients]
            end
            if amount then
                local dP = recipe.duration / amount.amount / 60
                local mag = 10 ^ self.modules.modeScaleEncoder.value
                self._targetPotential = self._targetPotential + dP * change * mag
                if self._targetPotential < 1e-9 then
                    self._targetPotential = 0
                elseif self._targetPotential > self._manager._state.availablePotential then
                    self._targetPotential = self._manager._state.availablePotential
                end
                self:update()
            end
        end
    end)

    self._manager:addListener(self.modules.modeZeroButton, { event = "trigger" }, function(_, _)
        if self._mode == lcPanel.Mode.SEL_RECIPE then
            if self._recipes then
                self._recipeIndex = 1
                self:update()
            end
        elseif self._mode == lcPanel.Mode.SEL_RATE then
            if self._manager._state.recipe then
                self._targetPotential = 0
            end
            self:update()
        end
    end)

    self._manager:addListener(self.modules.modeMaxButton, { event = "trigger" }, function(_, _)
        if self._mode == lcPanel.Mode.SEL_RECIPE then
            if self._recipes then
                self._recipeIndex = #self._recipes
                self:update()
            end
        elseif self._mode == lcPanel.Mode.SEL_RATE then
            if self._manager._state.recipe then
                self._targetPotential = self._manager._state.availablePotential
            end
            self:update()
        end
    end)

    self._manager:addListener(self.modules.modeAcceptButton, { event = "trigger" }, function(_, _)
        if self._mode == lcPanel.Mode.SEL_RECIPE then
            if self._recipes then
                local recipe = self._recipes[self._recipeIndex]
                self._manager._lineApi:setRecipe(recipe.name, recipe.hash)
            end
            self:stopEditing()
            self:update()
        elseif self._mode == lcPanel.Mode.SEL_RATE then
            if self._manager._state.recipe then
                self._manager._lineApi:setPotential(self._targetPotential)
            end
            self:stopEditing()
            self:update()
        end
    end)

    self._manager:addListener(self.modules.modeResetButton, { event = "trigger" }, function(_, _)
        self:stopEditing()
        self:update()
    end)

    self._manager:addListener(self.modules.pingsEnabled, { event = "ChangeState" }, function(_, _, state)
        self._manager._managerApi:setPingsEnabled(state)
    end)

    self._manager:addListener(self.modules.alarmEnabled, { event = "ChangeState" }, function(_, _, state)
        self._manager._managerApi:setAlarmEnabled(state)
    end)
end

function PanelState:clearEvents()
    for _, module in pairs(self.modules) do
        if module then
            self._manager:clearListeners(module)
        end
    end
end

function PanelState:stopEditing()
    self._mode = lcPanel.Mode.NORMAL
    self._recipes = {}
    self._recipeIndex = 1
    self._targetPotential = 0
    self._rateTarget = 1
    self.modules.modeScaleEncoder.value = 0
end

function PanelState:update()
    severity.setObjectColor(self.modules.statusSignal, self._manager._color or self._manager._sv)

    local status = ({
        [lc.Status.CRIT] = "CRIT",
        [lc.Status.ERR] = "ERR",
        [lc.Status.STOP] = "STOP",
        [lc.Status.PRIME] = "PRIME",
        [lc.Status.OK] = "OK",
    })[self._manager._state.status]

    -- Sync the main panel part.
    if self._manager._state.status == lc.Status.CRIT then
        severity.turnOn(self.modules.startButton, { 1, 0, 0 })
        severity.turnOff(self.modules.modeRecipeButton)
        severity.turnOff(self.modules.modeRateButton)
        self:stopEditing()
    elseif self._manager._state.status == lc.Status.ERR then
        severity.turnOn(self.modules.startButton, { 1, 0, 0 })
        severity.turnOn(self.modules.modeRecipeButton)
        severity.turnOn(self.modules.modeRateButton)
    elseif self._manager._state.status == lc.Status.OK then
        severity.turnOff(self.modules.startButton)
        severity.turnOn(self.modules.modeRecipeButton)
        severity.turnOn(self.modules.modeRateButton)
    else
        severity.turnOn(self.modules.startButton)
        severity.turnOn(self.modules.modeRecipeButton)
        severity.turnOn(self.modules.modeRateButton)
    end
    self.modules.stopButton.enabled = true
    severity.turnOn(self.modules.mfdStateButton)
    severity.turnOn(self.modules.mfdIoButton)
    severity.turnOn(self.modules.mfdNextButton)
    severity.turnOn(self.modules.mfdPrevButton)

    if self._manager._alarmSounding then
        severity.turnOn(self.modules.muteButton)
        severity.alarm(self.modules.buzzer)
    else
        severity.turnOff(self.modules.muteButton)
        severity.stopAlarm(self.modules.buzzer)
    end

    self.modules.pingsEnabled.state = self._manager._pingsEnabled
    self.modules.alarmEnabled.state = self._manager._alarmEnabled
    severity.turnOn(self.modules.pingButton)

    -- Display system state.
    self.modules.statusScreen.text = status
    if #self._mfdScreens > 0 then self._mfdScreens[self._mfdScreen](self) end

    if self._mode == lcPanel.Mode.NORMAL then
        severity.turnOff(self.modules.modeScaleEncoder)
        severity.turnOff(self.modules.modeSelectEncoder)
        severity.turnOff(self.modules.modeZeroButton)
        severity.turnOff(self.modules.modeMaxButton)
        self.modules.modeScreen.text = ""
        severity.turnOff(self.modules.modeAcceptButton)
        severity.turnOff(self.modules.modeResetButton)
    elseif self._mode == lcPanel.Mode.SEL_RECIPE then
        severity.turnOn(self.modules.modeRecipeButton, { 0, 1, 0 })

        severity.turnOff(self.modules.modeScaleEncoder)
        severity.turnOn(self.modules.modeSelectEncoder)
        severity.turnOn(self.modules.modeZeroButton)
        severity.turnOn(self.modules.modeMaxButton)
        self.modules.modeScreen.text = self:generateSelectRecipeScreen()
        severity.turnOn(self.modules.modeAcceptButton, { 0, 1, 0 })
        severity.turnOn(self.modules.modeResetButton, { 1, 0, 0 })
    elseif self._mode == lcPanel.Mode.SEL_RATE then
        severity.turnOn(self.modules.modeRateButton, { 0, 1, 0 })

        severity.turnOn(self.modules.modeScaleEncoder)
        severity.turnOn(self.modules.modeSelectEncoder)
        severity.turnOn(self.modules.modeZeroButton)
        severity.turnOn(self.modules.modeMaxButton)
        self.modules.modeScreen.text = self:generateSelectRateScreen()
        severity.turnOn(self.modules.modeAcceptButton, { 0, 1, 0 })
        severity.turnOn(self.modules.modeResetButton, { 1, 0, 0 })
    end
end

function PanelState:generateSelectRecipeScreen()
    if not self._recipes then
        return "Loading recipes..."
    elseif #self._recipes == 0 then
        return "No recipes found"
    end

    local pageSize = 5
    local pages = math.ceil(#self._recipes / pageSize)
    local page = math.floor((self._recipeIndex - 1) / pageSize)

    local text = string.format("Recipe (page %s/%s)\n", page + 1, pages)

    for i = page * pageSize + 1, math.min((page + 1) * pageSize, #self._recipes) do
        text = text .. (i == self._recipeIndex and " > " or "   ")
        text = text .. self._recipes[i].name .. "\n"
    end

    return text
end

function PanelState:generateSelectRateScreen()
    local recipe = self._manager._state.recipe
    if not recipe then
        return "No recipe loaded"
    elseif self._manager._state.numMachines == 0 then
        return "No machines found"
    end

    local pageSize = 4
    local pages = math.ceil((#recipe.ingredients + #recipe.products) / pageSize)
    local page = math.floor((self._rateTarget - 1) / pageSize)

    local targetRate = 100 * self._targetPotential / self._manager._state.numMachines
    local maxRate = 100 * self._manager._state.availablePotential / self._manager._state.numMachines
    local text = string.format("Rate per minute (page %s/%s)\nTarget rate: %.2f%% / %.2f%%\n", page + 1, pages,
        targetRate, maxRate)

    for i = page * pageSize + 1, math.min((page + 1) * pageSize, #recipe.ingredients + #recipe.products) do
        text = text .. (i == self._rateTarget and " > " or "   ")

        local amount
        if i <= #recipe.ingredients then
            text = text .. " In: "
            amount = recipe.ingredients[i]
        else
            text = text .. "Out: "
            amount = recipe.products[i - #recipe.ingredients]
        end

        local rate = 60 * self._targetPotential * amount.amount / recipe.duration
        text = text .. string.format("%.2f %s", rate, amount.type.name) .. "\n"
    end

    return text
end

--- A manager that handles all control panels in the network.
---
--- @class lcPanel.LcPanel: controller.MonitoringController
lcPanel.LcPanel = class.create("LcPanel", controller.MonitoringController)

lcPanel.LcPanel.CODE = "Amm.LcPanel"

--- @generic T: lcPanel.LcPanel
--- @param self T
--- @param addr string?
--- @return T
function lcPanel.LcPanel:New(addr)
    self = controller.MonitoringController.New(self)

    --- @private
    --- @type string
    self._addr = addr or AMM_LOOPBACK
    --- @package
    --- @type severity.Severity
    self._sv = severity.Severity.ERR
    --- @package
    --- @type severity.Color?
    self._color = nil
    --- @package
    --- @type string
    self._facyoryName = "Unknown factory"
    --- @package
    --- @type boolean
    self._pingsEnabled = false
    --- @package
    --- @type boolean
    self._alarmEnabled = false
    --- @package
    --- @type boolean
    self._alarmSounding = false
    --- @package
    --- @type lc.LineState
    self._state = lc.LineState:New()
    --- @package
    --- @type { code: string, msg: string, sv: severity.Severity }[]
    self._messages = {}
    --- @package
    --- @type controller.ManagerApiHandle
    self._managerApi = self:apiForManager(self._addr)
    --- @package
    --- @type controller.ApiHandle
    self._lineApi = self:apiFor(lc.LineCtl, self._addr)
    --- @private
    --- @type table<integer, lcPanel.PanelState>
    self._panelStates = {}

    return self
end

function lcPanel.LcPanel:_start()
    self:check()
    self:_update()
end

function lcPanel.LcPanel:_check()
    self:requestState(self._addr, true)
    self:_discover()
end

function lcPanel.LcPanel:onStateReceived(from, state)
    if from ~= self._addr or not state.controllers[lc.LineCtl.CODE] then
        return
    end

    self._sv = state.sv
    self._color = state.color
    self._facyoryName = state.factoryName
    self._pingsEnabled = state.pingsEnabled
    self._alarmEnabled = state.alarmEnabled
    self._alarmSounding = state.alarmSounding
    self._state = lc.LineState:FromData(state.controllers[lc.LineCtl.CODE].state)
    self._messages = state.controllers[lc.LineCtl.CODE].messages

    self:_discover()
    self:_update()
end

function lcPanel.LcPanel:_discover()
    local panelStates = {}

    --- Find new panels, bind events.
    for _, panel in ipairs(component.proxy(component.findComponent(classes.LargeControlPanel)) --[[ @as LargeControlPanel[] ]]) do
        if self._panelStates[panel.hash] then
            if self._panelStates[panel.hash]:checkModules(self.errRep) then
                panelStates[panel.hash] = self._panelStates[panel.hash]
            end
        else
            panelStates[panel.hash] = PanelState:New(panel, self, self.errRep)
        end
    end

    --- Unbind events from deleted panels.
    for hash, panelState in pairs(self._panelStates) do
        if not panelStates[hash] then
            panelState:clearEvents()
        end
    end

    self._panelStates = panelStates
end

function lcPanel.LcPanel:_update()
    for _, panelState in pairs(self._panelStates) do
        panelState:update()
    end
end

--- @private
function lcPanel.LcPanel:_rcvRecipesHandler(msg, recipes)
    self:_discover()
    for _, panelState in pairs(self._panelStates) do
        if not panelState._recipes then
            panelState._recipes = recipes
            panelState:update()
        end
    end
end

lcPanel.LcPanel:MessageHandler("rcvRecipes", lcPanel.LcPanel._rcvRecipesHandler)

return lcPanel
