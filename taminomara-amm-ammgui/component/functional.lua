--- Functional components.
---
--- !doctype module
--- @class ammgui.component.functional
local ns = {}

--- Base class for functional .
---
--- See `fragment` for details.
---
--- @class ammgui.component.functional.FunctionalParams: ammgui.component.Params
--- @field [integer] ammgui.component.Any Children.

--- Component that represents a list of other components without an enclosing DOM node.
---
--- See `fragment` for details.
---
--- @class ammgui.component.functional.Functional: ammgui.component.functional.FunctionalParams, ammgui.component.Component
--- @field package _isComponent true
--- @field package _backend ammgui._impl.backend.functional.FunctionalComponent

return ns
