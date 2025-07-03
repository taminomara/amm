local log   = require "ammcore.log"
local class = require "ammcore.class"

--- Render tree and component backends.
---
--- !doctype module
--- @class ammgui._impl.backend
local ns = {}

local logger = log.Logger:New()

--- Render tree node.
---
--- Holds current data of a particular component.
---
--- @class ammgui._impl.backend.RenderTreeNode
--- @field key any Key for synchronizing arrays of nodes.
--- @field backend ammgui._impl.backend.Component Component backend that implements this node.

--- Component backend.
---
--- Updates render trees based on user-provided component data.
---
--- @class ammgui._impl.backend.Component: ammcore.class.Base
ns.Component = class.create("Component")

--- Synchronize render tree with the new component data received from the user,
--- producing a new render tree.
---
--- !doc abstract
--- @param ctx ammgui._impl.context.sync.Context synchronization context.
--- @param state? ammgui._impl.backend.RenderTreeNode current state of the component.
--- @param data ammgui.component.Component component's data returned by the user.
--- @return ammgui._impl.backend.RenderTreeNode updated state of the component, ready to be applied.
function ns.Component:sync(ctx, state, data)
    error("not implemented")
end

--- Sync one component datum with its render tree node.
---
--- @param ctx ammgui._impl.context.sync.Context
--- @param state ammgui._impl.backend.RenderTreeNode?
--- @param datum ammgui.component.Any
--- @return ammgui._impl.backend.RenderTreeNode? updatedState
--- @return ammgui._impl.backend.RenderTreeNode? deletedState
function ns.syncOne(ctx, state, datum)
    if type(datum) == "string" then
        -- text = text or require("ammgui._impl.component.text") -- Prevent circular import.
        -- data = { data, _isComponent = true, _backend = text.Text }
        error("todo")
    elseif type(datum) == "boolean" or type(datum) == "nil" then
        return nil, state
    end

    ---@diagnostic disable-next-line: invisible
    local backend = datum._backend
    if state and backend == state.backend then
        return backend:sync(ctx, state, datum), nil
    else
        return backend:sync(ctx, nil, datum), state
    end
end

--- Sync array of component datums with current state of the render tree.
---
--- @param ctx ammgui._impl.context.sync.Context
--- @param states ammgui._impl.backend.RenderTreeNode[]
--- @param datums ammgui.component.Any[]
--- @return ammgui._impl.backend.RenderTreeNode[] updatedStates
--- @return ammgui._impl.backend.RenderTreeNode[] deletedStates
function ns.sync(ctx, states, datums)
    local renderTreeByKey = {} --- @type table<any, ammgui._impl.backend.RenderTreeNode>
    for i, state in ipairs(states) do
        local key = state.key or i
        if renderTreeByKey[key] then
            logger:warning(
                "multiple components with the same key %s: %s, %s",
                log.pp(key), renderTreeByKey[key], state
            )
        else
            renderTreeByKey[key] = state
        end
    end

    local updatedStates = {} --- @type ammgui._impl.backend.RenderTreeNode[]
    local deletedStates = {} --- @type ammgui._impl.backend.RenderTreeNode[]

    local function syncOne(key, node)
        local updatedState, deletedState = ns.syncOne(ctx, renderTreeByKey[key], node)
        table.insert(updatedStates, updatedState)
        table.insert(deletedStates, deletedState)
        renderTreeByKey[key] = nil
    end

    local pendingString = nil
    local pendingStringKey = 0

    for _, component in ipairs(datums) do
        if type(component) == "string" then
            if pendingString then
                pendingString = pendingString .. component
            else
                pendingString = component
                pendingStringKey = #updatedStates + 1
            end
        elseif type(component) == "boolean" or type(component) == "nil" then
            -- nothing to do here.
        ---@diagnostic disable-next-line: invisible
        elseif component._isComponent then
            --- @cast component ammgui.component.Component
            if pendingString then
                syncOne(pendingStringKey, pendingString)
                pendingString = nil
            end
            syncOne(component.key or #updatedStates + 1, component)
        else
            error(string.format("not a component: %s", log.pp(component)))
        end
    end
    if pendingString then
        syncOne(pendingStringKey, pendingString)
    end
    for _, renderTree in pairs(renderTreeByKey) do
        table.insert(deletedStates, renderTree)
    end

    return updatedStates, deletedStates
end

return ns
