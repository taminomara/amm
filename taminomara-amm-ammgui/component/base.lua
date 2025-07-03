--- Base class for components.
---
--- !doctype module
--- @class ammgui.component
local ns = {}

--- Base parameters that can be passed to any component.
---
--- @class ammgui.component.Params
--- @field key? any Key for synchronizing arrays of nodes.

--- Base for all components.
---
--- This is a simple table that holds component's parameters and some internal info.
--- The component's state and implementation are stored separately.
---
--- @class ammgui.component.Component: ammgui.component.Params
--- @field package _isComponent true Cookie flag present on every component, helps with downcasting from `any`.
--- @field package _backend ammgui._impl.backend.Component Component backend that implements this node.

--- @alias ammgui.component.Any ammgui.component.Component | string | false

return ns
