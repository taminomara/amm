local class = require "ammcore.clas"

--- Utilities for working with control panel modules.
local controlPanel = {}

--- A unified interface for working with control panels.
---
--- @class controlPanel.Panel: ammcore.class.Base
controlPanel.Panel = class.create("Panel")

--- @param panel LargeControlPanel | ModulePanel
--- @param index integer?
function controlPanel.Panel:New(panel, index)
    self = class.Base.New(self)

    --- @private
    --- @type LargeControlPanel | LargeVerticalControlPanel | ModulePanel
    self._panel = panel
    --- @private
    --- @type any
    self._index = index

    return self
end

--- @param panel LargeControlPanel | ModulePanel
function controlPanel.Panel:FromPanel(panel)
    return self:New(panel)
end

--- @param panel LargeVerticalControlPanel
--- @param index integer?
function controlPanel.Panel:FromVerticalPanel(panel, index)
    return self:New(panel --[[ @as any ]], index)
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return FINModuleScreen | false
function controlPanel.Panel:getScreen(x, y)
    return self:_get(classes.FINModuleScreen, x, y) --[[ @as FINModuleScreen | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return PushbuttonModule | false
function controlPanel.Panel:getPushbutton(x, y)
    return self:_get(classes.PushbuttonModule, x, y) --[[ @as PushbuttonModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return MushroomPushbuttonModule | false
function controlPanel.Panel:getMushroomPushbutton(x, y)
    return self:_get(classes.MushroomPushbuttonModule, x, y) --[[ @as MushroomPushbuttonModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return MushroomPushbuttonModuleBig | false
function controlPanel.Panel:getMushroomPushbuttonBig(x, y)
    return self:_get(classes.MushroomPushbuttonModuleBig, x, y) --[[ @as MushroomPushbuttonModuleBig | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return ModuleSwitch | false
function controlPanel.Panel:getSwitch(x, y)
    return self:_get(classes.ModuleSwitch, x, y) --[[ @as ModuleSwitch | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return SwitchModule2Position | false
function controlPanel.Panel:getSwitch2Position(x, y)
    return self:_get(classes.SwitchModule2Position, x, y) --[[ @as SwitchModule2Position | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return SwitchModule3Position | false
function controlPanel.Panel:getSwitch3Position(x, y)
    return self:_get(classes.SwitchModule3Position, x, y) --[[ @as SwitchModule3Position | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return PotentiometerModule | false
function controlPanel.Panel:getPotentiometer(x, y)
    return self:_get(classes.PotentiometerModule, x, y) --[[ @as PotentiometerModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return PotWDisplayModule | false
function controlPanel.Panel:getPotentiometerWithDisplay(x, y)
    return self:_get(classes.PotWDisplayModule, x, y) --[[ @as PotWDisplayModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return EncoderModule | false
function controlPanel.Panel:getEncoder(x, y)
    return self:_get(classes.EncoderModule, x, y) --[[ @as EncoderModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return ModulePotentiometer | false
function controlPanel.Panel:getModulePotentiometer(x, y)
    return self:_get(classes.ModulePotentiometer, x, y) --[[ @as ModulePotentiometer | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return MicroDisplayModule | false
function controlPanel.Panel:getMicroDisplay(x, y)
    return self:_get(classes.MicroDisplayModule, x, y) --[[ @as MicroDisplayModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return SquareMicroDisplayModule | false
function controlPanel.Panel:getSquareMicroDisplay(x, y)
    return self:_get(classes.SquareMicroDisplayModule, x, y) --[[ @as SquareMicroDisplayModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return LargeMicroDisplayModule | false
function controlPanel.Panel:getLargeMicroDisplay(x, y)
    return self:_get(classes.LargeMicroDisplayModule, x, y) --[[ @as LargeMicroDisplayModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return ModuleTextDisplay | false
function controlPanel.Panel:getTextDisplay(x, y)
    return self:_get(classes.ModuleTextDisplay, x, y) --[[ @as ModuleTextDisplay | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return GaugeModule | false
function controlPanel.Panel:getGauge(x, y)
    return self:_get(classes.GaugeModule, x, y) --[[ @as GaugeModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return BigGaugeModule | false
function controlPanel.Panel:getGaugeBig(x, y)
    return self:_get(classes.BigGaugeModule, x, y) --[[ @as BigGaugeModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return BuzzerModule | false
function controlPanel.Panel:getBuzzer(x, y)
    return self:_get(classes.BuzzerModule, x, y) --[[ @as BuzzerModule | false ]]
end

--- Get a panel component, or `nil` if component can't be found or of the wrong type.
---
--- @param x integer
--- @param y integer
--- @return IndicatorModule | false
function controlPanel.Panel:getIndicator(x, y)
    local mod = self._panel:getModule(x, y) --[[ @as IndicatorModule | false ]]
    if mod and mod.setColor then
        return mod
    else
        return false
    end
end

--- @private
--- @param cls FINModuleBase-Class
--- @param x integer
--- @param y integer
--- @return FINModuleBase | false
function controlPanel.Panel:_get(cls, x, y)
    --- @diagnostic disable-next-line: param-type-mismatch
    local mod = self._panel:getModule(x, y, self._index) --[[ @as FINModuleBase | false ]]

    while mod and mod:isA(classes.BasicSubplate_2x2) do
        --- @cast mod BasicSubplate_2x2
        mod = mod:getSubModule() --[[ @as FINModuleBase | false ]]
    end

    if mod and mod:isA(cls) then
        return mod
    else
        return false
    end
end

return controlPanel
