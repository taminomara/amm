local blockComponent = require "ammgui.component.block"

--- Block DOM nodes.
---
--- !doctype module
--- @class ammgui.dom.block
local ns = {}

--- Base for block DOM nodes.
---
--- @class ammgui.dom.block.Node
--- @field _isBlockNode true
--- @field _component ammgui.component.block.Component Component class asscociated with this node.
--- @field key? integer | string Key for synchronizing arrays of nodes.

--- @type ammgui.dom.block.Node
local TextContainerNode = { _isBlockNode = true, _component = blockComponent.TextContainer }
TextContainerNode.__index = TextContainerNode

--- Parameters for `ammgui.dom.block.p`.
---
--- @class ammgui.dom.block.PParams
--- @field [number] string | ammgui.dom.inline.Node Paragraph contents.
--- @field key? integer | string Key for synchronizing arrays of nodes.

--- Create a paragraph.
---
--- This is equivalent to ``<p>`` element in HTML.
---
--- Example:
---
--- .. code-block:: lua
---
---    local p = dom.p { "Hello, ", dom.code "world", "!" }
---
--- @param params ammgui.dom.block.PParams paragraph parameters.
--- @return ammgui.dom.block.Node
function ns.p(params)
    return setmetatable(params, TextContainerNode) --[[ @as ammgui.dom.block.Node ]]
end

return ns
