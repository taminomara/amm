local log = require "ammcore.log"
--- Css value parsers and validators.
---
--- !doctype module
--- @class ammgui._impl.css.parse
local ns = {}

--- @param x unknown
--- @param r ammgui._impl.css.resolved.Resolved
--- @return nil
function ns.parseFail(x, r, n)
    error(string.format("invalid %s value %s", n, log.pp(x)), 0)
end

--- @param x unknown
--- @param u string
--- @param n string
--- @return number value
--- @return string unit
function ns.parseUnit(x, u, n)
    if type(x) == "number" then
        return x, u
    elseif
        type(x) == "table"
        and #x == 2
        and type(x[1]) == "number"
        and type(x[2]) == "string"
    then
        ---@diagnostic disable-next-line: redundant-return-value
        return table.unpack(x)
    else
        error(string.format("invalid %s value %s", n, log.pp(x)))
    end
end

--- @param x unknown
--- @param r ammgui._impl.css.resolved.Resolved
--- @param n string
--- @return [number, "px"|"%"]
function ns.parseLength(x, r, n)
    local n, u = ns.parseUnit(x, "px", n)
    if u == "em" then
        local nn, nu = table.unpack(r.fontSize)
        n = n * nn
        u = nu
    end
    if u ~= "px" and u ~= "%" then
        local units = r.units
        if not units[u] then
            error(string.format("unknown %s unit %s", n, log.pp(u)), 0)
        end
        n = n * units[u]
        u = "px"
    end
    return { n, u }
end

--- @param x unknown
--- @param r ammgui._impl.css.resolved.Resolved
--- @return [number, "px"|"%"]
function ns.parsePositiveLength(x, r, n)
    local val = ns.parseLength(x, r, n)
    if val[1] < 0 then
        error(string.format("%s can't be negative", n), 0)
    end
    return val
end

--- @param x unknown
--- @param r ammgui._impl.css.resolved.Resolved
--- @param n string
--- @return [number, "px"]
function ns.parseFontSize(x, r, n)
    local n, u = ns.parseUnit(x, "px", n)
    if n < 0 then
        error(string.format("%s can't be negative", n), 0)
    end
    if u == "%" then
        local nn, nu = table.unpack(r.getInherited(r, "fontSize"))
        n = n * nn / 100
        u = nu
    elseif u == "em" then
        local nn, nu = table.unpack(r.getInherited(r, "fontSize"))
        n = n * nn
        u = nu
    end
    if u ~= "px" then
        local units = r.units
        if not units[u] then
            error(string.format("unknown %s unit %s", n, log.pp(u)), 0)
        end
        n = n * units[u]
        u = "px"
    end
    return { n, u }
end

--- @param x unknown
--- @param r ammgui._impl.css.resolved.Resolved
--- @param n string
--- @return [number, "px"|""]
function ns.parseLineHeight(x, r, n)
    local n, u = ns.parseUnit(x, "", n)
    if n < 0 then
        error(string.format("%s can't be negative", n), 0)
    end
    if u == "%" then
        local nn, nu = table.unpack(r.fontSize)
        n = n * nn / 100
        u = nu
    elseif u == "em" then
        local nn, nu = table.unpack(r.fontSize)
        n = n * nn
        u = nu
    end
    if u ~= "px" and u ~= "" then
        local units = r.units
        if not units[u] then
            error(string.format("unknown %s unit %s", n, log.pp(u)), 0)
        end
        n = n * units[u]
        u = "px"
    end
    return { n, u }
end

--- @param x unknown
--- @param r ammgui._impl.css.resolved.Resolved
--- @param n string
--- @return Color
function ns.parseColor(x, r, n)
    local theme = r.theme

    if type(x) == "string" then x = x:lower() end
    while theme[x] do
        x = theme[x]
        if type(x) == "string" then x = x:lower() end
    end

    if type(x) == "string" then
        if x == "transparent" then
            return structs.Color { 0, 0, 0, 0 }
        elseif x == "currentcolor" then
            if n == "color" then
                return r:getInherited(n)
            else
                return r.color
            end
        elseif x == "currentbackgroundcolor" then
            if n == "backgroundColor" then
                return r:getInherited(n)
            else
                return r.backgroundColor
            end
        end

        local r, g, b, a
        for _, m in ipairs({
            "^#(%x)(%x)(%x)$",
            "^#(%x)(%x)(%x)(%x)$",
            "^#(%x%x)(%x%x)(%x%x)$",
            "^#(%x%x)(%x%x)(%x%x)(%x%x)$",
        }) do
            r, g, b, a = x:match(m)
            if r and g and b then
                if not a then
                    a = "ff"
                end
                break
            end
        end
        if not r or not g or not b or not a then
            error(string.format("invalid %s value %s", n, log.pp(x)), 0)
        end

        return structs.Color {
            r = tonumber(r, 16) / (2 ^ (4 * r:len()) - 1),
            g = tonumber(g, 16) / (2 ^ (4 * g:len()) - 1),
            b = tonumber(b, 16) / (2 ^ (4 * b:len()) - 1),
            a = tonumber(a, 16) / (2 ^ (4 * a:len()) - 1),
        }
    elseif type(x) == "userdata" or (type(x) == "table" and x.__amm_is_color) then
        return x
    else
        error(string.format("invalid %s value %s", n, log.pp(x)), 0)
    end
end

--- @param x unknown
--- @param r ammgui._impl.css.resolved.Resolved
--- @param n string
--- @return number
function ns.parseFloat(x, r, n)
    if type(x) == "number" then
        return x
    else
        error(string.format("invalid %s value %s", n, log.pp(x)), 0)
    end
end

return ns
