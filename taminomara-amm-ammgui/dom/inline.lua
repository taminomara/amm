local inlineComponent = require "ammgui.component.inline"

--- Inline DOM nodes, i.e. text.
---
--- !doctype module
--- @class ammgui.dom.inline
local ns = {}

--- Base for inline DOM nodes.
---
--- @class ammgui.dom.inline.Node
--- @field _isInlineNode true
--- @field _component ammgui.component.inline.Component Component class asscociated with this node.
--- @field key? integer | string Key for synchronizing arrays of nodes.

--- @type ammgui.dom.inline.Node
local StringNode = { _isInlineNode = true, _component = inlineComponent.String }
StringNode.__index = StringNode

--- Parameters for `ammgui.dom.inline.string`.
---
--- @class ammgui.dom.inline.StringParams
--- @field [number] string String contents.
--- @field size? integer Font size.
--- @field monospace? boolean Use monospace font.
--- @field nobr? boolean Disable wrapping contents of this string.
--- @field color? Color Text color.
--- @field key? integer | string Key for synchronizing arrays of nodes.

--- Create a string with additional parameters.
---
--- This is equivalent to ``<span>`` element in HTML, except you can't nest them.
---
--- Example:
---
--- .. code-block:: lua
---
---    local s = dom.string { "Hello, world!", size = 24, monospace = true }
---
--- @param params ammgui.dom.inline.StringParams string parameters.
--- @return ammgui.dom.inline.Node
function ns.string(params)
    return setmetatable(params, StringNode) --[[ @as ammgui.dom.inline.Node ]]
end

--- Create a monospaced text.
---
--- @param text string text contents.
--- @return ammgui.dom.inline.Node
function ns.mono(text)
    return ns.string { text, monospace = true }
end

--- Create a monospaced non-breakable text.
---
--- @param text string text contents.
--- @return ammgui.dom.inline.Node
function ns.code(text)
    return ns.string { text, monospace = true, nobr = true }
end

--- Create an emphasized text.
---
--- @param text string text contents.
--- @return ammgui.dom.inline.Node
function ns.em(text)
    return ns.string { text, size=44 } -- TODO
end

return ns
