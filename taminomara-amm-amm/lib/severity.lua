--- Definitions for error severity and assotiated colors.
local severity = {}

local severityNames = {}
local severityColors = {}

--- Color representation.
---
--- Consists of three numbers between `0` and `1`
--- representing values for red, green and blue components.
---
--- An additional component might be added to make an object blink.
---
--- @alias severity.Color [number, number, number, boolean?]

--- Everything that can be colored.
---
--- @alias severity.Colorable
--- | IndicatorPole
--- | ModularPoleModule_Indicator
--- | PushbuttonModule
--- | MushroomPushbuttonModule
--- | PotWDisplayModule
--- | SwitchModule2Position
--- | SwitchModule3Position
--- | ModuleButton
--- | EncoderModule
--- | PotentiometerModule
--- | BigGaugeModule
--- | GaugeModule
--- | SquareMicroDisplayModule
--- | MicroDisplayModule
--- | LargeMicroDisplayModule
--- | IndicatorModule
--- | VehicleScanner

--- Everything that can be enabled or disabled.
---
--- @alias severity.Toggleable
--- | PushbuttonModule
--- | MushroomPushbuttonModule
--- | PotWDisplayModule
--- | SwitchModule2Position
--- | SwitchModule3Position
--- | EncoderModule
--- | PotentiometerModule

--- Issue severity.
---
--- @enum severity.Severity
severity.Severity = {
    --- Critical error.
    CRIT = 5,
    --- Error.
    ERR = 4,
    --- Warning.
    WARN = 3,
    --- Info.
    INFO = 2,
    --- Ok, i.e. no errors.
    OK = 1,
}

--- Default brightness for enabled indicators and buttons.
severity.defaultOnBrightness = 0.2

--- Default brightness for disabled indicators and buttons.
severity.defaultOffBrightness = 0

--- @type table<number, [severity.Colorable, severity.Color]>
local blinking = {}
--- @type table<number, BuzzerModule>
local alarming = {}

--- Get name of a severity level.
---
--- @param sv severity.Severity
--- @return string
function severity.getName(sv)
    return severityNames[sv]
end

--- Get default indicator color for a severity level.
---
--- @param sv severity.Severity
--- @return severity.Color
function severity.getColor(sv)
    return severityColors[sv]
end

--- Set color of an indicator or a button according to the given severity,
--- and use `severity.defaultOnBrightness`.
---
--- @param button severity.Colorable
--- @param sv severity.Severity | severity.Color
function severity.setObjectColor(button, sv)
    if type(sv) == "number" then sv = severity.getColor(sv) end
    sv = sv or { 1, 1, 1 }
    blinking[button.hash] = sv[4] and { button, sv } or nil
    button:setColor(sv[1], sv[2], sv[3], severity.defaultOnBrightness)
end

--- Enable an indicator or a button and color it according to the given severity.
---
--- @param button severity.Toggleable
--- @param sv severity.Severity | severity.Color | nil
function severity.turnOn(button, sv)
    severity.setObjectColor(button, sv or { 1, 1, 1 })
    button.enabled = true
end

--- Set color of an indicator or a button according to the given severity,
--- and use `severity.defaultOffBrightness`.
---
--- @param button severity.Colorable
--- @param sv severity.Severity | severity.Color
function severity.setDisabledObjectColor(button, sv)
    if type(sv) == "number" then sv = severity.getColor(sv) end
    sv = sv or { 1, 1, 1 }
    blinking[button.hash] = nil
    button:setColor(sv[1], sv[2], sv[3], severity.defaultOffBrightness)
end

--- Disable an indicator or a button and color it according to the given severity.
---
--- @param button severity.Toggleable
--- @param sv severity.Severity | severity.Color | nil
function severity.turnOff(button, sv)
    severity.setDisabledObjectColor(button, sv or { 1, 1, 1 })
    button.enabled = false
end

--- Sound alarm.
---
--- @param buzzer BuzzerModule
function severity.alarm(buzzer)
    buzzer.volume = 1
    buzzer.frequency = 800
    buzzer.attackCurve = 0
    buzzer.attackTime = 0.75
    alarming[buzzer.hash] = buzzer
end

--- Stop sounding alarm.
---
--- @param buzzer BuzzerModule
function severity.stopAlarm(buzzer)
    if buzzer.isPlaying then
        local _ = buzzer:stop()
    end
    alarming[buzzer.hash] = nil
end

severityNames = {
    [severity.Severity.CRIT] = "CRIT",
    [severity.Severity.ERR] = "ERR",
    [severity.Severity.WARN] = "WARN",
    [severity.Severity.INFO] = "INFO",
    [severity.Severity.OK] = "OK",
}

severityColors = {
    [severity.Severity.CRIT] = { 1, 0, 1 },
    [severity.Severity.ERR] = { 1, 0, 0 },
    [severity.Severity.WARN] = { 1, 1, 0 },
    [severity.Severity.INFO] = { 0, 1, 1 },
    [severity.Severity.OK] = { 0, 1, 0 },
}

future.addTask(async(function()
    local isOn = false
    while true do
        sleep(1)
        for hash, data in pairs(blinking) do
            local button, color = table.unpack(data)
            local ok
            if isOn then
                ok = pcall(button.setColor, button, color[1], color[2], color[3], severity.defaultOnBrightness)
            else
                ok = pcall(button.setColor, button, color[1] * 0.01, color[2] * 0.01, color[3] * 0.01, severity.defaultOffBrightness)
            end
            if not ok then
                blinking[hash] = nil
            end
        end
        isOn = not isOn
    end
end))

future.addTask(async(function()
    while true do
        sleep(1.3)
        for hash, alarm in pairs(alarming) do
            if not pcall(alarm.beep, alarm) then
                alarming[hash] = nil
            end
        end
    end
end))

return severity
