local class = require "ammcore/util/class"
local log   = require "ammcore/util/log"

--- Utilities for parsing component nicks.
local nick = {}

local logger = log.Logger:New()

--- @class nick.ParsedNick: class.Base, { [string]: string[] }
nick.ParsedNick = class.create("ParsedNick")

--- Return the first value for parameter `name`, parsed by function `ty`.
---
--- @generic T
--- @param name string
--- @param ty fun(s: string): T
--- @return T?
function nick.ParsedNick:getOne(name, ty)
    local value = self[name]
    if not value or not value[1] then
        return nil
    end
    local parsed = ty(value[1])
    if not parsed then
        logger:warning("Unable to parse nick, invalid value for %s: %q", name, value[1])
        return nil
    end
    return parsed
end

--- Return all values for parameter `name`, parsed by function `ty`.
---
--- @generic T
--- @param name string
--- @param ty fun(s: string): T
--- @return T[]
function nick.ParsedNick:getAll(name, ty)
    local result = {}
    for _, value in ipairs(self[name] or {}) do
        local parsed = ty(value)
        if parsed then
            table.insert(result, parsed)
        else
            logger:warning("Unable to parse nick, invalid value for %s: %q", name, value)
        end
    end
    return result
end

--- Parse key-value pairs from object's nick.
---
--- If nick contains a hash symbol (`"#"`), everything up to the first hash symbol
--- is discarded. Then the rest of the string is parsed for key-value pairs separated
--- by equals sign (`"key=value"`), where keys are alphanumeric and values
--- are any non-space character. Spaces around equal signs are not permitted.
--- If a key appears more than once in the sequence, all associated values
--- are gathered into a single array.
---
--- @param s string
--- @return nick.ParsedNick
function nick.parse(s)
    s = string.gsub(s, "^.-#", "")
    local result = nick.ParsedNick:New()
    for k, v in string.gmatch(s, "(%w+)=(%S*)") do
        result[k] = result[k] or {}
        table.insert(result[k], v)
    end
    return result
end

return nick
