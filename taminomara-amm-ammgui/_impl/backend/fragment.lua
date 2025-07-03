local backend = require "ammgui._impl.backend"
local class = require "ammcore.class"

--- Backend for a generic list of components.
---
--- !doctype module
--- @class ammgui._impl.backend.fragment
local ns = {}

--- Render tree for a component that represents a single DOM node for a replaced element.
---
--- @class ammgui._impl.backend.fragment.RenderTreeFragmentNode: ammgui._impl.backend.RenderTreeNode
--- @field backend ammgui._impl.backend.fragment.FragmentComponent
--- @field children ammgui._impl.backend.RenderTreeNode[]
--- @field deletedChildren ammgui._impl.backend.RenderTreeNode[]

--- Backend for a component that represents a single DOM node.
---
--- @class ammgui._impl.backend.fragment.FragmentComponent: ammgui._impl.backend.Component
ns.FragmentComponent = class.create("FragmentComponent", backend.Component)

--- @param state? ammgui._impl.backend.fragment.RenderTreeFragmentNode current state of the component.
--- @param data ammgui.component.fragment.Fragment component's data returned by the user.
--- @return ammgui._impl.backend.fragment.RenderTreeFragmentNode updated state of the component, ready to be applied.
function ns.FragmentComponent:sync(ctx, state, data)
    local updatedStates, deletedStates
    if state then
        updatedStates, deletedStates = backend.sync(ctx, state.children, data)
    else
        updatedStates, deletedStates = backend.sync(ctx, {}, data)
    end
    return {
        key = data.key,
        backend = self,
        children = updatedStates,
        deletedChildren = deletedStates,
    }
end

ns.fragmentComponent = ns.FragmentComponent:New()

return ns
