--- Block DOM nodes, i.e. containers.
---
--- !doctype module
--- @class ammgui.dom.block
local ns = {}

--- Base for block DOM node parameters.
---
--- @class ammgui.dom.block.NodeParams
--- @field key? any Key for synchronizing arrays of nodes.
--- @field class? string | (string | false)[] Array of CSS classes.
--- @field initialClass? string | (string | false)[] Array of initial CSS classes.
--- @field style? ammgui.css.rule.Rule Inline CSS style for this node.
--- @field initialStyle? ammgui.css.rule.Rule Initial CSS style for this node.
--- @field ref? ammgui.component.block.func.Ref<ammgui.component.block.Component?>
--- @field onMouseEnter? fun(pos: Vector2D, modifiers: integer): boolean?
--- @field onMouseMove? fun(pos: Vector2D, modifiers: integer): boolean?
--- @field onMouseExit? fun(pos: Vector2D, modifiers: integer): boolean?
--- @field onMouseDown? fun(pos: Vector2D, modifiers: integer): boolean?
--- @field onMouseUp? fun(pos: Vector2D, modifiers: integer): boolean?
--- @field onClick? fun(pos: Vector2D, modifiers: integer): boolean?
--- @field onRightClick? fun(pos: Vector2D, modifiers: integer): boolean?
--- @field onMouseWheel? fun(pos: Vector2D, delta: number, modifiers: integer): boolean?
--- @field dragTarget? any
--- @field isDraggable? boolean
--- @field onDragStart? fun(pos: Vector2D, origin: Vector2D, modifiers: integer, target: unknown?): boolean|"normal"|"ok"|"warn"|"err"|"none"|nil
--- @field onDrag? fun(pos: Vector2D, origin: Vector2D, modifiers: integer, target: unknown?): boolean|"normal"|"ok"|"warn"|"err"|"none"|nil
--- @field onDragEnd? fun(pos: Vector2D, origin: Vector2D, modifiers: integer, target: unknown?)

--- Base for block DOM nodes.
---
--- @class ammgui.dom.block.Node: ammgui.dom.block.NodeParams
--- @field package _isBlockNode true Cookie flag present on every node, helps with downcasting from `any`.
--- @field package _component ammgui.component.block.ComponentProvider Component class that implements this node.

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
--- @param params ammgui.dom.block.NodeParams node parameters.
--- @param component ammgui.component.block.ComponentProvider component class that implements this node.
--- @return ammgui.dom.block.Node node node with its component set to ``component``.
function ns.paramsToNode(params, component)
    --- @cast params ammgui.dom.block.Node
    params._isBlockNode = true
    params._component = component
    return params
end

return ns
