local class = require "ammcore.class"
local component = require "ammgui._impl.component.component"

--- Canvas component.
---
--- !doctype module
--- @class ammgui._impl.component.canvas
local ns = {}

---
---
--- @class ammgui._impl.component.canvas.Canvas: ammgui._impl.component.component.Component
ns.Canvas = class.create("Canvas", component.Component)

function ns.Canvas:onMount(ctx, data)
end

function ns.Canvas:onUpdate(ctx, data)
end

function ns.Canvas:makeLayout()
    -- return text.Canvas:New(self.css, self._text or "")
end

return ns
