local class = require "ammcore.class"
local fun   = require "ammcore.fun"
local log   = require "ammcore.log"

--- Base class for all components.
---
--- !doctype module
--- @class ammgui._impl.component
local ns = {}

local logger = log.Logger:New()

--- Base class for all components.
---
--- @class ammgui._impl.component.Component: ammcore.class.Base
ns.Component = class.create("Component")

--- @param key any
---
--- !doctype classmethod
--- @generic T: ammgui._impl.component.Component
--- @param self T
--- @return T
function ns.Component:New(key)
    self = class.Base.New(self)

    --- !doctype const
    --- @type any?
    self.key = key

    return self
end

--- Called when component is initialized.
---
--- !doc abstract
--- @param ctx ammgui.component.context.SyncContext
--- @param data ammgui.dom.Node user-provided component data.
function ns.Component:onMount(ctx, data)
    error("not implemented")
end

--- Called when component is updated.
---
--- !doc abstract
--- @param ctx ammgui.component.context.SyncContext
--- @param data ammgui.dom.Node user-provided component data.
function ns.Component:onUpdate(ctx, data)
    error("not implemented")
end

--- Called when component is destroyed.
---
--- !doc abstract
--- @param ctx ammgui.component.context.SyncContext
function ns.Component:onUnmount(ctx)
    error("not implemented")
end

--- Called to collect actual HTML tag implementations.
---
--- Should add node components to the given array.
---
--- @param components ammgui._impl.nodeComponent.NodeComponent[]
function ns.Component:collect(components)
    error("not implemented")
end

--- Process a reference.
---
--- @param ref ammgui.component.block.func.Ref<ammgui.component.api.ComponentApi?>
function ns.Component:noteRef(ref)
    error("not implemented")
end

--- Sync one DOM node with its component.
---
--- @param ctx ammgui.component.context.SyncContext
--- @param component ammgui._impl.component.Component? component that was updated.
--- @param node ammgui.dom.AnyNode node that corresponds to this component.
--- @return ammgui._impl.component.Component component resulting component class.
function ns.Component.syncOne(ctx, component, node)
    if type(node) == "string" then
        error("todo")
        -- text = text or require("ammgui.component.inline.text") -- Prevent circular import.
        -- node = { node, _isNode = true, _component = text.Text }
    end

    ---@diagnostic disable-next-line: invisible
    local nodeComponent = node._component
    if component and nodeComponent == component.__class then
        component:onUpdate(ctx, node)
    else
        if component then
            component:onUnmount(ctx)
        end
        component = nodeComponent:New(node.key)
        component:onMount(ctx, node)
    end
    return component
end

--- Sync array of DOM nodes with their components.
---
--- @param ctx ammgui.component.context.SyncContext
--- @param components ammgui._impl.component.Component[]
--- @param nodes ammgui.dom.AnyNode[]
--- @return ammgui._impl.component.Component[] components
function ns.Component.syncProviders(ctx, components, nodes)
    local componentByKey = {}
    for i, component in ipairs(components) do
        local key = component.key or i
        if componentByKey[key] then
            logger:warning(
                "multiple components with the same key %s: %s, %s",
                log.pp(key), componentByKey[key], component
            )
        else
            componentByKey[key] = component
        end
    end

    local newProviders = {}

    local function syncOne(key, node)
        table.insert(newProviders, ns.Component.syncOne(ctx, componentByKey[key], node))
        componentByKey[key] = nil
    end

    local pendingString = nil
    local pendingStringKey = 0

    for _, node in ipairs(nodes) do
        if type(node) == "string" then
            if pendingString then
                pendingString = pendingString .. node
            else
                pendingString = node
                pendingStringKey = #newProviders + 1
            end
        ---@diagnostic disable-next-line: invisible
        elseif node._isNode then
            --- @cast node ammgui.dom.Node
            if pendingString then
                syncOne(pendingStringKey, pendingString)
                pendingString = nil
            end
            syncOne(node.key or #newProviders + 1, node)
        else
            error(string.format("not a DOM node: %s", log.pp(node)))
        end
    end
    if pendingString then
        syncOne(pendingStringKey, pendingString)
    end

    return newProviders
end

--- Sync array of DOM nodes with their components.
---
--- @param ctx ammgui.component.context.SyncContext
--- @param components ammgui._impl.component.Component[]
--- @param nodeComponents ammgui._impl.nodeComponent.NodeComponent[]
--- @param nodes ammgui.dom.AnyNode[]
--- @param parent ammgui._impl.nodeComponent.NodeComponent
--- @return ammgui._impl.component.Component[] providers
--- @return ammgui._impl.nodeComponent.NodeComponent[] components
function ns.Component.syncAll(ctx, components, nodeComponents, nodes, parent)
    local newComponents = ns.Component.syncProviders(ctx, components, nodes)

    local newNodeComponents = {}

    for _, component in ipairs(newComponents) do
        component:collect(newNodeComponents)
    end

    for _, component in ipairs(newNodeComponents) do
        component.parent = parent
    end

    return newComponents, newNodeComponents
end

return ns
