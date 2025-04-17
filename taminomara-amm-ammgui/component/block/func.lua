---@diagnostic disable: invisible
local class = require "ammcore.class"
local bcom = require "ammgui.component.block"
local array = require "ammcore._util.array"
local log = require "ammcore.log"
local defer = require "ammcore.defer"
local list = require "ammgui.component.block.list"

--- Functional component.
---
--- !doctype module
--- @class ammgui.component.block.func
local ns = {}

local logger = log.Logger:New()

--- Reference to an arbitrary object. See `Hooks.useRef` for details.
---
--- @class ammgui.component.block.func.Ref<T>: ammcore.class.Base, { current: T }
ns.Ref = class.create("Ref")

--- !doctype classmethod
--- @generic T
--- @param initial T
--- @return ammgui.component.block.func.Ref<T>
function ns.Ref:New(initial)
    self = class.Base.New(self)

    --- Current referenced value.
    self.current = initial

    return self
end

--- Hooks provider for functional components.
---
--- @class ammgui.component.block.func.Hooks: ammcore.class.Base
ns.Hooks = class.create("Hooks")

--- @param ctx ammgui.component.context.RenderingContext
---
--- !doctype classmethod
--- @generic T: ammgui.component.block.func.Hooks
--- @param self T
--- @return T
function ns.Hooks:New(ctx)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui.component.context.RenderingContext
    self._context = ctx

    --- @private
    --- @type table<string | number, any>
    self._state = {}

    --- @package
    --- @type integer
    self._counter = 1

    --- @package
    --- @type boolean
    self._stateChanged = false

    --- @package
    --- @type boolean
    self._doingSync = false

    return self
end

--- @package
function ns.Hooks:_beforeSync()
    self._doingSync = true
    self._counter = 1
end

--- @package
function ns.Hooks:_afterSync()
    self._doingSync = false
    self._stateChanged = false
end

--- Request GUI update.
---
--- Upon the next interface update, AmmGui will run the functional component's code
--- again to an updated version of DOM.
---
--- Avoid using this function in the functional component's body,
--- as that may lead to perpetual updates. Prefer using other hooks,
--- such as `useState`, to manage updates for you.
function ns.Hooks:requestUpdate()
    self._stateChanged = true
    if not self._doingSync then
        self._context:requestEarlyRefresh()
    end
end

--- Use a stateful hook.
---
--- Returns a value and a function to update it. Calling update function causes
--- regeneration of the DOM and an interface update.
---
--- @generic T
--- @param default T default value for the state.
--- @return T value current state value.
--- @return fun(v: T) function to update state value.
function ns.Hooks:useState(default)
    local idx = self._counter
    self._counter = self._counter + 1

    self._state[idx] = self._state[idx] or {
        default,
        function(value)
            self._state[idx][1] = value
            self:requestUpdate()
        end,
    }

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._state[idx])
end

--- Use a reducer hook.
---
--- Similar to `useState`
---
--- @generic T
--- @param default T default value for the state.
--- @param reducer fun(t: T, ...): T state reducer.
--- @return T value current state value.
--- @return fun(...) function to update state value.
function ns.Hooks:useReducer(default, reducer)
    local idx = self._counter
    self._counter = self._counter + 1

    self._state[idx] = self._state[idx] or {
        default,
        function(...)
            self._state[idx][1] = reducer(
                self._state[idx][1],
                ...
            )
            self:requestUpdate()
        end,
    }

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._state[idx])
end

--- Use a reference hook.
---
--- This is a way to reference and store an object that does not affect render
--- between synchronizations. When you first create a reference, it will be initialized
--- with the given default value. On subsequent requests, it will contain whatever
--- value you've stored in it. Mutating referenced object does not cause re-rendering;
--- in fact, AmmGui does not track this value at all.
---
--- You can add a reference to a DOM node. Once the node is synchronized and rendered,
--- the ref object will contain a reference to the component implementing its node.
---
--- @generic T
--- @param initial T default value for the state.
--- @return ammgui.component.block.func.Ref<T>
function ns.Hooks:useRef(initial)
    local idx = self._counter
    self._counter = self._counter + 1
    self._state[idx] = self._state[idx] or { ns.Ref:New(initial) }
    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._state[idx])
end

--- Functional component.
---
--- @class ammgui.component.block.func.Functional: ammgui.component.block.ComponentProvider
ns.Functional = class.create("Functional", bcom.ComponentProvider)

--- @param data ammgui.dom.FunctionalNode
function ns.Functional:onMount(ctx, data)
    self._id = data._id
    self._params = data._params
    self._func = data._func

    self._hooks = ns.Hooks:New(ctx)

    self._hooks:_beforeSync()
    self._root = self:_makeNode()
    self._hooks:_afterSync()

    self._provider = bcom.Component.syncOne(ctx, nil, self._root)
end

--- @param ctx ammgui.component.context.RenderingContext
--- @param data ammgui.dom.FunctionalNode
function ns.Functional:onUpdate(ctx, data)
    if
        self._id ~= data._id
        or self._hooks._stateChanged
        or self._params ~= data._params
    then
        self._id = data._id
        self._params = data._params
        self._func = data._func

        self._hooks:_beforeSync()
        self._root = self:_makeNode()
        self._hooks:_afterSync()
    end

    self._provider = bcom.Component.syncOne(ctx, self._provider, self._root)
end

function ns.Functional:onUnmount(ctx)
    self._provider:onUnmount(ctx)
end

function ns.Functional:collect(components)
    self._provider:collect(components)
end

function ns.Functional:noteRef(ref)
    self._provider:noteRef(ref)
end

--- @return ammgui.dom.block.Node
function ns.Functional:_makeNode()
    local result

    local ok, err = defer.xpcall(function()
        result = self._func(self._hooks, self._params)
    end)

    if not ok then
        logger:error("Error in functional component: %s\n%s", err.message, err.trace)
        return { _isBlockNode = true, _component = list.List } -- empty list
    end

    return result
end

return ns
