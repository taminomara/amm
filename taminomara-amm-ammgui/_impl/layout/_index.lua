local class = require "ammcore.class"
--- Layout calculation algorithms.
---
--- !doctype module
--- @class ammgui._impl.layout._index
local ns = {}

--- Base class for layout calculation.
---
--- Layout can be performed in two modes (a.k.a. flows): inline and block.
---
--- In inline flow, the layout algorithm should split a node into inline elements
--- and return them to be further handled by textbox. When an element with
--- ``display`` other than ``inline`` is laid out in inline mode, it is wrapped
--- into a special element that behaves like ``inline-block``.
---
--- In block flow, the layout algorithm should determine size of the node,
--- and calculate positions of its children. To do so, it must first collect
--- all inline children into text boxes. Inline elements should never be laid out
--- in block flow.
---
--- @class ammgui._impl.layout._index.Layout: ammcore.class.Base
ns.Layout = class.create("Layout")

function ns.Layout:runInlineFlow()
    error("not implemented")
end

--- Run layout in block mode.
---
--- @param availableWidth number? available width, used to resolve percentage values. `nil` if unknown or infinite.
--- @param availableHeight number?  available height, used to resolve percentage values. `nil` if unknown or infinite.
--- @return Vector2D borderBoxPos position of the border box.
--- @return Vector2D borderBoxSize size of the border box.
--- @return Vector2D contentPos position of the content box.
--- @return Vector2D contentSize size of the content box.
--- @return Vector2D borderBoxVisibleSize size of the border box, including any visible overflow.
--- @return number outlineWidth width of the border.
function ns.Layout:runBlockFlow(availableWidth, availableHeight)
    error("not implemented")
end

return ns
