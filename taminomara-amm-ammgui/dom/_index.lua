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

--- Base for DOM node parameters.
---
--- @class ammgui.dom.NodeParams
--- @field key? any Key for synchronizing arrays of nodes.
--- @field class? string | (string | false)[] Array of CSS classes.
--- @field style? ammgui.css.rule.Rule Inline CSS style for this node.
--- @field [integer] ammgui.dom.AnyNode Children.
--- @field ref? ammgui.Ref<ammgui.NodeApi?>
--- @field onMouseEnter? fun(pos: ammgui.Vec2, modifiers: integer): boolean?
--- @field onMouseMove? fun(pos: ammgui.Vec2, modifiers: integer): boolean?
--- @field onMouseExit? fun(pos: ammgui.Vec2, modifiers: integer): boolean?
--- @field onMouseDown? fun(pos: ammgui.Vec2, modifiers: integer): boolean?
--- @field onMouseUp? fun(pos: ammgui.Vec2, modifiers: integer): boolean?
--- @field onClick? fun(pos: ammgui.Vec2, modifiers: integer): boolean?
--- @field onMouseWheel? fun(pos: ammgui.Vec2, delta: number, modifiers: integer): boolean?
--- @field dragTarget? any
--- @field isDraggable? boolean
--- @field onDragStart? fun(pos: ammgui.Vec2, origin: ammgui.Vec2, modifiers: integer, target: unknown?): boolean|"normal"|"ok"|"warn"|"err"|"none"|nil
--- @field onDrag? fun(pos: ammgui.Vec2, origin: ammgui.Vec2, modifiers: integer, target: unknown?): boolean|"normal"|"ok"|"warn"|"err"|"none"|nil
--- @field onDragEnd? fun(pos: ammgui.Vec2, origin: ammgui.Vec2, modifiers: integer, target: unknown?)

--- Base for DOM nodes.
---
--- @class ammgui.dom.Node: ammgui.dom.NodeParams
--- @field package _isNode true Cookie flag present on every node, helps with downcasting from `any`.
--- @field package _component ammgui._impl.component.provider.Provider Component provider that implements this node.
--- @field package _tag string? HTML tag used for the node.

--- @alias ammgui.dom.AnyNode ammgui.dom.Node | string

--- @param params ammgui.dom.NodeParams node parameters.
--- @param tag string? HTML tag used for the node.
--- @param component ammgui._impl.component.provider.Provider component class that implements this node.
--- @return ammgui.dom.Node node node with its component set to ``component``.
local function toNode(params, component, tag)
    --- @cast params ammgui.dom.Node
    params._isNode = true
    params._component = component
    params._tag = tag
    if params.style and not params.style.loc then
        local loc = bootloader.getLoc(2)
        if not string.match(loc, "taminomara%-amm%-ammgui/component/") then
            params.style.loc = loc
        end
    end
    return params
end

--- @class ammgui.dom.ListParams
--- @field [integer] ammgui.dom.AnyNode List contents.
--- @field key? any Key for synchronizing arrays of nodes.
--- @field ref? ammgui.Ref<ammgui.NodeApi?>

--- @class ammgui.dom.ListNode: ammgui.dom.Node, ammgui.dom.ListParams

--- Concatenate an array of block-level nodes into a single node.
---
--- This utility is helpful when you need to return multiple nodes from a function,
--- but don't want to wrap them into a ``<div>``.
---
--- It can also be used to add keys or refs to an existing node.
---
--- .. tip::
---
---    Lua arrays don't work nicely with `nil` values. If you have an array
---    of ``{ 1, 2, nil, 4 }``, Lua will think that array has only two elements.
---
---    To avoid potential mistakes, prefer using `map` or functional utilities
---    from `ammcore.fun` to avoid manual table insertions.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    local tabSet = dom.Functional(function()
---        return dom.list {
---            dom.text { class = "tab", "Tab 1" },
---            dom.text { class = "tab", "Tab 2" },
---            dom.text { class = "tab", "Tab 3" },
---        }
---    end)
---
--- **Example: handling functional component's body**
---
--- Here, we create a functional component that accepts block nodes as its params
--- and wraps them in a ``div``. We use `list` to extract passed nodes
--- and group them into a single list.
---
--- .. code-block:: lua
---
---    local tab = dom.Functional(function(ctx, params)
---        return dom.div {
---            dom.h1 { params.title },
---            dom.list(params),
---        }
---    end)
---
--- We can now use our ``tab`` component like so:
---
--- .. code-block:: lua
---
---    tab {
---        title = "Tab 1",
---        dom.p { "This is tab's body." }
---        dom.p { "We can pass multiple nodes here." }
---        dom.p { "All of them will end up in a list." }
---    }
---
--- **Example: adding key to a node**
---
--- Here, we have a function ``makeDescription`` that returns a block node.
--- We need to add a key to this node, but we shouldn't modify an output
--- of another function. To avoid mutation, we wrap the node into a list.
---
--- .. code-block:: lua
---
---    local description = dom.list {
---        key = "desc",
---        makeDescription(),
---    }
---
--- Note that these situations are rare, because most AmmGui's functions
--- allow customizing keys and refs.
---
--- @param params ammgui.dom.ListParams
--- @return ammgui.dom.ListNode
function ns.list(params)
    return toNode(params --[[ @as ammgui.dom.NodeParams ]], list.List) --[[ @as ammgui.dom.ListNode ]]
end

--- A helper that applies a function to each element of an array,
--- and gathers results into a `list`.
---
--- This is a useful function that helps with building lists of nodes
--- from arrays of data.
---
--- Note that the mapper function can return `nil` to skip a node.
---
--- **Example:**
---
--- Let's suppose that you have an array of recipes, and you want to display them.
--- For each recipe, you need to create a DOM node with recipe's description,
--- then gather these nodes into a list.
---
--- The naive approach would be to iterate over recipes using a for-loop,
--- and push descriptions into an array:
---
--- .. code-block:: lua
---
---    local descriptions = dom.list {}
---    for _, recipe in ipairs(recipes) do
---        table.insert(descriptions, dom.p { recipe.name })
---    end
---
--- This code is clunky and tedious to write. Instead, we can map an array of recipes
--- using this helper:
---
--- .. code-block:: lua
---
---    local descriptions = dom.map(recipes, function(recipe)
---        return dom.p { recipe.name }
---    )
---
--- @generic T
--- @param arr T[] array to be mapped.
--- @param fn fun(x: T, i: number): ammgui.dom.AnyNode|nil mapper.
--- @return ammgui.dom.ListNode list list of nodes.
function ns.map(arr, fn)
    return ns.list(fun.a.map(arr, fn))
end

--- Create a div.
---
--- This is equivalent to the ``<div>`` element in HTML.
---
--- Accepts a table with children and node parameters:
---
--- .. code-block:: lua
---
---    local div = dom.div {
---        class = "my-element",
---
---        dom.h1 { "Hello!" },
---        dom.p { "I'm a child of this <div>." },
---    }
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.div(params)
    return toNode(params, node.Node, "div")
end

--- Create a ``<header>`` node. See `div` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.header(params)
    return toNode(params, node.Node, "header")
end

--- Create a ``<footer>`` node. See `div` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.footer(params)
    return toNode(params, node.Node, "footer")
end

--- Create a ``<main>`` node. See `div` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.main(params)
    return toNode(params, node.Node, "main")
end

--- Create a ``<nav>`` node. See `div` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.nav(params)
    return toNode(params, node.Node, "nav")
end

--- Create a ``<search>`` node. See `div` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.search(params)
    return toNode(params, node.Node, "search")
end

--- Create an ``<article>`` node.
---
--- Article node is meant to contain text blocks such as headings,
--- paragraphs, sections, etc. The default theme sets up margins to separate
--- these elements; `article` trims vertical margins of the first and last
--- child elements to avoid unnecessary gaps (see `~ammgui.css.rule.Rule.marginTrim`).
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.article(params)
    return toNode(params, node.Node, "article")
end

--- Create a ``<section>`` node.
---
--- Section node is meant to be a child of `article`. It is essentially
--- a block version of `p`: like paragraph, it defines top and bottom margins
--- to separate its siblings.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.section(params)
    return toNode(params, node.Node, "section")
end

--- Create a ``<blockquote>`` node.
---
--- Block quote is similar to `section`. It is used to add quotes or admonitions.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.blockquote(params)
    return toNode(params, node.Node, "blockquote")
end

--- Create a ``<figure>`` node.
---
--- Figure node is used to add captions to images. Place `img` and `figcaption`
--- nodes inside to get a caption that's lined up to an image.
---
--- .. tip::
---
---    Instead of manually creating nodes for figure and image,
---    use functional component `Figure`.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.figure(params)
    return toNode(params, node.Node, "figure")
end

--- Create a ``<details>`` node.
---
--- Details is used in conjuncture with `summary` to create expandable blocks.
---
--- .. tip::
---
---    By themselves, these nodes don't have any special behavior.
---    Use `Details` to create an element that expands on click.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.details(params)
    return toNode(params, node.Node, "details")
end

--- Create a ``<summary>`` node.
---
--- Summary is used in conjuncture with `details` to create expandable blocks.
---
--- .. tip::
---
---    By themselves, these nodes don't have any special behavior.
---    Use `Details` to create an element that expands on click.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.summary(params)
    return toNode(params, node.Node, "summary")
end

--- Create a paragraph.
---
--- This is equivalent to the ``<p>`` element in HTML.
---
--- Accepts a table with children and node parameters:
---
--- .. code-block:: lua
---
---    local p = dom.p { "Hello, world!" }
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.p(params)
    return toNode(params, node.Node, "p")
end

--- Create an ``<h1>`` node. See `p` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.h1(params)
    return toNode(params, node.Node, "h1")
end

--- Create an ``<h2>`` node. See `p` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.h2(params)
    return toNode(params, node.Node, "h2")
end

--- Create an ``<h3>`` node. See `p` for more info.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.h3(params)
    return toNode(params, node.Node, "h3")
end

--- Create a ``<button>`` node.
---
--- Button node works like other nodes such as `text` or `p`, except for CSS styling.
---
--- You can pass callbacks via the standard node parameters:
--- see `~ammgui.dom.NodeParams.onClick` and others.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.button(params)
    return toNode(params, node.Node, "button")
end

--- Create an ``<figcaption>`` node.
---
--- Figure caption node is used together with `figure` to add captions to images.
---
--- .. tip::
---
---    Instead of manually creating nodes for figure, image, and caption
---    use functional component `Figure`.
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.figcaption(params)
    return toNode(params, node.Node, "figcaption")
end

--- Create a flexbox.
---
--- This is equivalent to ``<div>`` element with ``display: flex`` in HTML.
---
--- Accepts a table with children and node parameters:
---
--- .. code-block:: lua
---
---    local flex = dom.flex {
---        class = "tabs",
---        dom.div {
---            class = "tab",
---            dom.text { "Tab 1" },
---        },
---        dom.div {
---            class = "tab",
---            dom.text { "Tab 2" },
---        },
---    }
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.flex(params)
    return toNode(params, node.Node, "flex")
end

--- Create a scrollbox.
---
--- This is equivalent to ``<div>`` element with ``overflow: scroll`` in HTML.
---
--- Accepts a table with children and node parameters:
---
--- .. code-block:: lua
---
---    local scroll = dom.scroll {
---        class = "my-element",
---
---        dom.h1 { "Hello!" },
---        dom.p { "I'm a child of this <scroll>." },
---    }
---
--- @param params ammgui.dom.NodeParams
--- @return ammgui.dom.Node
function ns.scroll(params)
    return toNode(params, node.Node, "scroll")
end

--- Create a string with additional parameters.
---
--- This is equivalent to ``<span>`` element in HTML, except you can't nest them.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    local span = dom.span {
---        "Hello, world!",
---        style = { size = 24, monospace = true }
---    }
---
--- @param params ammgui.dom.NodeParams string parameters.
--- @return ammgui.dom.Node
function ns.span(params)
    return toNode(params, node.Node, "span")
end

--- Create an emphasized text.
---
--- @param params ammgui.dom.NodeParams string parameters.
--- @return ammgui.dom.Node
function ns.em(params)
    return toNode(params, node.Node, "em")
end

--- Create an inline code listing.
---
--- @param params ammgui.dom.NodeParams string parameters.
--- @return ammgui.dom.Node
function ns.code(params)
    return toNode(params, node.Node, "code")
end

--- @class ammgui.dom.FunctionalParams
--- @field key? any Key for synchronizing arrays of nodes.
--- @field ref? ammgui.Ref<ammgui.NodeApi?>

--- @class ammgui.dom.FunctionalParamsWithChildren: ammgui.dom.FunctionalParams, ammgui.dom.ListParams

--- @class ammgui.dom.FunctionalNode: ammgui.dom.Node
--- @field package _id {}
--- @field package _func fun(ctx: ammgui.Context, params: unknown): ammgui.dom.Node
--- @field package _params any
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
--- @param cb fun(ctx: ammgui.Context, params: T): ammgui.dom.AnyNode
--- @return fun(params: T): ammgui.dom.FunctionalNode
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
--- .. warning::
---
---    This function allows interacting with implementation details of AmmGui.
---    Their APIs are unstable and can change in the future.
---
--- @param factory fun(...): ammgui.CanvasBase canvas factory.
--- @param ... any arguments for canvas factory.
--- @return fun(data: ammgui.dom.NodeParams): ammgui.dom.CanvasNode
function ns.Canvas(factory, ...)
    local args = { ... }
    return function(params)
        params["_factory"] = factory
        params["_args"] = args
        return toNode(params, canvas.Canvas) --[[ @as ammgui.dom.CanvasNode ]]
    end
end

--- @class ammgui.dom.CanvasParams: ammgui.dom.NodeParams
--- @field data any
--- @field onPrepareLayout? fun(data: any, textMeasure: ammgui._impl.context.textMeasure.TextMeasure): ...
--- @field onDraw fun(data: any, gpu: FINComputerGPUT2, size: ammgui.Vec2, ...)

local canvasFunctional = ns.Canvas(api.CanvasFunctional.New, api.CanvasFunctional)

--- Create a canvas node.
---
--- This is a simplified version of `Canvas`. It accepts three parameters:
---
--- - ``data``: any data that will passed to callbacks;
---
--- - ``onPrepareLayout``: a callback that's invoked during layout preparation stage.
---
---   It takes two parameters; first is ``data`` described above, second
---   is a text measuring service (see `ammgui._impl.context.textMeasure.TextMeasure`).
---
---   It can return an arbitrary number of values that will be passed on ``onDraw``;
---
--- - ``onDraw``: a callback that's invoked during an interface redraw.
---
---   It takes three parameters; first is ``data``, second is ``gpu``,
---   third is canvas size. Additionally, anything returned from ``onPrepareLayout``
---   will be passed as fourth argument.
---
--- @param params ammgui.dom.CanvasParams
--- @return ammgui.dom.CanvasNode
function ns.canvas(params)
    return canvasFunctional(params)
end

return ns
