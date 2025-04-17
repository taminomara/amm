--- Utility functions.
---
--- !doctype module
--- @class ammgui.component.block.util
local ns = {}

--- @param value [number, "px"|"%"]
--- @param absValue number
--- @return number
function ns.resolvePercentage(value, absValue)
    if value[2] == "%" then
        return value[1] * absValue / 100
    else
        return value[1]
    end
end

--- @param value [number, "px"|"%"]|string?
--- @param absValue number
--- @return number?
function ns.resolvePercentageOrNil(value, absValue)
    if not value or type(value) == "string" then
        return nil
    elseif value[2] == "%" then
        return value[1] * absValue / 100
    else
        return value[1]
    end
end

--- @param value [number, "px"|"%"]|string?
--- @return number?
function ns.resolveAbsOrNil(value)
    if not value or type(value) == "string" or value[2] == "%" then
        return nil
    else
        return value[1]
    end
end

return ns
