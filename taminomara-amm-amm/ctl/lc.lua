local array = require "ammcore.util.array"
local class = require "ammcore.util.class"
local severity = require "amm.lib.severity"
local log = require "ammcore.util.log"
local errorReporter = require "amm.lib.errorReporter"
local controller = require "amm.lib.controller"
local recipeHelpers = require "amm.lib.recipeHelpers"

-- Production line controller.
local lc = {}

--- Status of a production line.
---
--- @enum lc.State
lc.Status = {
    --- Critical error, production stopped.
    CRIT = 0,
    --- Error, production stopped.
    ERR = 1,
    --- Production paused by the pioneer.
    STOP = 2,
    --- Waiting for the system to prime.
    PRIME = 3,
    --- Production running.
    OK = 4,
}

--- State of a production line.
---
--- @class lc.LineState: class.Base
lc.LineState = class.create("LineState")

--- @generic T: lc.LineState
--- @param self T
--- @param status lc.State?
--- @param numMachines integer?
--- @return T
function lc.LineState:New(status, numMachines)
    self = class.Base.New(self)

    --- Overall state of the production line.
    ---
    --- @type lc.State
    self.status = status or lc.Status.STOP

    --- Number of machines in the network.
    ---
    --- @type integer
    self.numMachines = numMachines or 0

    --- Current production recipe.
    ---
    --- @type recipeHelpers.Recipe
    self.recipe = nil

    --- Current combined potential of all machines.
    ---
    --- @type number
    self.potential = 0

    --- Target combined potential of all machines.
    ---
    --- @type number
    self.targetPotential = 0

    --- Total combined potential of all machines, depending on power shards.
    ---
    --- @type number
    self.availablePotential = 0

    --- Total productivity of all machines.
    ---
    --- @type number
    self.productivity = 0

    --- True if the system's input resource capacity isn't at 100%.
    ---
    --- @type boolean
    self.requiresPriming = false

    --- Number of machines with at least one resource below 20%.
    ---
    --- @type integer
    self.lowResourceMachines = 0

    --- Total amount of input resources stored in machines.
    ---
    --- @type table<string, integer>
    self.inputStackSize = {}

    --- Total amount of input resources stored in machines.
    ---
    --- @type table<string, integer>
    self.outputStackSize = {}

    return self
end

function lc.LineState:FromData(data)
    self = self:New()

    for k, v in pairs(data) do
        self[k] = v
    end

    return self
end

--- Production line controller.
---
--- @class lc.LineCtl: controller.Controller
lc.LineCtl = class.create("LineCtl", controller.Controller)

lc.LineCtl.CODE = "Amm.Lc"

function lc.LineCtl:New()
    self = controller.Controller.New(self)

    --- State of the line.
    --- @private
    --- @type lc.LineState
    self._state = lc.LineState:New()

    --- Production machines that are connected to the network.
    --- @private
    --- @type Manufacturer[]
    self._machines = {}

    --- Production machine statuses.
    --- @private
    --- @type table<string, boolean>
    self._machineIsWorking = {}

    --- The main power switch that controls the production.
    --- @private
    --- @type CircuitSwitch | nil
    self._powerSwitch = nil

    return self
end

function lc.LineCtl:getState()
    return self._state
end

function lc.LineCtl:getSeverity()
    if self:_getStatus() == lc.Status.CRIT then
        return severity.Severity.CRIT
    elseif self:_getStatus() == lc.Status.ERR then
        return severity.Severity.ERR
    elseif self:_getStatus() == lc.Status.STOP then
        return severity.Severity.INFO, { 1, 0, 0 }
    elseif self:_getStatus() == lc.Status.PRIME then
        return severity.Severity.INFO
    else
        return self.errRep:getSeverity()
    end
end

function lc.LineCtl:getFactoryName()
    return self._state.recipe and string.format("%s factory", self._state.recipe.name)
end

function lc.LineCtl:_start()
    -- Recover system state.
    self._state = lc.LineState:New(self:loadState() --[[ @as integer? ]])
    if self._state.status == lc.Status.CRIT then
        self._state.status = lc.Status.ERR
    end

    -- Discover power switch.
    self._powerSwitch = self:_discoverPowerSwitch()
    if not self._powerSwitch then
        self.errRep:raise("AMM_NO_POWER_SWITCH")
        self:_setStatus(lc.Status.CRIT)
        return
    end

    -- Discover machines.
    self._machines = self:_discoverMachines()
    self._machineIsWorking = {}
    self._state.numMachines = #self._machines
    if #self._machines == 0 then
        self.errRep:raise("AMM_NO_MACHINES")
        self:_setStatus(lc.Status.CRIT)
        return
    end

    -- Turn all machines off to make sure we get event updates from all of them.
    local _ = self._powerSwitch:setIsSwitchOn(false)

    -- Bind events.
    self:_bindPowerSwitch()
    self:_bindMachines()

    -- Run basic checks.
    self:check()
    if self:_getStatus() == lc.Status.CRIT then return end

    -- Make sure the switch state is in sync after we've disabled it.
    self:_syncPowerSwitch()
end

function lc.LineCtl:_check()
    if self:_getStatus() == lc.Status.CRIT then return end

    self:_resetState()

    -- Check that the list of machines has not changed.
    local updatedPowerSwitch = self:_discoverPowerSwitch()
    local updatedMachines = self:_discoverMachines()
    if
        updatedPowerSwitch ~= self._powerSwitch
        or not array.eq(updatedMachines, self._machines)
    then
        -- A set of machines connected to the factory has changed.
        -- We'll need to restart the computer to re-index all of them.
        self.errRep:raise("AMM_MACHINES_CHANGED")
        self:_setStatus(lc.Status.CRIT)
        return
    end

    local circuit = self._powerSwitch:getPowerConnectors()[1]:getCircuit()
    local machineType = self._machines[1]:getType()

    self._state.recipe = recipeHelpers.Recipe:New(self._machines[1]:getRecipe())

    local missingResources = {}

    for _, machine in ipairs(self._machines) do
        if machine:getType() ~= machineType then
            self.errRep:raise("AMM_INCONSISTENT_MACHINES", nil, machine.location)
            self:_resetState()
            self:_setStatus(lc.Status.CRIT)
            return
        end
        if machine:getPowerConnectors()[1].connections == 0 then
            self.errRep:raise("AMM_NO_CONNECTED_POWER", nil, machine.location)
            self:_resetState()
            self:_setStatus(lc.Status.CRIT)
            return
        end
        if circuit and machine:getPowerConnectors()[1]:getCircuit() ~= circuit then
            self.errRep:raise("AMM_WRONG_GRID", nil, machine.location)
            self:_resetState()
            self:_setStatus(lc.Status.CRIT)
            return
        end
        if self._state.recipe and machine:getRecipe().hash ~= self._state.recipe.hash then
            self.errRep:add("AMM_INCONSISTENT_RECIPES", nil, machine.location)
            self:_resetState()
            self:_setStatus(lc.Status.ERR)
            return
        end

        if machine.standby then
            self.errRep:add("AMM_STANDBY_MACHINES", nil, machine.location)
        end

        if self._powerSwitch.isSwitchOn and not machine:getPowerConnectors()[1]:getPower().hasPower then
            self.errRep:add("AMM_OFFLINE_MACHINES", nil, machine.location)
        end

        if not machine.standby and self._machineIsWorking[machine.hash] then
            self._state.potential = self._state.potential + machine.potential
        end
        self._state.targetPotential = self._state.targetPotential + machine.potential
        self._state.availablePotential = self._state.availablePotential + machine.maxPotential
        self._state.productivity = self._state.productivity + machine.productivity

        if self._state.recipe then
            local notEnoughResources = false
            local inv = machine:getInputInv()
            local stacks = {}
            for i = 1, inv.size do
                local stack = inv:getStack(i - 1)
                if stack and stack.item.type then
                    stacks[stack.item.type.hash] = stack
                end
            end
            for _, product in ipairs(self._state.recipe.ingredients) do
                local item = product.type
                local stack = stacks[item.hash]
                if stack then
                    self._state.inputStackSize[item.hash] = (self._state.inputStackSize[item.hash] or 0) + stack.count
                end
                if not stack or stack.count < 0.3 * item.max then
                    missingResources[item.hash] = true
                    notEnoughResources = true
                    self._state.requiresPriming = true
                elseif stack.count < item.max then
                    self._state.requiresPriming = true
                end
            end
            if notEnoughResources then
                self.errRep:add("AMM_NOT_ENOUGH_RESOURCES", nil, machine.location)
                self._state.lowResourceMachines = self._state.lowResourceMachines + 1
            end
        end
    end

    if not self._state.recipe then
        self.errRep:add("AMM_NO_RECIPE")
        self:_resetState()
        self:_setStatus(lc.Status.ERR)
        return
    end

    if self._state.lowResourceMachines > 0 then
        if self._state.recipe then
            local text = "Low resources"
            local sep = ": "
            for _, product in ipairs(self._state.recipe.ingredients) do
                if missingResources[product.type.hash] then
                    text = text .. sep .. product.type.name
                    sep = ", "
                end
            end
            self.errRep:add("AMM_NOT_ENOUGH_RESOURCES", text)
        end
    end

    -- If we're here, there are no errors in the system.
    if self:_getStatus() == lc.Status.ERR then
        self:_setStatus(lc.Status.STOP)
    elseif self:_getStatus() == lc.Status.PRIME and not self._state.requiresPriming then
        self:_setStatus(lc.Status.OK)
    elseif self:_getStatus() == lc.Status.OK and self._state.lowResourceMachines >= 0.5 * self._state.numMachines then
        self:_setStatus(lc.Status.PRIME)
    end
end

--- Change current operation state and sync state of the power switch.
---
--- @private
--- @param newState lc.State
function lc.LineCtl:_setStatus(newState)
    if self._state.status ~= newState then
        self:notifySubscribers()
        self:saveState(newState)
    end

    self._state.status = newState

    self:_syncPowerSwitch()
end

--- Get current system state.
---
--- @private
--- @return lc.State
function lc.LineCtl:_getStatus()
    return self._state.status
end

--- Reset all state fields except `status` and `numMachines`.
---
--- @private
function lc.LineCtl:_resetState()
    self._state = lc.LineState:New(self._state.status, self._state.numMachines)
end

--- Make sure power switch state is synced with then current system state.
---
--- @private
function lc.LineCtl:_syncPowerSwitch()
    if self._powerSwitch then
        local _ = self._powerSwitch:setIsSwitchOn(self:_getStatus() == lc.Status.OK)
    end
end

--- Find all machines in the network.
--- Makes sure that the order of machines is well-defined.
---
--- @private
--- @return Manufacturer[]
function lc.LineCtl:_discoverMachines()
    local machines = component.proxy(component.findComponent(classes.Manufacturer))
    return machines --[[ @as Manufacturer[] ]]
end

--- Find the controlling power switch.
---
--- @private
--- @return CircuitSwitch | nil
function lc.LineCtl:_discoverPowerSwitch()
    local id = component.findComponent("AMM_PowerCtl")[1]
    if not id then return nil end
    local obj = component.proxy(id) --[[ @as Object ]]
    if not obj or not obj:isA(classes.CircuitSwitch) then return nil end
    return obj --[[ @as CircuitSwitch ]]
end

--- @private
function lc.LineCtl:_bindPowerSwitch()
    self:addListener(
        self._powerSwitch,
        { name = "ProductionChanged" },
        function()
            if self:_getStatus() == lc.Status.CRIT or self:_getStatus() == lc.Status.ERR then
                if self._powerSwitch.isSwitchOn then
                    local _ = self._powerSwitch:setIsSwitchOn(false)
                end
            else
                if self._powerSwitch.isSwitchOn and self:_getStatus() ~= lc.Status.OK then
                    self:_setStatus(lc.Status.OK)
                    self:scheduleCheck()
                elseif not self._powerSwitch.isSwitchOn and self:_getStatus() == lc.Status.OK then
                    self:_setStatus(lc.Status.STOP)
                    self:scheduleCheck()
                end
            end
        end
    )
end

--- @private
function lc.LineCtl:_bindMachines()
    self:addListener(
        { name = "ProductionChanged" },
        self._machines,
        function(e, s, ch)
            self._machineIsWorking[s.hash] = (ch == 1)
            self:scheduleCheck()
        end
    )
end

--- @private
function lc.LineCtl:_startHandler(_)
    if self:_getStatus() == lc.Status.STOP then
        self:_setStatus(self._state.requiresPriming and lc.Status.PRIME or lc.Status.OK)
    elseif self:_getStatus() == lc.Status.PRIME then
        self:_setStatus(lc.Status.OK)
    elseif self:_getStatus() == lc.Status.CRIT or self:_getStatus() == lc.Status.ERR then
        computer.reset()
    end
end

lc.LineCtl:MessageHandler("start", lc.LineCtl._startHandler)

--- @private
function lc.LineCtl:_stopHandler(_)
    if self:_getStatus() == lc.Status.PRIME or self:_getStatus() == lc.Status.OK then
        self:_setStatus(lc.Status.STOP)
    end
end

lc.LineCtl:MessageHandler("stop", lc.LineCtl._stopHandler)

--- @private
function lc.LineCtl:_setRecipeHandler(_, recipeName, recipeHash)
    self:check() -- refresh list of machines and the state
    if self._state == lc.Status.CRIT then return end

    for _, recipe in ipairs(self._machines[1]:getRecipes()) do
        if recipe.hash == recipeHash then
            for _, machine in ipairs(self._machines) do
                local _ = machine:setRecipe(recipe)
            end

            self:check()
            self:notifySubscribers()

            return
        end
    end

    computer.log(2, string.format("Unknown recipe %s (hash=%s)", recipeName, recipeHash))
end

lc.LineCtl:MessageHandler("setRecipe", lc.LineCtl._setRecipeHandler)

--- @private
function lc.LineCtl:_getRecipesHandler(msg)
    self:check() -- refresh list of machines and the state
    if self._state == lc.Status.CRIT then return end

    local recipes = {}
    for _, recipe in ipairs(self._machines[1]:getRecipes()) do
        table.insert(recipes, { hash = recipe.hash, name = recipe.name })
    end

    self:sendMessage(msg.addr, msg.code, "rcvRecipes", recipes)
end

lc.LineCtl:MessageHandler("getRecipes", lc.LineCtl._getRecipesHandler)

--- @private
function lc.LineCtl:_setPotentialHandler(_, potential)
    self:check() -- refresh list of machines and the state
    if self._state == lc.Status.CRIT then return end

    if potential > self._state.availablePotential then
        computer.log(2, string.format(
            "Not enough power shards to set the factory potential to %.2f%%: max potential is %.2f%%",
            potential * 100, self._state.availablePotential * 100
        ))
        potential = self._state.availablePotential
    end

    local machines = array.insertMany({}, self._machines)
    table.sort(machines, function(a, b) return a.maxPotential < b.maxPotential end)

    for i, machine in ipairs(machines) do
        local machinesLeftToSet = #machines - i + 1
        local potentialPerMachine = math.max(
            machine.minPotential,
            math.min(machine.maxPotential, potential / machinesLeftToSet)
        )
        local _ = machine:setPotential(potentialPerMachine)
        potential = math.max(0, potential - potentialPerMachine)
    end

    self:check()
    self:notifySubscribers()
end

lc.LineCtl:MessageHandler("setPotential", lc.LineCtl._setPotentialHandler)

-- Messages

log.addErrorCode(
    "AMM_NO_POWER_SWITCH",
    "Couldn't locate the main power switch",
    severity.Severity.CRIT
)
log.addErrorCode(
    "AMM_MACHINES_CHANGED",
    "Set of production machines changed, restart required",
    severity.Severity.CRIT
)
log.addErrorCode(
    "AMM_NO_MACHINES",
    "No production machines found",
    severity.Severity.CRIT
)
log.addErrorCode(
    "AMM_INCONSISTENT_MACHINES",
    "Inconsistent type of oroduction machines",
    severity.Severity.CRIT
)
log.addErrorCode(
    "AMM_NO_CONNECTED_POWER",
    "Some machines are not connected to power",
    severity.Severity.CRIT
)
log.addErrorCode(
    "AMM_WRONG_GRID",
    "Some machines are connected to the wrong grid",
    severity.Severity.CRIT
)

log.addErrorCode(
    "AMM_INCONSISTENT_RECIPES",
    "Inconsistent recipes",
    severity.Severity.ERR
)
log.addErrorCode(
    "AMM_NO_RECIPE",
    "No recipe loaded",
    severity.Severity.ERR
)

log.addErrorCode(
    "AMM_STANDBY_MACHINES",
    "Some machines are on standby",
    severity.Severity.WARN
)
log.addErrorCode(
    "AMM_OFFLINE_MACHINES",
    "No power",
    severity.Severity.WARN
)
log.addErrorCode(
    "AMM_NOT_ENOUGH_RESOURCES",
    "Low resources",
    severity.Severity.WARN
)
log.addErrorCode(
    "AMM_WRONG_PANEL_SETUP",
    "Control panel missing necessary modules",
    severity.Severity.WARN
)

log.addErrorCode(
    "AMM_PRIMING_REQUIRED",
    "Priming required",
    severity.Severity.INFO
)

return lc
