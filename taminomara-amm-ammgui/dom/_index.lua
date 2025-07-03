local node = require "ammgui._impl.component.node"
local func = require "ammgui._impl.component.func"
local list = require "ammgui._impl.component.list"
local fun = require "ammcore.fun"
-- local canvas = require "ammgui.component.block.canvas"
local bootloader = require "ammcore.bootloader"
local class      = require "ammcore.class"
local canvas     = require "ammgui._impl.component.canvas"
local api        = require "ammgui.api"

--- Lightweight DOM structure.
---
--- AmmGui uses react-like shadow DOM approach. Nodes declared in this file are simple
--- lightweight tables containing settings for an associated `~ammgui.component`.
---
--- On each rendering cycle, we compare settings from these DOM nodes to settings
--- currently assigned to each node's `~ammgui.component`. If settings have changed,
--- we know that we need to recalculate CSS and layout. Otherwise, we can use
--- previously calculated layout to speed up rendering process.
---
--- !doctype module
--- @class ammgui.dom
local ns = {}

--- Base class for parameters accepted by functional components.
---
--- See `Functional`.
---
--- @class ammgui.dom.FunctionalParams: ammgui.dom.BaseNodeParams

--- Base class for parameters accepted by functional components that can have children.
---
--- See `Functional`.
---
--- @class ammgui.dom.FunctionalParamsWithChildren: ammgui.dom.FunctionalParams, ammgui.dom.ListParams

--- A DOM node for a functional component.
---
--- See `Functional`.
---
--- @class ammgui.dom.FunctionalNode: ammgui.dom.BaseNode
--- @field package _id {}
--- @field package _func fun(ctx: ammgui.Context, params: ammgui.dom.FunctionalParams): ammgui.dom.Node
--- @field package _params ammgui.dom.FunctionalParams
--- @field package _memo boolean
--- @field package _children ammgui.dom.ListNode

--- Create a functional component.
---
--- Functional components are a way to separate GUI pages into independent blocks.
---
--- Each functional component consists of a single function that produces DOM nodes.
--- When used, you pass parameters for this function; AmmGui then checks
--- if these parameters had changed since the last interface update, and, if they did,
--- invokes the component's function to generate an updated DOM.
---
--- .. warning::
---
---    Functional component's result is cached. To ensure proper cache invalidation,
---    functional components should be pure. That is, their result should only depend
---    on the input parameters; it should stay the same as long as parameters
---    stay the same.
---
---    Follow these rules to ensure that your component is pure:
---
---    - never modify ``params`` or any value within it:
---
---      .. code-block:: lua
---
---         local greeting = dom.Functional(function(ctx, params)
---             -- 🚫 Modifying `params`.
---             params.name = params.name or "mysterious person" -- 🔴 modification is not allowed.
---
---             -- ✅ Creating a new variable.
---             name = params.name or "mysterious person"
---         end)
---
---    - if you've instantiated a functional component, don't modify its parameters
---      afterwards:
---
---      .. code-block:: lua
---
---         -- 🚫 Modifying `params` after a functional component was instantiated.
---         local greetingParams = { name = "Alice" }
---         local greetingNode1 = greeting(greetingParams)
---         greetingParams.name = "Bob" -- 🔴 modification is not allowed.
---         local greetingNode2 = greeting(greetingParams)
---
---         -- ✅ Creating a new table for every functional component instantiation:
---         local greetingNode1 = greeting { name = "Alice" }
---         local greetingNode2 = greeting { name = "Bob" }
---
---    - don't modify DOM nodes that were passed to other functions, or were returned
---      from other functions:
---
---      .. code-block:: lua
---
---         -- 🚫 Modifying a node that was returned from somewhere else.
---         local node = someFunctionThatReturnsANode()
---         node.ref = ctx:useRef() -- 🔴 modification is not allowed.
---
---         -- ✅ Wrapping a node without modifying it.
---         local node = dom.list {
---             ref = ctx:useRef(),
---             someFunctionThatReturnsANode()
---         }
---
---         -- 🚫 Modifying a node that you've created after passing it somewhere.
---         local text = dom.text { "Hello!" }
---         local div1 = dom.div { text }
---         text[1] = "Goodbye." -- 🔴 modification is not allowed.
---         local div2 = dom.div { text }
---
---         -- ✅ Modifying a node that you've created before using it somewhere else.
---         local div = dom.div {}
---         for _, item in ipairs(array) do
---             table.insert(div, dom.text { item })
---         end
---
---         -- 🚫 Modifying a node that you've created after returning it.
---         local greeting = dom.Functional(function(ctx, params)
---             local heading = dom.h1 { "Hello, ", params.name or "world", "!" }
---             local button = dom.button {
---                 onClick = function() -- 🔴 `onClick` will run after `return`...
---                     table.insert(heading, " clicked!") -- 🔴 ...therefore modification is not allowed.
---                 end
---                 "Click me!"
---             }
---
---             return dom.div { heading, button }
---         end)
---
---         -- ✅ Using functional context to modify state.
---         local greeting = dom.Functional(function(ctx, params)
---             local clicked, setClicked = ctx:useState(false)
---
---             local heading = dom.h1 { "Hello, ", params.name or "world", "!" }
---             if clicked then
---                 -- 🟢 `heading` was created by us, we can modify it before returning
---                 -- or passing it to another function.
---                 table.insert(heading, " clicked!")
---             end
---
---             local button = dom.button {
---                 onClick = function()
---                     setClicked(true) -- 🟢 using a special mutator returned from `useState`.
---                 end
---                 "Click me!"
---             }
---
---             return dom.div { heading, button }
---         end)
---
--- **Example:**
---
--- Let's create a simple component that greets a user:
---
--- .. code-block:: lua
---
---    local greeting = dom.Functional(function(ctx, params)
---        return dom.h1 { "Hello, ", params.name or "world", "!" }
---    end)
---
--- We can now reuse this component elsewhere:
---
--- .. code-block:: lua
---
---    -- This is a simple block-level DOM node:
---    local greetingNode = greeting { name = "stranger" }
---
---    -- We can nest it, like any other node:
---    local div = dom.div { greetingNode }
---
--- **Example: using keys with functional components**
---
--- We can always use ``key`` and ``ref`` properties when using
--- a functional component. Their values will not be passed
--- to the component's function.
---
--- Here, we make a list of two ``greeting`` nodes. To make sure
--- that the list can be properly synchronized regardless of the order of greetings,
--- we add keys to our nodes.
---
--- .. code-block:: lua
---
---    local multipleGreetings = dom.Functional(function(ctx, params)
---        return dom.list {
---            greeting { key = "alice", name = "Alice" },
---            greeting { key = "bob", name = "Bob" },
---        }
---    end)
---
--- **Example: functional component with body**
---
--- We can make functional components that accept other nodes as parameters,
--- and use them in their body.
---
--- For example, let's make a component that displays an admonition.
--- We will accept an array of block nodes as admonition's body. We will also
--- accept an optional parameter ``title``.
---
--- To extract nodes from parameters and group them into a single node,
--- we will use a helper function called `list`.
---
--- .. code-block:: lua
---
---    local admonition = dom.Functional(function(ctx, params)
---        return dom.div {
---            class = "admonition",
---            dom.h1 { params.title or "Note" },
---            dom.list(params),
---        }
---    end)
---
--- We can now use our ``admonition`` component like so:
---
--- .. code-block:: lua
---
---    admonition {
---        title = "Warning",
---        dom.p { "This is admonition's body." }
---        dom.p { "We can pass multiple nodes here." }
---        dom.p { "All of them will end up in a list." }
---    }
---
--- Note that every node passed in as a child will be wrapped into a special
--- wrapper node. This allows AmmGui to track where the children came from,
--- and optimize DOM synchronization.
---
--- .. tip::
---
---    To get better type inference with Lua Language Server, declare component's
---    implementation as a separate function, and annotate its parameter types.
---    To further improve things, you can split ``params`` annotation into
---    a separate class inherited from `ammgui.dom.FunctionalParams`
---    or `ammgui.dom.FunctionalParamsWithChildren`:
---
---    .. code-block:: lua
---
---       --- @class _GreetingParams: ammgui.dom.FunctionalParams
---       --- @field name string
---
---       --- Implementation for the `greeting` component.
---       --- @param ctx ammgui.dom.Context
---       --- @param params _GreetingParams
---       local function _greeting(ctx, params)
---           return dom.h1 { "Hello, ", params.name, "!" }
---       end
---
---       --- The component itself.
---       local greeting = dom.Functional(_greeting)
---
---    With these annotations, Lua Language Server will not allow calling ``greeting``
---    without ``name``:
---
---    .. code-block:: lua
---
---       local node = greeting {} --> error: Missing required fields
---                                --> in type `_GreetingParams`: `name`.
---
--- @generic T: ammgui.dom.FunctionalParams
--- @param cb fun(ctx: ammgui.Context, params: T): ammgui.dom.AnyNode component's implementation.
--- @return fun(params: T): ammgui.dom.FunctionalNode component new functional component.
function ns.Functional(cb)
    local id = {} -- Unique identifier for the component.
    return function(params)
        params = fun.t.copy(params)
        local key = params["key"]
        params["key"] = nil
        local ref = params["ref"]
        params["ref"] = nil

        local children = ns.list {}
        for i, v in ipairs(params) do
            table.insert(children, toNode({ v, key = v.key }, func.Children))
            params[i] = nil
        end

        return toNode(
            {
                _func = cb,
                _params = params,
                _id = id,
                _memo = false,
                _children = children,
                key = key,
                ref = ref,
            },
            func.Functional
        ) --[[ @as ammgui.dom.FunctionalNode ]]
    end
end

--- @generic T: ammgui.dom.FunctionalParams
--- @param cb fun(params: T): ammgui.dom.FunctionalNode component implementation.
--- @return fun(params: T): ammgui.dom.FunctionalNode memoized version of component implementation.
function ns.Memo(cb)
    return function(params)
        return fun.t.update(cb(params), { _memo = true })
    end
end

--- Canvas DOM node.
---
--- See `Canvas` and `canvas`.
---
--- @class ammgui.dom.CanvasNode: ammgui.dom.Node
--- @field _factory fun(...): ammgui.CanvasBase
--- @field _args any[]

--- Create a canvas component.
---
--- Canvas components allow implementing elements that require custom drawing.
---
--- Pass in a function that creates instances of `ammgui.CanvasBase`,
--- and any arguments for this function to create a new component. When this component
--- is used, AmmGui will call your function to create an instance
--- of `~ammgui.CanvasBase`, then use this instance during rendering.
---
--- .. tip::
---
---    Use `canvas` for simple elements that don't require advanced logic.
---
--- .. warning:: Unstable API
---
---    This function allows interacting with implementation details of AmmGui.
---    Their APIs are unstable and can change in the future.
---
--- @param factory fun(...): ammgui.CanvasBase canvas factory.
--- @param ... any arguments for canvas factory.
--- @return fun(params: ammgui.dom.NodeParams): ammgui.dom.CanvasNode component new canvas component.
function ns.Canvas(factory, ...)
    local args = { ... }
    return function(params)
        params["_factory"] = factory
        params["_args"] = args
        return toNode(params, canvas.Canvas, "canvas") --[[ @as ammgui.dom.CanvasNode ]]
    end
end

--- Parameters for `canvas` node.
---
--- See `canvas`.
---
--- @class ammgui.dom.CanvasParams: ammgui.dom.NodeParams
--- @field onPrepareLayout? fun(textMeasure: ammgui._impl.context.textMeasure.TextMeasure): ... Callback invoked to prepare for drawing.
--- @field onDraw fun(gpu: FINComputerGPUT2, size: ammgui.Vec2, ...) Callback invoked to draw canvas contents.

--- @class ammgui._CanvasFunctional: ammgui.CanvasBase
local _CanvasFunctional = class.create("_CanvasFunctional", api.CanvasBase)

--- @param data ammgui.dom.CanvasNode | ammgui.dom.CanvasParams
function _CanvasFunctional:onMount(data)
    self._onPrepareLayout = data.onPrepareLayout
    self._onDraw = data.onDraw
end

--- @param data ammgui.dom.CanvasNode | ammgui.dom.CanvasParams
function _CanvasFunctional:onUpdate(data)
    if self._onPrepareLayout ~= data.onPrepareLayout then
        self._prepared = nil
    end

    self._onPrepareLayout = data.onPrepareLayout
    self._onDraw = data.onDraw
end

function _CanvasFunctional:prepareLayout(textMeasure)
    if not self._prepared then
        if self._onPrepareLayout then
            self._prepared = { self._onPrepareLayout(textMeasure) }
        else
            self._prepared = {}
        end
    end
end

function _CanvasFunctional:draw(ctx, size)
    self._onDraw(ctx.gpu, size, table.unpack(self._prepared))
end

local canvasFunctional = ns.Canvas(_CanvasFunctional.New, _CanvasFunctional)

--- Create a canvas node.
---
--- This is a simplified version of `Canvas`. It accepts two parameters:
---
--- - ``onPrepareLayout``: a callback that's invoked during layout preparation stage.
---
---   It takes a text measuring service as a single parameter
---   (see `ammgui._impl.context.textMeasure.TextMeasure`).
---
---   It can return an arbitrary number of values that will be passed on ``onDraw``;
---
--- - ``onDraw``: a callback that's invoked during an interface redraw.
---
---   It takes two parameters; first is ``gpu``, second is canvas size.
---
---   Additionally, anything returned from ``onPrepareLayout`` will be passed as third
---   parameter.
---
--- **Example:**
---
--- In this example, we implement the simples canvas possible: it simply draws
--- a single rectangle.
---
--- .. code-block:: lua
---
---    local canvas = ns.canvas {
---        onDraw = function (gpu, size)
---            gpu:drawRect(
---                Vec2:New(0, 0),
---                size,
---                structs.Color { 1, 0.7, 0.7, 1 },
---                "",
---                0
---            )
---        end
---    }
---
--- @param params ammgui.dom.CanvasParams canvas callbacks and parameters.
--- @return ammgui.dom.CanvasNode node new node.
function ns.canvas(params)
    return canvasFunctional(params)
end

return ns
