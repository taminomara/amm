local class = require "ammcore.class"
local log   = require "ammcore.log"

--- This module contains implementations for DOM nodes, called components.
--- There are three kinds of components in AmmGui:
---
--- - node components, like ``<div>`` or ``<span>``. They can have other components
---   as children;
--- - replaced components, like ``<canvas>`` or ``<img>``. They can't have children,
---   and they're treated as black boxes with known dimensions and/or preferred aspect
---   ratios;
--- - text component, i.e. a raw text fragment. They're spawned whenever there's
---   a string in the DOM three;
--- - provider components. They don't have their own representation, but instead they
---   create other nodes during synchronization.
---
--- All of them are organized in the following structure:
---
--- .. code-block:: text
---
---    Provider
---     |
---     +-- Component
---     |    |
---     |    +-- Text
---     |    |
---     |    +-- Node
---     |    |
---     |    +-- Canvas
---     |    |
---     |   ...  <other replaced components>
---     |
---     +-- List
---     |
---     +-- Func
---     |
---    ...
---
--- !doctype module
--- @class ammgui._impl.component.provider
local ns = {}

local logger = log.Logger:New()

--- An interface that abstracts over a single component and a list of components.
---
--- Things like lists and functional components implement `ComponentProvider`.
--- They perform their synchronization logic and yield `Component` implementations.
---
--- `Component`, on the other hand, is a thing that we actually see on the screen.
--- For convenience, each `Component` implements `ComponentProvider`, yielding itself
--- as the only implementation.
---
--- @class ammgui._impl.component.provider.Provider: ammcore.class.Base
ns.Provider = class.create("Provider")

--- @param key any
---
--- !doctype classmethod
--- @generic T: ammgui._impl.component.provider.Provider
--- @param self T
--- @return T
function ns.Provider:New(key)
    self = class.Base.New(self)

    --- !doctype const
    --- @type any?
    self.key = key

    return self
end

--- Called when component is initialized.
---
--- !doc abstract
--- @param ctx ammgui._impl.context.sync.Context
--- @param data ammgui.dom.Node user-provided component data.
function ns.Provider:onMount(ctx, data)
    error("not implemented")
end

--- Called when component is updated.
---
--- !doc abstract
--- @param ctx ammgui._impl.context.sync.Context
--- @param data ammgui.dom.Node user-provided component data.
function ns.Provider:onUpdate(ctx, data)
    error("not implemented")
end

--- Called when component is destroyed.
---
--- !doc virtual
--- @param ctx ammgui._impl.context.sync.Context
function ns.Provider:onUnmount(ctx)
    -- nothing to do here.
end

--- Called to collect actual HTML tag implementations.
---
--- Should add node components to the given array.
---
--- @param components ammgui._impl.component.component.Component[]
function ns.Provider:collect(components)
    error("not implemented")
end

--- Process a reference.
---
--- @param ref ammgui.Ref<ammgui.NodeApi?>
function ns.Provider:noteRef(ref)
    error("not implemented")
end

--- @type ammgui._impl.component.text?
local text = nil

--- Sync one DOM node with its component.
---
--- @param ctx ammgui._impl.context.sync.Context
--- @param component ammgui._impl.component.provider.Provider? component that was updated.
--- @param node ammgui.dom.AnyNode node that corresponds to this component.
--- @return ammgui._impl.component.provider.Provider component resulting component class.
function ns.Provider.syncOne(ctx, component, node)
    if type(node) == "string" then
        text = text or require("ammgui._impl.component.text") -- Prevent circular import.
        node = { node, _isNode = true, _component = text.Text }
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

    if node.ref then
        component:noteRef(node.ref)
    end

    return component
end

--- Sync array of DOM nodes with their components.
---
--- @param ctx ammgui._impl.context.sync.Context
--- @param components ammgui._impl.component.provider.Provider[]
--- @param nodes ammgui.dom.AnyNode[]
--- @return ammgui._impl.component.provider.Provider[] components
function ns.Provider.syncProviders(ctx, components, nodes)
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
        table.insert(newProviders, ns.Provider.syncOne(ctx, componentByKey[key], node))
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
--- @param ctx ammgui._impl.context.sync.Context
--- @param components ammgui._impl.component.provider.Provider[]
--- @param nodes ammgui.dom.AnyNode[]
--- @param parent ammgui._impl.component.component.Component
--- @return ammgui._impl.component.provider.Provider[] providers
--- @return ammgui._impl.component.component.Component[] components
function ns.Provider.syncAll(ctx, components, nodes, parent)
    local newComponents = ns.Provider.syncProviders(ctx, components, nodes)

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
