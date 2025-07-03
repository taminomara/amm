local domBackend = require "ammgui._impl.backend.dom"
local bootloader = require "ammcore.bootloader"

--- Components that represent simple DOM nodes.
---
--- !doctype module
--- @class ammgui.component.dom
local ns = {}

--- Parameters for components that represent DOM nodes.
---
--- @class ammgui.component.dom.Params: ammgui.component.Params
--- @field class? string | (string | false)[] Array of CSS classes.
--- @field style? ammgui.css.rule.Rule Inline CSS style for this node.
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

--- Component that represents a single DOM node.
---
--- @class ammgui.component.dom.Component: ammgui.component.dom.Params, ammgui.component.Component
--- @field package _isComponent true
--- @field package _backend ammgui._impl.backend.dom.DomComponent

--- Parameters for components that represent DOM nodes with children.
---
--- @class ammgui.component.dom.ContainerParams: ammgui.component.dom.Params
--- @field [integer] ammgui.component.Any Children.

--- Component that represents a single DOM node with children.
---
--- @class ammgui.component.dom.ContainerComponent: ammgui.component.dom.ContainerParams, ammgui.component.dom.Component
--- @field package _isComponent true
--- @field package _backend ammgui._impl.backend.dom.DomComponent

--- @param params ammgui.component.dom.ContainerParams
--- @param component ammgui._impl.backend.dom.DomComponent
--- @return ammgui.component.dom.ContainerComponent
local function toContainerNode(params, component)
    --- @cast params ammgui.component.dom.ContainerComponent
    params._isComponent = true
    params._backend = component
    if params.style and not params.style.loc then
        local loc = bootloader.getLoc(2)
        if not string.match(loc, "taminomara%-amm%-ammgui/component/") then
            params.style.loc = loc
        end
    end
    return params
end

local divBackend = domBackend.DomComponent:New("div")

--- Create a ``<div>`` node.
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
--- .. warning::
---
---    You shouldn't modify or reuse node parameters after passing them
---    to a node constructor.
---
---    .. code-block:: lua
---
---       -- 🚫 Modifying `params` after a node was instantiated.
---       local headingParams = { "Hello, world!" }
---       local headingNode1 = dom.h1(headingParams)
---       headingParams[1] = "Hi, world!" -- 🔴 modification is not allowed.
---       local headingNode2 = dom.h1(headingParams)
---
---       -- ✅ Creating a new table for every node instantiation:
---       local headingNode1 = dom.h1 { "Hello, world!" }
---       local headingNode2 = dom.h1 { "Hi, world!" }
---
--- @param params ammgui.component.dom.ContainerParams node parameters.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.div(params)
    return toContainerNode(params, divBackend)
end

local headerBackend = domBackend.DomComponent:New("header")

--- Create a ``<header>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.header(params)
    return toContainerNode(params, headerBackend)
end

local footerBackend = domBackend.DomComponent:New("footer")

--- Create a ``<footer>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.footer(params)
    return toContainerNode(params, footerBackend)
end

local mainBackend = domBackend.DomComponent:New("main")

--- Create a ``<main>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.main(params)
    return toContainerNode(params, mainBackend)
end

local navBackend = domBackend.DomComponent:New("nav")

--- Create a ``<nav>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.nav(params)
    return toContainerNode(params, navBackend)
end

local searchBackend = domBackend.DomComponent:New("search")

--- Create a ``<search>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.search(params)
    return toContainerNode(params, searchBackend)
end

local articleBackend = domBackend.DomComponent:New("article")

--- Create an ``<article>`` node.
---
--- Article node is meant to contain text blocks such as headings,
--- paragraphs, sections, etc. The default theme sets up margins to separate
--- these elements; `article` trims vertical margins of the first and last
--- child elements to avoid unnecessary gaps (see `~ammgui.css.rule.Rule.marginTrim`).
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.article(params)
    return toContainerNode(params, articleBackend)
end

local sectionBackend = domBackend.DomComponent:New("section")

--- Create a ``<section>`` node.
---
--- Section node is meant to be a child of `article`. It is essentially
--- a block version of `p`: like paragraph, it defines top and bottom margins
--- to separate its siblings.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.section(params)
    return toContainerNode(params, sectionBackend)
end

local blockquoteBackend = domBackend.DomComponent:New("blockquote")

--- Create a ``<blockquote>`` node.
---
--- Block quote is similar to `section`. It is used to add quotes or admonitions.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.blockquote(params)
    return toContainerNode(params, blockquoteBackend)
end

local figureBackend = domBackend.DomComponent:New("figure")

--- Create a ``<figure>`` node.
---
--- Figure node is used to add captions to images. Place `img` and `figcaption`
--- nodes inside to get a caption that's lined up to an image.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.figure(params)
    return toContainerNode(params, figureBackend)
end

local detailsBackend = domBackend.DomComponent:New("details")

--- Create a ``<details>`` node.
---
--- Details is used in conjuncture with `summary` to create expandable blocks.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.details(params)
    return toContainerNode(params, detailsBackend)
end

local summaryBackend = domBackend.DomComponent:New("summary")

--- Create a ``<summary>`` node.
---
--- Summary is used in conjuncture with `details` to create expandable blocks.
---
--- .. tip::
---
---    By themselves, these nodes don't have any special behavior.
---    Use `Details` to create an element that expands on click.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.summary(params)
    return toContainerNode(params, summaryBackend)
end

local pBackend = domBackend.DomComponent:New("p")

--- Create a paragraph.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.p(params)
    return toContainerNode(params, pBackend)
end

local h1Backend = domBackend.DomComponent:New("h1")

--- Create an ``<h1>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.h1(params)
    return toContainerNode(params, h1Backend)
end

local h2Backend = domBackend.DomComponent:New("h2")

--- Create an ``<h2>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.h2(params)
    return toContainerNode(params, h2Backend)
end

local h3Backend = domBackend.DomComponent:New("h3")

--- Create an ``<h3>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.h3(params)
    return toContainerNode(params, h3Backend)
end

local buttonBackend = domBackend.DomComponent:New("button")

--- Create a ``<button>`` node.
---
--- You can pass callbacks via the standard node parameters:
--- see `~ammgui.dom.NodeParams.onClick` and others.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.button(params)
    return toContainerNode(params, buttonBackend)
end

local figcaptionBackend = domBackend.DomComponent:New("figcaption")

--- Create a ``<figcaption>`` node.
---
--- Figure caption node is used together with `figure` to add captions to images.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.figcaption(params)
    return toContainerNode(params, figcaptionBackend)
end

local spanBackend = domBackend.DomComponent:New("span")

--- Create a ``<span>`` node.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.span(params)
    return toContainerNode(params, spanBackend)
end

local smallBackend = domBackend.DomComponent:New("small")

--- Create a ``<small>`` node for a small text.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.small(params)
    return toContainerNode(params, smallBackend)
end

local emBackend = domBackend.DomComponent:New("em")

--- Create a ``<em>`` node for an emphasized text.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.em(params)
    return toContainerNode(params, emBackend)
end

local dimBackend = domBackend.DomComponent:New("dim")

--- Create a ``<dim>`` node for a dim text.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.dim(params)
    return toContainerNode(params, dimBackend)
end

local strongBackend = domBackend.DomComponent:New("strong")

--- Create a ``<em>`` node for a strongly emphasized text.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.strong(params)
    return toContainerNode(params, strongBackend)
end

local codeBackend = domBackend.DomComponent:New("code")

--- Create a ``<code>`` node for an inline code listing.
---
--- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
--- @return ammgui.component.dom.ContainerComponent node new node.
function ns.code(params)
    return toContainerNode(params, codeBackend)
end

-- local canvasBackend = domBackend.NodeComponent:New("canvas", {})
-- --- Create a ``<code>`` node for an inline code listing.
-- ---
-- --- @param params ammgui.component.dom.ContainerParams node parameters. See `div` for usage example.
-- --- @return ammgui.component.dom.ContainerComponent node new node.
-- function ns.canvas(params)
--     return toContainerNode(params, codeBackend)
-- end

return ns
