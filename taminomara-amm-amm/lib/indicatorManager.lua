local class = require "ammcore.util.class"
local severity = require "amm.lib.severity"
local nick = require "ammcore.util.nick"
local machineWatcher = require "amm.lib.machineWatcher"

--- Facilities for managing status indicator poles.
local indicatorManager = {}

--- Manager for status indicator poles.
---
--- @class indicatorManager.IndicatorManager: machineWatcher.MachineWatcher
indicatorManager.IndicatorManager = class.create("IndicatorManager", machineWatcher.MachineWatcher)

function indicatorManager.IndicatorManager:New()
    self = machineWatcher.MachineWatcher.New(self, "AMM_Indicator")

    --- @private
    --- @type { indicator: ModularPoleModule_Indicator | IndicatorPole, idx: integer, sv: severity.Severity?, color: severity.Color? }[]
    self._localIndicators = {}
    --- @private
    --- @type (ModularPoleModule_Indicator | IndicatorPole)[]
    self._globalIndicators = {}

    return self
end

function indicatorManager.IndicatorManager:discover()
    self._localIndicators = {}
    self._globalIndicators = {}

    machineWatcher.MachineWatcher.discover(self)
end

function indicatorManager.IndicatorManager:_added(machine)
    self:_updated(machine)
end

function indicatorManager.IndicatorManager:_updated(machine)
    if machine:isA(classes.ModularIndicatorPole) then
        --- @cast machine ModularIndicatorPole

        local vars = nick.parse(machine.nick)

        local idx = vars:getOne("idx", math.tointeger) or 0
        local localPositions = vars:getAll("local", math.tointeger)
        local globalPositions = vars:getAll("local", math.tointeger)

        if #localPositions == 0 and #globalPositions == 0 then
            local i = 0
            while true do
                local module = machine:getModule(i)
                if not module then
                    break
                end
                if module:isA(classes.ModularPoleModule_Indicator) then
                    if #globalPositions == 0 then
                        globalPositions = { i }
                    else
                        localPositions = globalPositions
                        globalPositions = { i }
                        break
                    end
                end
                i = i + 1
            end
        end

        for _, localPos in ipairs(localPositions) do
            local localIndicator = machine:getModule(localPos)
            if localIndicator and localIndicator:isA(classes.ModularPoleModule_Indicator) then
                table.insert(self._localIndicators, { localIndicator, idx = idx, sv = nil, color = nil })
            end
        end
        for _, globalPos in ipairs(globalPositions) do
            local globalIndicator = machine:getModule(globalPos)
            if globalIndicator and globalIndicator:isA(classes.ModularPoleModule_Indicator) then
                table.insert(self._globalIndicators, globalIndicator)
            end
        end
    elseif machine:isA(classes.IndicatorPole) then
        --- @case indicator IndicatorPole
        table.insert(self._globalIndicators, machine)
    end
end

--- Turn off all global indicators.
function indicatorManager.IndicatorManager:globalOff()
    for _, indicator in ipairs(self._globalIndicators) do
        severity.setDisabledObjectColor(indicator, { 0, 0, 0 })
    end
end

--- Turn on all global indicators and set them to the given severity/color.
---
--- @param sv severity.Severity | severity.Color
function indicatorManager.IndicatorManager:globalOn(sv)
    for _, indicator in ipairs(self._globalIndicators) do
        severity.setObjectColor(indicator, sv)
    end
end

--- Turn off all local indicators.
function indicatorManager.IndicatorManager:localOff()
    for _, indicator in ipairs(self._localIndicators) do
        severity.setDisabledObjectColor(indicator[1], { 0, 0, 0 })
        indicator.sv = nil
    end
end

--- Set severity and color of a local indicator closest to the given location.
--
--- Only indicators within `maxDistanceCm` from the location will be considered.
---
--- @param location Vector
--- @param sv severity.Severity
--- @param color severity.Color?
--- @param maxDistanceCm integer?
function indicatorManager.IndicatorManager:setLocalColor(location, sv, color, maxDistanceCm)
    maxDistanceCm = maxDistanceCm or 2000

    local candidates = {}

    for _, indicator in ipairs(self._localIndicators) do
        local direction = location - indicator[1].location
        local distance = direction.x ^ 2 + direction.y ^ 2 + direction.z ^ 2
        if distance < maxDistanceCm ^ 2 then
            local candidate = candidates[indicator.idx] or {}
            if not candidate.distance or candidate.distance > distance then
                candidate.indicator = indicator
                candidate.distance = distance
            end
            candidates[indicator.idx] = candidate
        end
    end

    for _, candidate in pairs(candidates) do
        if
            not candidate.indicator.sv
            or sv > candidate.indicator.sv
            or sv == candidate.indicator and not candidate.indicator.color
        then
            candidate.indicator.sv = sv
            candidate.indicator.color = color
        end
    end
end

--- Apply colors to all local indicators.
function indicatorManager.IndicatorManager:applyLocalColors()
    for _, indicator in ipairs(self._localIndicators) do
        if indicator.color or indicator.sv then
            severity.setObjectColor(indicator[1], indicator.color or indicator.sv or { 1, 1, 1 })
        else
            severity.setDisabledObjectColor(indicator[1], { 0, 0, 0 })
        end
    end
end

return indicatorManager
