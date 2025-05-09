local class = require "ammcore.class"
local bootloader = require "ammcore.bootloader"
local fun = require "ammcore.fun"
local log = require "ammcore.log"

--- Functional components API.
---
--- !doctype module
--- @class ammgui.func
local ns = {}

local logger = log.Logger:New()

--- Reference to an arbitrary object. See `Hooks.useRef` for details.
---
--- @class ammgui.Ref<T>: ammcore.class.Base, { current: T }
ns.Ref = class.create("Ref")

--- !doctype classmethod
--- @generic T
--- @param initial T
--- @return ammgui.Ref<T>
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
--- @class ammgui.Context: ammcore.class.Base
ns.Context = class.create("Context")

--- @param ctx ammgui._impl.context.sync.Context
---
--- !doctype classmethod
--- @generic T: ammgui.Context
--- @param self T
--- @return T
function ns.Context:New(ctx)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui._impl.context.sync.Context
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
function ns.Context:_beforeSync()
    self._doingSync = true
    self._counter = 1
    self._stateChanged = false
end

--- @package
--- @param func function
function ns.Context:_afterSync(func)
    self._doingSync = false
    if self._prevCounter and self._counter ~= self._prevCounter then
        logger:warning(
            "Number of hooks used in this sync (%s) doesn't match number of hooks used in previous sync (%s). \n\z
            This might indicate that you're creating hooks in an if statement or in a loop; \n\z
            only create hooks at the beginning of your functional component's body. \n\z
            if you need to create hooks conditionally, split your functional component \n\z
            into smaller pieces. \n\z
            \nat %s",
            self._counter - 1,
            self._prevCounter - 1,
            bootloader.getLoc(func)
        )
    end
    self._prevCounter = self._counter
end

--- @package
function ns.Context:_runEffects()
    for _, idx in ipairs(self._outdatedEffects) do
        self._state[idx][3] = self._state[idx][2](table.unpack(self._state[idx][1]))
    end
    self._outdatedEffects = {}
end

function ns.Context:_getIdx()
    local idx = self._counter
    self._counter = self._counter + 1
    return idx
end

--- @package
function ns.Context:_cleanUpEffects()
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
function ns.Context:requestUpdate()
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
function ns.Context:useState(default)
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
function ns.Context:useReducer(default, reducer)
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
--- @return ammgui.Ref<T>
function ns.Context:useRef(initial)
    self:_checkInComponentBody()

    local idx = self:_getIdx()

    self._state[idx] = self._state[idx] or { ns.Ref:New(initial), "ref" }
    self:_checkKind(idx, "ref")

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._state[idx], 1, 1)
end

--- @param setup fun(...): fun()?
--- @param dependencies any[]?
function ns.Context:useEffect(setup, dependencies)
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
---    local logWatcher = dom.Functional(function(ctx, params)
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
---    local logWatcher = dom.Functional(function(ctx, params)
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
---    local logWatcher = dom.Functional(function(ctx, params)
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
function ns.Context:useEffectEvent(handler)
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

function ns.Context:_checkKind(idx, kind)
    local values = self._state[idx]
    if values[#values] ~= kind then
        error(string.format(
            "trying to get a %s at index %s, but on previous render %s was %s. \n\z
            This might indicate that you're creating hooks in an if statement or in a loop; \n\z
            only create hooks at the beginning of your functional component's body. \n\z
            if you need to create hooks conditionally, split your functional component \n\z
            into smaller pieces.",
            kind, idx, idx, values[idx][#values]
        ), 3)
    end
end

function ns.Context:_checkInComponentBody()
    if not self._doingSync then
        logger:warning(
            "Trying to create a hook outside of functional component's body. \n\z
            Don't pass context to sub-components or other functions; \n\z
            only create hooks at the beginning of your functional component's body. \n\z
            if you need to create hooks conditionally, split your functional component \n\z
            into smaller pieces. \n\z
            \nat %s", bootloader.getLoc(3)
        )
    end
end

function ns.Context:_checkNotInComponentBody()
    if self._doingSync then
        logger:warning(
            "Trying to request an update from functional component's body might cause \n\z
            frequent re-renders and performance issues. Don't update hook values from \n\z
            functional component's body. If they depend on component's parameters, \n\z
            they should be computed from scratch on each render, or passed from outside. \n\z
            If you have a state that doesn't affect DOM rendering, or you need to cache \n\z
            values and update them from component's body, save them in a ref instead (see 'useRef'). \n\z
            If you need to update refs from event handlers or callbacks, call 'requestUpdate' \n\z
            to manually trigger DOM refresh.",
            "\nat %s", bootloader.getLoc(3)
        )
    end
end

--- Public API for components.
---
--- Component implementations can potentially change, so you shouldn't rely on them.
--- Instead, we used this wrapper that provides stable API to the user.
---
--- @class ammgui.NodeApi: ammcore.class.Base
ns.NodeApi = class.create("NodeApi")

--- @param component ammgui._impl.component.component.Component
---
--- !doctype classmethod
--- @generic T: ammgui.NodeApi
--- @param self T
--- @return T
function ns.NodeApi:New(component)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui._impl.component.component.Component
    self._component = component

    return self
end

--- Set inline styles defined for this component.
---
--- This CSS rule takes precedence over what was defined
--- in `ammgui.dom.NodeParams.style`, but does not override anything.
---
--- @param inline ammgui.css.rule.Rule
function ns.NodeApi:setInlineCss(inline)
    return self._component:setInlineDynamicCss(inline)
end

--- @return ammgui._impl.layout.blockBase.BlockBase?
function ns.NodeApi:_getBlockLayout()
    if not self._component.layout:isInline() then
        return self._component.layout:asBlock()
    else
        return nil
    end
end

--- Get calculated size of the component's border box, not including overflow.
---
--- @return ammgui.Vec2
function ns.NodeApi:getBorderBoxSize()
    local layout = self:_getBlockLayout()
    return layout and layout.usedLayout.resolvedBorderBoxSize or Vec2:New( 0, 0 )
end

--- Get calculated size of the component's content box, not including overflow.
---
--- @return ammgui.Vec2
function ns.NodeApi:getContentSize()
    local layout = self:_getBlockLayout()
    return layout and layout.usedLayout.resolvedContentSize or Vec2:New( 0, 0 )
end

--- Get calculated minimum size of the component's border box.
---
--- This function returns resolved values for ``minWidth`` and ``minHeight``.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return ammgui.Vec2
function ns.NodeApi:getBorderBoxMinSize()
    return self:getContentMinSize() + self:getBorderBoxSize() - self:getContentSize()
end

--- Get calculated minimum size of the component's content box.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return ammgui.Vec2
function ns.NodeApi:getContentMinSize()
    local layout = self:_getBlockLayout()
    return Vec2:New(
        layout and layout.horizontalLayout.resolvedContentMinSize or 0,
        layout and layout.verticalLayout.resolvedContentMinSize or 0
    )
end

--- Get calculated maximum size of the component's border box.
---
--- This function returns resolved values for ``maxWidth`` and ``maxHeight``.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return ammgui.Vec2
function ns.NodeApi:getBorderBoxMaxSize()
    return self:getContentMaxSize() + self:getBorderBoxSize() - self:getContentSize()
end

--- Get calculated maximum size of the component's content box.
---
--- For inline components, returns ``(0, 0)``.
---
--- @return ammgui.Vec2
function ns.NodeApi:getContentMaxSize()
    local layout = self:_getBlockLayout()
    return Vec2:New(
        layout and layout.horizontalLayout.resolvedContentMaxSize or 0,
        layout and layout.verticalLayout.resolvedContentMaxSize or 0
    )
end

--- Base class for canvas implementations.
---
--- Canvas inherits from an event listener. It will be registered automatically
--- before it is drawn, you don't need to call
--- `~ammgui.component.context.RenderingContext.pushEventListener` yourself.
---
--- If your canvas pushes additional event listeners, make sure that their parent
--- is set to be the canvas itself, and that their ``isActive`` method returns
--- whatever `CanvasBase.isActive` returns.
---
--- @class ammgui.CanvasBase: ammcore.class.Base
ns.CanvasBase = class.create("CanvasBase")

--- This function is called before each render.
---
--- You can do any necessary preparations before drawing here. Most notably,
--- you can measure any strings that you intend to draw using the provided
--- text measuring service.
---
--- !doc virtual
--- @param params any data that was passed to the ``<canvas>`` element.
--- @param textMeasure ammgui._impl.context.textMeasure.TextMeasure text measuring service.
function ns.CanvasBase:prepareLayout(params, textMeasure)
end

--- Called to draw the canvas content.
---
--- !doc abstract
--- @param params any data that was passed to the ``<canvas>`` element.
--- @param ctx ammgui._impl.context.render.Context rendering context.
--- @param size ammgui.Vec2 canvas size.
--- @param parentEventListener ammgui._impl.eventListener.EventListener canvas' event listener.
function ns.CanvasBase:draw(params, ctx, size, parentEventListener)
    error("not implemented")
end

--- Canvas implementation used for the ``<canvas>`` node.
---
--- @class ammgui.CanvasFunctional: ammgui.CanvasBase
ns.CanvasFunctional = class.create("CanvasFunctional", ns.CanvasBase)

function ns.CanvasFunctional:prepareLayout(params, textMeasure)
    if params.onPrepareLayout then
        self._prepared = { params.onPrepareLayout(params.data, textMeasure) }
    else
        self._prepared = {}
    end
end

function ns.CanvasFunctional:draw(params, ctx, size, parentEventListener)
    if params.onDraw then
        params.onDraw(params.data, ctx.gpu, size, table.unpack(self._prepared))
    end
end

return ns
