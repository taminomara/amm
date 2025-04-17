local class = require "ammcore.class"
local scrollbox = require "ammgui.component.block.scrollbox"

--- Root component.
---
--- !doctype module
--- @class ammgui.component.block.root
local ns = {}

--- Root component.
---
--- @class ammgui.component.block.root.Root: ammgui.component.block.scrollbox.ScrollBox
ns.Root = class.create("Root", scrollbox.ScrollBox)

ns.Root.elem = ""

--- @param data ammgui.dom.DivNode
function ns.Root:onMount(ctx, data)
    self:setPseudoclass("root")
    scrollbox.ScrollBox.onMount(self, ctx, data)
end

function ns.Root:draw(ctx)
    ctx:pushLayout(structs.Vector2D { 0, 0 }, self.usedLayout.resolvedBorderBoxSize, true)
    scrollbox.ScrollBox.draw(self, ctx)
    ctx:popLayout()
end

return ns
