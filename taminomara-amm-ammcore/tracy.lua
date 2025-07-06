--- @namespace ammcore.tracy

--- Wrappers for tracy library.
---
--- These functions don't do anything when FIN compiled without tracy.
local ns = {}

--- Begin tracy zone.
function ns.zoneBegin() end

--- End tracy zone.
function ns.zoneEnd() end

--- Begin named tracy zone.
---
--- Zone names should not contain any runtime data, as they will be used
--- for grouping zones in profiler. Use `ZoneName` if you want to set a dynamic
--- zone name.
function ns.zoneBeginN(name) end

--- Add an additional zone text/description.
---
--- A zone can have multiple descriptions, all of them will be displayed in profiler.
---
--- @param text string
function ns.zoneText(text) end

--- Like `zoneText`, but accepts a format string and format parameters.
---
--- This is equivalent to:
---
--- .. code-block:: lua
---
---    tracy.zoneText(string.format(text, ...))
function ns.zoneTextF(text, ...) end

--- Add an additional zone name.
---
--- Zone can have a dynamic name that will be displayed in profiler,
--- but will not affect zone grouping.
---
--- @param text string
function ns.zoneName(text) end

--- Like `zoneName`, but accepts a format string and format parameters.
---
--- This is equivalent to:
---
--- .. code-block:: lua
---
---    tracy.zoneName(string.format(text, ...))
function ns.zoneNameF(text, ...) end

--- Send a message that will be displayed in the profiler.
---
--- @param text string
function ns.message(text) end

--- Like `message`, but accepts a format string and format parameters.
---
--- This is equivalent to:
---
--- .. code-block:: lua
---
---    tracy.message(string.format(text, ...))
function ns.messageF(text, ...) end

--- Begin tracy zone with stack capturing.
---
--- @param depth integer
function ns.zoneBeginS(depth) end

--- Begin named tracy zone with stack capturing.
---
--- @param name string
--- @param depth integer
function ns.zoneBeginNS(name, depth) end

---@diagnostic disable-next-line: undefined-global
local tracy = tracy
if tracy then
    rawset(ns, "zoneBegin", tracy.ZoneBegin)
    rawset(ns, "zoneEnd", tracy.ZoneEnd)
    rawset(ns, "zoneBeginN", tracy.ZoneBeginN)
    rawset(ns, "zoneText", tracy.ZoneText)
    rawset(ns, "zoneTextF", function(text, ...) ns.zoneText(string.format(text, ...)) end)
    rawset(ns, "zoneName", tracy.ZoneName)
    rawset(ns, "zoneNameF", function(text, ...) ns.zoneName(string.format(text, ...)) end)
    rawset(ns, "message", tracy.Message)
    rawset(ns, "messageF", function(text, ...) ns.message(string.format(text, ...)) end)
    rawset(ns, "zoneBeginS", tracy.ZoneBeginS)
    rawset(ns, "zoneBeginNS", tracy.ZoneBeginNS)
end

local function scope()
    return setmetatable({}, { __close = ns.zoneEnd })
end

--- Begin tracy scope.
---
--- Usage:
---
--- .. code-block:: lua
---
---    do
---        local _ <close> = tracy.ZoneScoped()
---        -- Code that will be measured by tracy.
---    end
function ns.zoneScoped()
    ns.zoneBegin()
    return scope()
end

--- Begin named tracy scope.
---
--- Usage:
---
--- .. code-block:: lua
---
---    do
---        local _ <close> = tracy.ZoneScopedN("name")
---        -- Code that will be measured by tracy.
---    end
---
--- @param name string
function ns.zoneScopedN(name)
    ns.zoneBeginN(name)
    return scope()
end

--- Begin tracy scope with stack capturing.
---
--- Usage:
---
--- .. code-block:: lua
---
---    do
---        local _ <close> = tracy.ZoneScopedS(1)
---        -- Code that will be measured by tracy.
---    end
---
--- @param depth integer
function ns.zoneScopedS(depth)
    ns.zoneBeginS(depth)
    return scope()
end

--- Begin named tracy scope with stack capturing.
---
--- Usage:
---
--- .. code-block:: lua
---
---    do
---        local _ <close> = tracy.ZoneScopedNS("name", 1)
---        -- Code that will be measured by tracy.
---    end
---
--- @param name string
--- @param depth integer
function ns.zoneScopedNS(name, depth)
    ns.zoneBeginNS(name, depth)
    return scope()
end

return ns
