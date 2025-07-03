local backend = require "ammgui._impl.backend"
local class = require "ammcore.class"

--- Render tree and component backends for DOM nodes.
---
--- !doctype module
--- @class ammgui._impl.backend.dom
local ns = {}

--- Render tree for a component that represents a generic DOM node.
---
--- @class ammgui._impl.backend.dom.RenderTreeDomNode: ammgui._impl.backend.RenderTreeNode
--- @field backend ammgui._impl.backend.dom.DomComponent
--- @field data ammgui.component.dom.ContainerComponent
--- @field children ammgui._impl.backend.RenderTreeNode[]
--- @field deletedChildren ammgui._impl.backend.RenderTreeNode[]

--- Backend for a component that represents a single DOM node.
---
--- @class ammgui._impl.backend.dom.DomComponent: ammgui._impl.backend.Component
ns.DomComponent = class.create("DomComponent", backend.Component)

--- @param tag string HTML tag associated with this node.
---
--- !doctype classmethod
--- @generic T: ammgui._impl.backend.dom.DomComponent
--- @param self T
--- @return T
function ns.DomComponent:New(tag)
    self = backend.Component.New(self)

    --- HTML tag associated with this node.
    ---
    --- !doctype const
    --- @type string
    self.tag = tag

    return self
end

--- @param state? ammgui._impl.backend.dom.RenderTreeDomNode current state of the component.
--- @param data ammgui.component.dom.ContainerComponent component's data returned by the user.
--- @return ammgui._impl.backend.dom.RenderTreeDomNode updated state of the component, ready to be applied.
function ns.DomComponent:sync(ctx, state, data)
    local updatedStates, deletedStates
    if state then
        updatedStates, deletedStates = backend.sync(ctx, state.children, data)
    else
        updatedStates, deletedStates = backend.sync(ctx, {}, data)
    end
    return {
        key = data.key,
        backend = self,
        data = data,
        children = updatedStates,
        deletedChildren = deletedStates,
    }
end

return ns
