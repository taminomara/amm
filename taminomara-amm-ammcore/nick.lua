--- @namespace ammcore.nick

local class = require "ammcore.class"
local log = require "ammcore.log"

--- Utilities for parsing component nicks.
---
---
--- Nick format
--- -----------
---
--- Nicks are parsed similar to how bash parses program's arguments. They can have
--- positional and named parameters, separated by spaces. Named parameters
--- have format ``name=value``, and positional parameters have format ``value``.
---
--- Values can't have spaces in them. However, you can escape spaces using
--- double-quoted strings. To escape a quote inside of a string, put it twice.
---
--- For example, the following nick
---
--- .. code-block:: text
---
---    positional "positional=with=eq" name1=value name2="value "" with quote"
---
--- has two positional parameters (``positional`` and ``positional=with=eq``),
--- and two named parameters (``name1`` is ``value``, and
--- ``name2`` is ``value " with quote``).
local ns = {}

local logger = log.getLogger()

--- Result of parsing component's nick.
---
--- @class ParsedNick: ammcore.class.Base
--- @field [string] string[]
--- @field [integer] string
ns.ParsedNick = class.create("ParsedNick")

--- Return the first value for parameter ``name``, parsed by function ``ty``.
---
--- @generic T
--- @param name string name of the parameter to get.
--- @param ty fun(s: string): T function to parse a raw string; should return `nil` if parsing fails.
--- @return T? value parsed value or `nil` if parsing failed or parameter was not found.
function ns.ParsedNick:getOne(name, ty)
    local value = self[name]
    if not value then
        return nil
    end

    local first = value[1]
    if not first then
        return nil
    end

    local parsed = ty(first)
    if not parsed then
        logger:warning("Unable to parse nick, invalid value for %s: %q", name, first)
        return nil
    end
    return parsed
end

--- Return all values for parameter ``name``, parsed by function ``ty``.
---
--- @generic T
--- @param name string name of the parameter to get.
--- @param ty fun(s: string): T function to parse a raw string; should return `nil` if parsing fails.
--- @return T[] parsed values.
function ns.ParsedNick:getAll(name, ty)
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

--- Return a value for positional parameter ``pos``, parsed by function ``ty``.
---
--- @generic T
--- @param pos integer name of the parameter to get.
--- @param ty fun(s: string): T function to parse a raw string; should return `nil` if parsing fails.
--- @return T? value parsed value or `nil` if parsing failed or parameter was not found.
function ns.ParsedNick:getPos(pos, ty)
    local value = self[pos]
    if not value then
        return nil
    end
    local parsed = ty(value)
    if not parsed then
        logger:warning("Unable to parse nick, invalid value for %s: %q", pos, value)
        return nil
    end
    return parsed
end

--- Parse key-value pairs from object's nick.
---
--- @param nick string nick to parse.
--- @return ParsedNick parsed parsing result.
function ns.parse(nick)
    local result = ns.ParsedNick()

    local pos = 1
    while pos <= nick:len() do
        local name, value
        local _, nextPos, ch = nick:find('([%s"=])', pos)
        nextPos, ch = nextPos or nick:len() + 1, ch or " "
        if ch == "=" then
            name = nick:sub(pos, nextPos - 1)
            pos = nextPos + 1
            _, nextPos, ch = nick:find('([%s"])', nextPos + 1)
            nextPos, ch = nextPos or nick:len() + 1, ch or " "
        end
        while nextPos <= nick:len() and not ch:match("^%s$") do
            -- find closing quote
            _, nextPos, ch = string.find(nick, "%" .. ch .. "(.?)", nextPos + 1)
            nextPos, ch = nextPos or nick:len() + 1, ch or " "
        end
        value = nick:sub(pos, nextPos - 1):gsub("\"(\"?)", "%1")

        if name then
            result[name] = result[name] or {}
            table.insert(result[name], value)
        else
            table.insert(result --[[@as string[] ]], value)
        end

        _, nextPos = nick:find('%S', nextPos + 1)
        pos = nextPos or nick:len() + 1
    end

    return result
end

return ns
