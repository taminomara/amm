local bootloader = require "ammcore/bootloader"

--- Simple utilities on top of the `debug` module.
local ns = {}

--- Get module name at stack frame `n`.
---
--- @param n integer?
--- @return string
function ns.getMod(n)
    return bootloader.getModuleByRealPath(ns.getFile((n or 1) + 1)) or "<unknown>"
end

--- Get file name at stack frame `n`.
---
--- @param n integer?
--- @return string
function ns.getFile(n)
    return debug.getinfo((n or 1) + 1).source:match("^@(.-)$") or "<unknown>"
end

--- Get current line number at stack frame `n`.
---
--- @param n integer?
--- @return integer
function ns.getLine(n)
    local line = debug.getinfo((n or 1) + 1).currentline
    return line
end

--- Get current location at stack frame `n`.
---
--- @param n integer?
--- @return string
function ns.getLoc(n)
    local loc = string.format(
        "%s:%s",
        ns.getFile((n or 1) + 1),
        ns.getLine((n or 1) + 1)
    )
    return loc
end

return ns
