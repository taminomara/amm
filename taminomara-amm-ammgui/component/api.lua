local class = require "ammcore.class"

--- Public API for components.
---
--- Component implementations can potentially change, so you shouldn't rely on them.
--- Instead, we used this wrapper that provides stable API to the user.
---
--- !doctype module
--- @class ammgui.component.api
local ns = {}

--- Public API for components.
---
--- @class ammgui.component.api.ComponentApi: ammcore.class.Base
ns.ComponentApi = class.create("ComponentApi")

--- @param component ammgui.component.base.Component
---
--- !doctype classmethod
--- @generic T: ammgui.component.api.ComponentApi
--- @param self T
--- @return T
function ns.ComponentApi:New(component)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui.component.base.Component
    self._component = component

    return self
end

--- Set inline styles defined for this component.
---
--- .. warning::
---
---    Using this function on a node permanently disables styles set via the
---    `~ammgui.dom.NodeParams.style` parameter.
---
--- @param inline ammgui.css.rule.Rule
function ns.ComponentApi:setInlineCss(inline)
    return self._component:setInlineCss(inline, true)
end

--- Override current set of CSS classes by a new set.
---
--- .. warning::
---
---    Using this function on a node permanently disables classes set via the
---    `~ammgui.dom.NodeParams.class` parameter.
---
--- @param classes string | (string | false)[]
function ns.ComponentApi:setClasses(classes)
    return self._component:setClasses(classes, true)
end

--- Add a CSS class to the set of classes of this component.
---
--- .. warning::
---
---    Using this function on a node permanently disables classes set via the
---    `~ammgui.dom.NodeParams.class` parameter.
---
--- @param className string
function ns.ComponentApi:setClass(className)
    return self._component:setClass(className, true)
end

--- Remove a CSS class form the set of classes of this component.
---
--- .. warning::
---
---    Using this function on a node permanently disables classes set via the
---    `~ammgui.dom.NodeParams.class` parameter.
---
--- @param className string
function ns.ComponentApi:unsetClass(className)
    return self._component:unsetClass(className, true)
end

--- Check if a CSS class is set for this component.
---
--- @param className string
--- @return boolean
function ns.ComponentApi:hasClass(className)
    return self._component:hasClass(className)
end

--- Get CSS values that were calculated during the last render.
---
--- .. warning::
---
---    For children of components with ``display = "none"``,
---    CSS styles may be outdated.
---
--- @return ammgui.css.rule.Resolved
function ns.ComponentApi:getCss()
    return self._component.css
end

--- Get calculated size of the component's border box, not including overflow.
---
--- @return Vector2D
function ns.ComponentApi:getBorderBoxSize()
    local usedLayout = rawget(self._component, "usedLayout")
    return usedLayout and usedLayout.resolvedBorderBoxSize or structs.Vector2D { 0, 0 }
end

--- Get calculated size of the component's content box, not including overflow.
---
--- @return Vector2D
function ns.ComponentApi:getContentSize()
    local usedLayout = rawget(self._component, "usedLayout")
    return usedLayout and usedLayout.resolvedContentSize or structs.Vector2D { 0, 0 }
end

--- Get calculated minimum size of the component's border box.
---
--- This function returns resolved values for ``minWidth`` and ``minHeight``.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return Vector2D
function ns.ComponentApi:getBorderBoxMinSize()
    return self:getContentMinSize() + self:getBorderBoxSize() - self:getContentSize()
end

--- Get calculated minimum size of the component's content box.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return Vector2D
function ns.ComponentApi:getContentMinSize()
    local verticalLayout = rawget(self._component, "verticalLayout")
    return structs.Vector2D {
        verticalLayout and verticalLayout.resolvedContentMinSize or 0,
        verticalLayout and verticalLayout.resolvedContentMinSize or 0,
    }
end

--- Get calculated maximum size of the component's border box.
---
--- This function returns resolved values for ``maxWidth`` and ``maxHeight``.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return Vector2D
function ns.ComponentApi:getBorderBoxMaxSize()
    return self:getContentMaxSize() + self:getBorderBoxSize() - self:getContentSize()
end

--- Get calculated maximum size of the component's content box.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return Vector2D
function ns.ComponentApi:getContentMaxSize()
    local verticalLayout = rawget(self._component, "verticalLayout")
    return structs.Vector2D {
        verticalLayout and verticalLayout.resolvedContentMaxSize or 0,
        verticalLayout and verticalLayout.resolvedContentMaxSize or 0,
    }
end

return ns
