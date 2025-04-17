local bdom = require "ammgui.dom.block"
local idom = require "ammgui.dom.inline"
local p = require "ammgui.component.block.p"
local div = require "ammgui.component.block.div"
local flex = require "ammgui.component.block.flex"
local func = require "ammgui.component.block.func"
local span = require "ammgui.component.inline.span"
local list = require "ammgui.component.block.list"
local ilist = require "ammgui.component.inline.list"
local scrollbox = require "ammgui.component.block.scrollbox"

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

--- Insert key into the given node in-place.
---
--- This function modifies a node by adding a key. It returns the same node
--- to enable method chaining.
---
--- This is useful when you don't have control over how a node is created,
--- but need to modify it.
---
--- **Example:**
---
--- Here, we get nodes from a function ``formatRecipe``, and we need to insert it into
--- an array. To make sure that elements are properly synchronized regardless
--- of their order, we add keys to them:
---
--- .. code-block:: lua
---
---    function formatRecipes(recipes)
---        local div = dom.div { class="recipe-list" }
---        for _, recipe in ipairs(recipes) do
---            table.insert(
---                div,
---                dom.withKey(
---                    recipe.internalName,
---                    formatRecipe(recipe)
---                )
---            )
---        end
---        return div
---    end
---
--- @overload fun(key: any, node: ammgui.dom.block.Node): ammgui.dom.block.Node
--- @overload fun(key: any, node: ammgui.dom.inline.Node): ammgui.dom.inline.Node
function ns.withKey(key, node)
    node.key = key
    return node
end

--- @class ammgui.dom.ListNode: ammgui.dom.block.Node
--- @field nodes ammgui.dom.block.Node[] List contents.
--- @field class nil
--- @field style nil
--- @field ref nil
--- @field onMouseEnter nil
--- @field onMouseMove nil
--- @field onMouseExit nil
--- @field onMouseDown nil
--- @field onMouseUp nil
--- @field onClick nil
--- @field onRightClick nil
--- @field onMouseWheel nil
--- @field dragTarget nil
--- @field isDraggable nil
--- @field onDragStart nil
--- @field onDrag nil
--- @field onDragEnd nil

--- Concatenate an array of block-level nodes into a single node.
---
--- This utility is helpful when you need to return multiple nodes from a function,
--- but don't want to wrap them into a ``<div>``.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    function tabSet()
---        return dom.list {
---            dom.text { class = "tab", "Tab 1" },
---            dom.text { class = "tab", "Tab 2" },
---            dom.text { class = "tab", "Tab 3" },
---        }
---    end
---
--- @param nodes ammgui.dom.block.Node[]
--- @return ammgui.dom.ListNode
function ns.list(nodes)
    return bdom.paramsToNode({ nodes = nodes }, list.List) --[[ @as ammgui.dom.ListNode ]]
end

--- @class ammgui.dom.TextParams: ammgui.dom.block.NodeParams
--- @field style? ammgui.css.rule.BlockProperties CSS styles applicable for this element.
--- @field [integer] string | ammgui.dom.inline.Node Paragraph contents.

--- @class ammgui.dom.TextNode: ammgui.dom.TextParams, ammgui.dom.block.Node

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
--- @param params ammgui.dom.TextParams
--- @return ammgui.dom.TextNode
function ns.p(params)
    return bdom.paramsToNode(params, p.P) --[[ @as ammgui.dom.TextNode ]]
end

--- Create an ``<text>`` node.
---
--- This node works exactly like `p`, but it isn't styled by theme CSS.
--- It is useful when you need to add text content, but don't need margins
--- of the `p` node.
---
--- The only reason `text` exists in AmmGui is because you can't mix inline
--- and block elements, and thus can't add strings directly to `div`
--- and other blocks.
---
--- @param params ammgui.dom.TextParams
--- @return ammgui.dom.TextNode
function ns.text(params)
    return bdom.paramsToNode(params, p.Text) --[[ @as ammgui.dom.TextNode ]]
end

--- Create an ``<h1>`` node. See `p` for more info.
---
--- @param params ammgui.dom.TextParams
--- @return ammgui.dom.TextNode
function ns.h1(params)
    return bdom.paramsToNode(params, p.H1) --[[ @as ammgui.dom.TextNode ]]
end

--- Create an ``<h2>`` node. See `p` for more info.
---
--- @param params ammgui.dom.TextParams
--- @return ammgui.dom.TextNode
function ns.h2(params)
    return bdom.paramsToNode(params, p.H2) --[[ @as ammgui.dom.TextNode ]]
end

--- Create an ``<h3>`` node. See `p` for more info.
---
--- @param params ammgui.dom.TextParams
--- @return ammgui.dom.TextNode
function ns.h3(params)
    return bdom.paramsToNode(params, p.H3) --[[ @as ammgui.dom.TextNode ]]
end

--- Create a ``<button>`` node.
---
--- Button node works like other nodes such as `text` or `p`, except for CSS styling.
---
--- You can pass callbacks via the standard node parameters:
--- see `~ammgui.dom.block.NodeParams.onClick` and others.
---
--- @param params ammgui.dom.TextParams
--- @return ammgui.dom.TextNode
function ns.button(params)
    return bdom.paramsToNode(params, p.Button) --[[ @as ammgui.dom.TextNode ]]
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
--- @param params ammgui.dom.TextParams
--- @return ammgui.dom.TextNode
function ns.figcaption(params)
    return bdom.paramsToNode(params, p.FigCaption) --[[ @as ammgui.dom.TextNode ]]
end

--- @class ammgui.dom.DivParams: ammgui.dom.block.NodeParams
--- @field style? ammgui.css.rule.BlockProperties CSS styles applicable for this element.
--- @field [integer] ammgui.dom.block.Node Div contents.

--- @class ammgui.dom.DivNode: ammgui.dom.DivParams, ammgui.dom.block.Node

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
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.div(params)
    return bdom.paramsToNode(params, div.Div) --[[ @as ammgui.dom.DivNode ]]
end

--- Create a ``<header>`` node. See `div` for more info.
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.header(params)
    return bdom.paramsToNode(params, div.Header) --[[ @as ammgui.dom.DivNode ]]
end

--- Create a ``<footer>`` node. See `div` for more info.
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.footer(params)
    return bdom.paramsToNode(params, div.Footer) --[[ @as ammgui.dom.DivNode ]]
end

--- Create a ``<main>`` node. See `div` for more info.
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.main(params)
    return bdom.paramsToNode(params, div.Main) --[[ @as ammgui.dom.DivNode ]]
end

--- Create a ``<nav>`` node. See `div` for more info.
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.nav(params)
    return bdom.paramsToNode(params, div.Nav) --[[ @as ammgui.dom.DivNode ]]
end

--- Create a ``<search>`` node. See `div` for more info.
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.search(params)
    return bdom.paramsToNode(params, div.Search) --[[ @as ammgui.dom.DivNode ]]
end

--- Create an ``<article>`` node.
---
--- Article node is meant to contain text blocks such as headings,
--- paragraphs, sections, etc. The default theme sets up margins to separate
--- these elements; `article` trims vertical margins of the first and last
--- child elements to avoid unnecessary gaps (see `~ammgui.css.rule.Rule.marginTrim`).
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.article(params)
    return bdom.paramsToNode(params, div.Article) --[[ @as ammgui.dom.DivNode ]]
end

--- Create a ``<section>`` node.
---
--- Section node is meant to be a child of `article`. It is essentially
--- a block version of `p`: like paragraph, it defines top and bottom margins
--- to separate its siblings.
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.section(params)
    return bdom.paramsToNode(params, div.Section) --[[ @as ammgui.dom.DivNode ]]
end

--- Create a ``<blockquote>`` node.
---
--- Block quote is similar to `section`. It is used to add quotes or admonitions.
---
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.blockquote(params)
    return bdom.paramsToNode(params, div.BlockQuote) --[[ @as ammgui.dom.DivNode ]]
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
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.figure(params)
    return bdom.paramsToNode(params, div.Figure) --[[ @as ammgui.dom.DivNode ]]
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
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.details(params)
    return bdom.paramsToNode(params, div.Details) --[[ @as ammgui.dom.DivNode ]]
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
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.summary(params)
    return bdom.paramsToNode(params, div.Summary) --[[ @as ammgui.dom.DivNode ]]
end

--- @class ammgui.dom.FlexParams: ammgui.dom.block.NodeParams
--- @field style? ammgui.css.rule.FlexProperties CSS styles applicable for this element.
--- @field [integer] ammgui.dom.block.Node Flex contents.

--- @class ammgui.dom.FlexNode: ammgui.dom.FlexParams, ammgui.dom.block.Node

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
--- @param params ammgui.dom.FlexParams
--- @return ammgui.dom.FlexNode
function ns.flex(params)
    return bdom.paramsToNode(params, flex.Flex) --[[ @as ammgui.dom.FlexNode ]]
end

--- @class ammgui.dom.FlexNode: ammgui.dom.FlexParams, ammgui.dom.block.Node

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
--- @param params ammgui.dom.DivParams
--- @return ammgui.dom.DivNode
function ns.scroll(params)
    return bdom.paramsToNode(params, scrollbox.ScrollBox) --[[ @as ammgui.dom.DivNode ]]
end

--- @alias ammgui.dom.Context ammgui.component.block.func.Hooks

--- @class ammgui.dom.FunctionalNode: ammgui.dom.block.Node
--- @field package _id {}
--- @field package _func fun(ctx: ammgui.dom.Context, params: unknown): ammgui.dom.block.Node
--- @field package _params any
--- @field class nil
--- @field style nil
--- @field ref nil
--- @field onMouseEnter nil
--- @field onMouseMove nil
--- @field onMouseExit nil
--- @field onMouseDown nil
--- @field onMouseUp nil
--- @field onClick nil
--- @field onRightClick nil
--- @field onMouseWheel nil
--- @field dragTarget nil
--- @field isDraggable nil
--- @field onDragStart nil
--- @field onDrag nil
--- @field onDragEnd nil

--- Create a functional component.
---
--- Functional components are a way to separate GUI pages into independent blocks.
---
--- Each functional component consists of a single function that produces DOM nodes.
--- When used, you pass parameters for this function; AmmGui then checks
--- if these parameters had changed since the last interface update, and, if they did,
--- invokes the component's function to generate an updated DOM.
---
--- Example:
---
--- .. code-block:: lua
---
---    -- Let's create a simple component that greets a user.
---    local greeting = dom.functional(function(ctx, params)
---        return dom.h1 { "Hello, ", params.name or "world", "!" }
---    end)
---
---    -- We can now reuse this component elsewhere.
---    local app = gui.App:New(function()
---        return greeting { name = "stranger" }
---    end)
---
--- .. warning::
---
---    Functional component's result is cached. To ensure proper cache invalidation,
---    functional components should be pure. That is, their result should only depend
---    on the input parameters; it should stay the same as long as parameters
---    stay the same.
---
---    This, among other things, means that any mutable internal state
---    should be dealt with using the ``ctx`` parameter.
---
--- .. tip::
---
---    To get better type inference with Lua Language Server, declare component's
---    implementation as a separate function, and annotate its parameter types:
---
---    .. code-block:: lua
---
---       --- Implementation for the `greeting` component.
---       --- @param ctx ammgui.dom.Context
---       --- @param params { name: string? }
---       local function _greeting(ctx, params)
---           return dom.h1 { "Hello, ", params.name or "world", "!" }
---       end
---
---       --- The component itself.
---       local greeting = dom.functional(_greeting)
---
--- @generic T
--- @param cb fun(ctx: ammgui.dom.Context, params: T): ammgui.dom.block.Node
--- @return fun(params: T): ammgui.dom.FunctionalNode
function ns.functional(cb)
    local id = {} -- Unique identifier for the component.
    return function(...)
        local n = select("#", ...)
        local key, params
        if n == 1 then
            key, params = nil, select(1, ...)
        elseif n == 2 then
            key, params = select(1, ...), select(2, ...)
        else
            error(string.format("expected 1 or 2 arguments, got %s", n))
        end
        return bdom.paramsToNode(
            {
                _func = cb,
                _params = params,
                _id = id,
                key = key
            },
            func.Functional
        ) --[[ @as ammgui.dom.FunctionalNode ]]
    end
end

--- Node for `ammgui.dom.ilist`.
---
--- @class ammgui.dom.IListNode: ammgui.dom.inline.Node
--- @field nodes ammgui.dom.inline.Node[] List contents.
--- @field class nil
--- @field style nil
--- @field ref nil
--- @field onMouseEnter nil
--- @field onMouseMove nil
--- @field onMouseExit nil
--- @field onMouseDown nil
--- @field onMouseUp nil
--- @field onClick nil
--- @field onRightClick nil
--- @field onMouseWheel nil
--- @field dragTarget nil
--- @field isDraggable nil
--- @field onDragStart nil
--- @field onDrag nil
--- @field onDragEnd nil

--- Concatenate an array of inline-level nodes into a single node.
---
--- @overload fun(nodes: ammgui.dom.inline.Node[]): ammgui.dom.IListNode
--- @overload fun(key: any, nodes: ammgui.dom.inline.Node[]): ammgui.dom.IListNode
function ns.ilist(...)
    local n = select("#", ...)
    local key, nodes
    if n == 1 then
        key, nodes = nil, select(1, ...)
    elseif n == 2 then
        key, nodes = select(1, ...), select(2, ...)
    else
        error(string.format("expected 1 or 2 arguments, got %s", n))
    end
    return idom.paramsToNode({ key = key, nodes = nodes }, ilist.List) --[[ @as ammgui.dom.IListNode ]]
end

--- Parameters for `ammgui.dom.span` and alike.
---
--- @class ammgui.dom.SpanParams: ammgui.dom.inline.NodeParams
--- @field style? ammgui.css.rule.TextProperties CSS styles applicable for this element.
--- @field [integer] string String contents.

--- Node for `ammgui.dom.span` and alike.
---
--- @class ammgui.dom.SpanNode: ammgui.dom.SpanParams, ammgui.dom.inline.Node

--- Create a string with additional parameters.
---
--- This is equivalent to ``<span>`` element in HTML, except you can't nest them.
---
--- Example:
---
--- .. code-block:: lua
---
---    local span = dom.span {
---        "Hello, world!",
---        style = { size = 24, monospace = true }
---    }
---
--- @param params ammgui.dom.SpanParams string parameters.
--- @return ammgui.dom.SpanNode
function ns.span(params)
    return idom.paramsToNode(params, span.Span) --[[ @as ammgui.dom.SpanNode ]]
end

--- Create an emphasized text.
---
--- @param params ammgui.dom.SpanParams string parameters.
--- @return ammgui.dom.SpanNode
function ns.em(params)
    return idom.paramsToNode(params, span.Em) --[[ @as ammgui.dom.SpanNode ]]
end

--- Create an inline code listing.
---
--- @param params ammgui.dom.SpanParams string parameters.
--- @return ammgui.dom.SpanNode
function ns.code(params)
    return idom.paramsToNode(params, span.Code) --[[ @as ammgui.dom.SpanNode ]]
end

return ns
