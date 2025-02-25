--- Simple utilities on top of the `debug` module.
local debugHelpers = {}

--- Get module name at stack frame `n`.
---
--- @param n integer?
--- @return string
function debugHelpers.getMod(n)
    local mod = debugHelpers.getFile((n or 1) + 1):gsub("[/\\]", ".")
    if debug.getinfo((n or 1) + 1).what ~= "main" then
        mod = mod .. ".<locals>"
    end
    return mod
end

--- Get file name at stack frame `n`.
---
--- @param n integer?
--- @return string
function debugHelpers.getFile(n)
    local src = debug.getinfo((n or 1) + 1).short_src or ""

    local path
    if not path then path = src:match("^%[string \"(.-)%.lua\"%]$") end
    if not path then path = src:match("^(EEPROM)$") end
    return path or "<unknown>"
end

--- Get current line number at stack frame `n`.
---
--- @param n integer?
--- @return integer
function debugHelpers.getLine(n)
    local line = debug.getinfo((n or 1) + 1).currentline
    return line
end

--- Get current location at stack frame `n`.
---
--- @param n integer?
--- @return string
function debugHelpers.getLoc(n)
    local loc = string.format(
        "%s:%s",
        debugHelpers.getFile((n or 1) + 1),
        debugHelpers.getLine((n or 1) + 1)
    )
    return loc
end

return debugHelpers
