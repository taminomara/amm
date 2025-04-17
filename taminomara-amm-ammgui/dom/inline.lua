--- Inline DOM nodes, i.e. text.
---
--- !doctype module
--- @class ammgui.dom.inline
local ns = {}

--- Base for inline DOM node parameters.
---
--- @class ammgui.dom.inline.NodeParams
--- @field key? integer | string Key for synchronizing arrays of nodes.
--- @field class? string | string[] Array of CSS classes.
--- @field style? ammgui.css.rule.Rule Inline CSS style for this node.

--- Base for inline DOM nodes.
---
--- @class ammgui.dom.inline.Node: ammgui.dom.inline.NodeParams
--- @field package _isInlineNode true Cookie flag present on every node, helps with downcasting from `any`.
--- @field package _component ammgui.component.inline.ComponentProvider Component class that implements this node.

--- Convert `NodeParams` to `Node`.
---
--- This function is used by node implementations to ensure that a node
--- has correct metadata.
---
--- .. warning::
---
---    This function is not stable, it may be changed or deleted in the future.
---    Do not use directly, prefer concrete node constructors.
---
--- @param params ammgui.dom.inline.NodeParams node parameters.
--- @param component ammgui.component.inline.ComponentProvider component class that implements this node.
--- @return ammgui.dom.inline.Node node node with its component set to ``component``.
function ns.paramsToNode(params, component)
    --- @cast params ammgui.dom.inline.Node
    params._isInlineNode = true
    params._component = component
    return params
end

return ns
