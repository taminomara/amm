---@diagnostic disable: invisible

local class = require "ammcore.class"
local log = require "ammcore.log"
local list = require "ammgui.component.list"
local bootloader = require "ammcore.bootloader"
local fun = require "ammcore.fun"
local base = require "ammgui.component.base"

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

local function evalDefault(default)
    if type(default) == "function" then
        return default()
    else
        return default
    end
end

--- Hooks provider for functional components.
---
--- @class ammgui.component.block.func.Hooks: ammcore.class.Base
ns.Hooks = class.create("Hooks")

--- @param ctx ammgui.component.context.SyncContext
---
--- !doctype classmethod
--- @generic T: ammgui.component.block.func.Hooks
--- @param self T
--- @return T
function ns.Hooks:New(ctx)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui.component.context.SyncContext
    self._context = ctx

    --- @private
    --- @type table<string | number, any>
    self._state = {}

    --- @package
    --- @type integer
    self._counter = 1

    --- @private
    --- @type integer?
    self._prevCounter = nil

    --- @package
    --- @type boolean
    self._stateChanged = true

    --- @package
    --- @type boolean
    self._doingSync = false

    --- @private
    --- @type integer[]
    self._outdatedEffects = {}

    return self
end

--- @package
function ns.Hooks:_beforeSync()
    self._doingSync = true
    self._counter = 1
    self._stateChanged = false
end

--- @package
--- @param func function
function ns.Hooks:_afterSync(func)
    self._doingSync = false
    if self._prevCounter and self._counter ~= self._prevCounter then
        logger:warning(
            "Number of hooks used in this sync (%s) doesn't match number of hooks used in previous sync (%s)." ..
            "This might indicate that you're creating hooks in an if statement or in a loop; " ..
            "only create hooks at the beginning of your functional component's body. " ..
            "if you need to create hooks conditionally, split your functional component " ..
            "into smaller pieces." ..
            "\nat %s",
            self._counter - 1,
            self._prevCounter - 1,
            bootloader.getLoc(func)
        )
    end
    self._prevCounter = self._counter
end

--- @package
function ns.Hooks:_runEffects()
    for _, idx in ipairs(self._outdatedEffects) do
        self._state[idx][3] = self._state[idx][2](table.unpack(self._state[idx][1]))
    end
    self._outdatedEffects = {}
end

function ns.Hooks:_getIdx()
    local idx = self._counter
    self._counter = self._counter + 1
    return idx
end

--- @package
function ns.Hooks:_cleanUpEffects()
    for i = #self._state, 1, -1 do
        local state = self._state[i]
        if state[#state] == "effect" and state[3] then
            state[3]()
        end
    end
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
    self._context:requestEarlyRefresh()
end

--- Use a stateful hook.
---
--- Returns a value and a function to update it. Calling update function causes
--- regeneration of the DOM and an interface update.
---
--- @generic T
--- @param default T | fun(): T default value for the state.
--- @return T value current state value.
--- @return fun(v: T | fun(current: T): T) function to update state value.
function ns.Hooks:useState(default)
    self:_checkInComponentBody()

    local idx = self:_getIdx()

    self._state[idx] = self._state[idx] or {
        evalDefault(default),
        function(value)
            self:_checkNotInComponentBody()
            self._state[idx][1] = value
            self:requestUpdate()
        end,
        "state",
    }
    self:_checkKind(idx, "state")

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._state[idx], 1, 2)
end

--- Use a reducer hook.
---
--- Similar to `useState`, but instead of setting new value directly,
--- this function will call ``reducer`` with old value and passed arguments,
--- and set new value to whatever the reducer returns.
---
--- @generic T
--- @param default T | fun(): T default value for the state.
--- @param reducer fun(t: T, ...): T state reducer.
--- @return T value current state value.
--- @return fun(...) function to update state value.
function ns.Hooks:useReducer(default, reducer)
    self:_checkInComponentBody()

    local idx = self:_getIdx()

    self._state[idx] = self._state[idx] or {
        evalDefault(default),
        function(...)
            self:_checkNotInComponentBody()
            self._state[idx][1] = reducer(
                self._state[idx][1],
                ...
            )
            self:requestUpdate()
        end,
        "reducer",
    }
    self:_checkKind(idx, "reducer")

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._state[idx], 1, 2)
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
    self:_checkInComponentBody()

    local idx = self:_getIdx()

    self._state[idx] = self._state[idx] or { ns.Ref:New(initial), "ref" }
    self:_checkKind(idx, "ref")

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._state[idx], 1, 1)
end

--- @param setup fun(...): fun()?
--- @param dependencies any[]?
function ns.Hooks:useEffect(setup, dependencies)
    self:_checkInComponentBody()

    local idx = self:_getIdx()

    self._state[idx] = self._state[idx] or { false, false, false, "effect" }
    self:_checkKind(idx, "effect")

    if not dependencies or not self._state[idx][1] or not fun.t.eq(self._state[idx][1], dependencies) then
        table.insert(self._outdatedEffects, idx)
        self._state[idx][1] = dependencies or {}
        self._state[idx][2] = setup
    end
end

--- Use an event hook.
---
--- This hook allows updating a callback without having to pass a new callback
--- to external system.
---
--- For example, let's say that you initialize an external system using
--- the `useEffect` hook, and you need to pass a callback to it:
---
--- .. code-block:: lua
---
---    local logWatcher = dom.functional(function(ctx, params)
---        cts:useEffect(
---            function()
---                -- We initialize a hypothetical system that tracks computer's log.
---                initializeLogWatcher {
---                    -- We pass a callback that decides if a log record
---                    -- should be displayed based on record's verbosity
---                    -- and given parameters.
---                    filter = function(record)
---                        return record.verbosity >= params.verbosity
---                    end
---                }
---            end,
---            -- Since we use `params.verbosity` in effect's body, we need to add it
---            -- to the list of effect's dependencies. This way, when `params.verbosity`
---            -- changes, the effect will run again.
---            params.verbosity
---        )
---        -- ...
---    end)
---
--- What happens when ``params.verbosity`` changes? Since we've added it
--- to the effect's dependencies, the effect will run again, causing log watcher
--- to be initialized twice. We don't want this.
---
--- To fix this issue, we could remove ``params.verbosity`` from effect's dependencies:
---
--- .. code-block:: lua
---
---    local logWatcher = dom.functional(function(ctx, params)
---        cts:useEffect(
---            function()
---                initializeLogWatcher {
---                    filter = function(record)
---                        return record.verbosity >= params.verbosity
---                    end
---                }
---            end
---            -- No dependencies.
---        )
---        -- ...
---    end)
---
--- This, however, will introduce another issue: when ``params.verbosity`` changes,
--- the ``filter`` callback will not be updated, and will use the old value.
---
--- To avoid this situation, we need to move our callback to an effect event:
---
--- .. code-block:: lua
---
---    local logWatcher = dom.functional(function(ctx, params)
---        local filter = ctx:useEffectEvent(function(record)
---            return record.verbosity >= params.verbosity
---        end)
---
---        cts:useEffect(
---            function()
---                initializeLogWatcher { filter = filter }
---            end
---        )
---        -- ...
---    end)
---
--- By using the `useEffectEvent` hook, we can update callback's implementation
--- without re-initializing the log watcher. Thw ``filter`` function that
--- we get from `useEffectEvent` will always run the latest callback that was used.
function ns.Hooks:useEffectEvent(handler)
    self:_checkInComponentBody()

    local idx = self:_getIdx()

    self._state[idx] = self._state[idx] or {
        function(...) return self._state[idx][2](...) end,
        handler,
        "effectEvent",
    }
    self:_checkKind(idx, "effectEvent")

    self._state[idx][2] = handler

    return table.unpack(self._state[idx], 1, 1)
end

function ns.Hooks:_checkKind(idx, kind)
    local values = self._state[idx]
    if values[#values] ~= kind then
        error(string.format(
            "trying to get a %s at index %s, but on previous render %s was %s. " ..
            "This might indicate that you're creating hooks in an if statement or in a loop; " ..
            "only create hooks at the beginning of your functional component's body. " ..
            "if you need to create hooks conditionally, split your functional component " ..
            "into smaller pieces.",
            kind, idx, idx, values[idx][#values]
        ), 3)
    end
end

function ns.Hooks:_checkInComponentBody()
    if not self._doingSync then
        logger:warning(
            "Trying to create a hook outside of functional component's body. " ..
            "Don't pass context to sub-components or other functions; " ..
            "only create hooks at the beginning of your functional component's body. " ..
            "if you need to create hooks conditionally, split your functional component " ..
            "into smaller pieces." ..
            "\nat %s", bootloader.getLoc(3)
        )
    end
end

function ns.Hooks:_checkNotInComponentBody()
    if self._doingSync then
        logger:warning(
            "Trying to request an update from functional component's body might cause " ..
            "frequent re-renders and performance issues. Don't update hook values from " ..
            "functional component's body. If they depend on component's parameters, " ..
            "they should be computed from scratch on each render, or passed from outside. " ..
            "If you have a state that doesn't affect DOM rendering, or you need to cache " ..
            "values and update them from component's body, save them in a ref instead (see 'useRef'). " ..
            "If you need to update refs from event handlers or callbacks, call 'requestUpdate' " ..
            "to manually trigger DOM refresh.",
            "\nat %s", bootloader.getLoc(3)
        )
    end
end

--- Functional component.
---
--- @class ammgui.component.block.func.Functional: ammgui.component.base.ComponentProvider
ns.Functional = class.create("Functional", base.ComponentProvider)

--- @param data ammgui.dom.FunctionalNode
function ns.Functional:onMount(ctx, data)
    self._hooks = ns.Hooks:New(ctx)
    ns.Functional.onUpdate(self, ctx, data)
end

--- @param data ammgui.dom.FunctionalNode
function ns.Functional:onUpdate(ctx, data)
    for i = 1, 5 do
        local outdated = false
        if
            not self._root
            or self._id ~= data._id
            or self._hooks._stateChanged
            or (not data._memo and ctx:isOutdated())
            or not fun.t.eq(self._params, data._params)
        then
            self._id = data._id
            self._params = data._params
            self._func = data._func

            self._hooks:_beforeSync()
            self._root = self._func(
                self._hooks,
                fun.a.extend(fun.t.copy(self._params), data._children)
            )
            self._hooks:_afterSync(self._func)

            outdated = true
        end

        ctx:pushComponent(outdated, data._children)
        self._provider = base.Component.syncOne(ctx, self._provider, self._root)
        ctx:popComponent()

        self._hooks:_runEffects()

        if not self._hooks._stateChanged then
            return
        end
    end

    error(string.format(
        "too many re-renders. AmmGui limits the number of renders " ..
        "to prevent infinite loops." ..
        "\nat %s",
        bootloader.getLoc(self._func)
    ))
end

function ns.Functional:onUnmount(ctx)
    self._provider:onUnmount(ctx)
    self._hooks:_cleanUpEffects()
end

function ns.Functional:collect(components)
    self._provider:collect(components)
end

function ns.Functional:noteRef(ref)
    self._provider:noteRef(ref)
end

--- Children of a functional component.
---
--- @class ammgui.component.block.func.Children: ammgui.component.block.list.List
ns.Children = class.create("Children", list.List)

function ns.Children:onMount(ctx, data)
    ctx:pushChildren(data)
    list.List.onMount(self, ctx, data)
    ctx:popChildren()
end

function ns.Children:onUpdate(ctx, data)
    ctx:pushChildren(data)
    list.List.onUpdate(self, ctx, data)
    ctx:popChildren()
end

return ns
