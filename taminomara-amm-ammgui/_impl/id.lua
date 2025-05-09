--- Unique ID generator.
---
--- Generates integers that're unique
---
--- !doctype module
--- @class ammgui._impl.id
local ns = {}

if __AMMGUI_IMPL_ID then
    error("ammgui._impl.id was imported twice under different names")
end
__AMMGUI_IMPL_ID = true

local function idGenerator(name)
    local id = 0
    return function()
        id = id + 1
        if id > 2 ^ 50 then
            computer.panic(string.format("ran out of integer IDs for %s", name))
        end
        return id
    end
end

--- A unique ID for a component.
---
--- @class ammgui._impl.id.EventListenerId

--- Make a new unique event listener ID.
---
--- @type fun(): ammgui._impl.id.EventListenerId
ns.newEventListenerId = idGenerator("EventListenerId")

return ns
