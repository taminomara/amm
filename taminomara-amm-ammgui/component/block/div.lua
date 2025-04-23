local class = require "ammcore.class"
local bcom = require "ammgui.component.block"
local fun = require "ammcore.fun"
local log = require "ammcore.log"

--- Div component.
---
--- !doctype module
--- @class ammgui.component.block.div
local ns = {}

--- Div component.
---
--- @class ammgui.component.block.div.Div: ammgui.component.block.Component
ns.Div = class.create("Div", bcom.Component)

ns.Div.elem = "div"

--- @param data ammgui.dom.DivNode
function ns.Div:onMount(ctx, data)
    bcom.Component.onMount(self, ctx, data)

    --- @private
    --- @type ammgui.component.base.ComponentProvider[]
    self._providers = nil

    --- @private
    --- @type ammgui.component.block.Component[]
    self._children = nil

    self._providers, self._children = bcom.Component.syncAll(ctx, {}, {}, data, self)
end

--- @param data ammgui.dom.DivNode
function ns.Div:onUpdate(ctx, data)
    bcom.Component.onUpdate(self, ctx, data)

    local
    providers,
    children,
    outdated,
    outdatedCss = bcom.Component.syncAll(ctx, self._providers, self._children, data, self)

    self._providers = providers
    self._children = children
    self.outdated = self.outdated or outdated
    self.outdatedCss = self.outdatedCss or outdatedCss
end

function ns.Div:propagateCssChanges(ctx)
    for _, child in ipairs(self._children) do
        child:updateCss(ctx)
        self.outdated = self.outdated or child.outdated
    end
end

function ns.Div:prepareLayout(textMeasure)
    bcom.Component.prepareLayout(self, textMeasure)
    for _, child in ipairs(self._children) do
        if child.outdated then
            child:prepareLayout(textMeasure)
        end
    end
end

function ns.Div:calculateIntrinsicContentWidth()
    local minContentWidth, maxContentWidth = 0, 0

    for _, child in ipairs(self._children) do
        local childMinOuterWidth, childMaxOuterWidth = child:getExtrinsicOuterWidth()
        minContentWidth = math.max(minContentWidth, childMinOuterWidth)
        maxContentWidth = math.max(maxContentWidth, childMaxOuterWidth)
    end

    return minContentWidth, maxContentWidth, false
end

function ns.Div:calculateContentLayout(availableWidth, availableHeight)
    local trimTopMargin = self.css.marginTrim == "block" or self.css.marginTrim == "block-start"
    local trimBottomMargin = self.css.marginTrim == "block" or self.css.marginTrim == "block-end"

    local canCollapseTopMargin =
        self.baseLayout.paddingTop == 0
        and self.baseLayout.outlineWidth == 0
        and self.css.overflow == "visible"
    local canCollapseBottomMargin =
        self.baseLayout.paddingBottom == 0
        and self.baseLayout.outlineWidth == 0
        and self.css.overflow == "visible"
    local collapsedMarginTop, collapsedMarginBottom = nil, nil

    local maxContentWidth, maxActualContentWidth = 0, 0
    local currentY, maxActualContentHeight = 0, 0

    self._childPositions = {}

    local previousChildMarginBottom = 0

    for i, child in ipairs(self._children) do
        local childLayoutData = child:getLayout(availableWidth, availableHeight)

        if i > 1 then
            if previousChildMarginBottom > 0 and childLayoutData.effectiveVerticalMargin.x > 0 then
                currentY = currentY + math.max(
                    previousChildMarginBottom,
                    childLayoutData.effectiveVerticalMargin.x
                )
            elseif previousChildMarginBottom < 0 and childLayoutData.effectiveVerticalMargin.x < 0 then
                currentY = currentY + math.min(
                    previousChildMarginBottom,
                    childLayoutData.effectiveVerticalMargin.x
                )
            else
                currentY = currentY + previousChildMarginBottom + childLayoutData.effectiveVerticalMargin.x
            end
        elseif not trimTopMargin then
            if canCollapseTopMargin then
                collapsedMarginTop = childLayoutData.collapsedMarginTop
            else
                currentY = currentY + childLayoutData.effectiveVerticalMargin.x
            end
        end

        local contentOffset = child.usedLayout.contentPosition.y
        local firstBaselineOffset = child.textLayout.firstBaselineOffset or child.textLayout.lastBaselineOffset
        local lastBaselineOffset = child.textLayout.lastBaselineOffset or child.textLayout.firstBaselineOffset

        if firstBaselineOffset and not self.textLayout.firstBaselineOffset then
            self.textLayout.firstBaselineOffset =
                currentY + contentOffset + firstBaselineOffset
        end
        if lastBaselineOffset then
            self.textLayout.lastBaselineOffset =
                currentY + contentOffset + lastBaselineOffset
        end

        self._childPositions[child] = structs.Vector2D {
            childLayoutData.effectiveHorizontalMargin.x,
            currentY,
        }

        maxActualContentHeight = math.max(
            maxActualContentHeight, currentY + childLayoutData.visibleBorderBoxSize.y
        )
        currentY = currentY + childLayoutData.resolvedBorderBoxSize.y

        maxContentWidth = math.max(
            maxContentWidth,
            childLayoutData.effectiveHorizontalMargin.x
            + childLayoutData.resolvedBorderBoxSize.x
            + childLayoutData.effectiveHorizontalMargin.y
        )
        maxActualContentWidth = math.max(
            maxActualContentWidth,
            childLayoutData.effectiveHorizontalMargin.x
            + childLayoutData.visibleBorderBoxSize.x
        )

        if i < #self._children then
            previousChildMarginBottom = childLayoutData.effectiveVerticalMargin.y
        elseif not trimBottomMargin then
            if canCollapseBottomMargin then
                collapsedMarginBottom = childLayoutData.collapsedMarginBottom
            else
                currentY = currentY + childLayoutData.effectiveVerticalMargin.y
            end
        end
    end

    return
        structs.Vector2D { maxContentWidth, currentY },
        structs.Vector2D { maxActualContentWidth, maxActualContentHeight },
        collapsedMarginTop,
        collapsedMarginBottom
end

function ns.Div:draw(ctx, contentPosition)
    bcom.Component.draw(self, ctx)

    local position = contentPosition or self.usedLayout.contentPosition
    for _, child in ipairs(self._children) do
        local visible = ctx:pushLayout(
            position + self._childPositions[child],
            child.usedLayout.visibleBorderBoxSize,
            child.css.overflow == "hidden"
        )
        if visible then
            child:draw(ctx)
        end
        ctx:popLayout()
    end
end

function ns.Div:reprChildren()
    return fun.a.map(self._children, function(x) return x:repr() end)
end

--- Implements a ``<body>`` element.
---
--- @class ammgui.component.block.div.Body: ammgui.component.block.div.Div
ns.Body = class.create("Body", ns.Div)

ns.Body.elem = "body"

--- Implements a ``<header>`` element.
---
--- @class ammgui.component.block.div.Header: ammgui.component.block.div.Div
ns.Header = class.create("Header", ns.Div)

ns.Header.elem = "header"

--- Implements a ``<footer>`` element.
---
--- @class ammgui.component.block.div.Footer: ammgui.component.block.div.Div
ns.Footer = class.create("Footer", ns.Div)

ns.Footer.elem = "footer"

--- Implements a ``<main>`` element.
---
--- @class ammgui.component.block.div.Main: ammgui.component.block.div.Div
ns.Main = class.create("Main", ns.Div)

ns.Main.elem = "main"

--- Implements a ``<nav>`` element.
---
--- @class ammgui.component.block.div.Nav: ammgui.component.block.div.Div
ns.Nav = class.create("Nav", ns.Div)

ns.Nav.elem = "nav"

--- Implements a ``<search>`` element.
---
--- @class ammgui.component.block.div.Search: ammgui.component.block.div.Div
ns.Search = class.create("Search", ns.Div)

ns.Search.elem = "search"

--- Implements a ``<article>`` element.
---
--- @class ammgui.component.block.div.Article: ammgui.component.block.div.Div
ns.Article = class.create("Article", ns.Div)

ns.Article.elem = "article"

--- Implements a ``<section>`` element.
---
--- @class ammgui.component.block.div.Section: ammgui.component.block.div.Div
ns.Section = class.create("Section", ns.Div)

ns.Section.elem = "section"

--- Implements a ``<blockquote>`` element.
---
--- @class ammgui.component.block.div.BlockQuote: ammgui.component.block.div.Div
ns.BlockQuote = class.create("BlockQuote", ns.Div)

ns.BlockQuote.elem = "blockquote"

--- Implements a ``<figure>`` element.
---
--- @class ammgui.component.block.div.Figure: ammgui.component.block.div.Div
ns.Figure = class.create("Figure", ns.Div)

ns.Figure.elem = "figure"

--- Implements a ``<details>`` element.
---
--- @class ammgui.component.block.div.Details: ammgui.component.block.div.Div
ns.Details = class.create("Details", ns.Div)

ns.Details.elem = "details"

--- Implements a ``<summary>`` element.
---
--- @class ammgui.component.block.div.Summary: ammgui.component.block.div.Div
ns.Summary = class.create("Summary", ns.Div)

ns.Summary.elem = "summary"

--- Implements a ``<p>`` element.
---
--- @class ammgui.component.block.div.P: ammgui.component.block.div.Div
ns.P = class.create("P", ns.Div)

ns.P.elem = "p"

--- Implements a ``<h1>`` element.
---
--- @class ammgui.component.block.div.H1: ammgui.component.block.div.Div
ns.H1 = class.create("H1", ns.Div)

ns.H1.elem = "h1"

--- Implements a ``<h2>`` element.
---
--- @class ammgui.component.block.div.H2: ammgui.component.block.div.Div
ns.H2 = class.create("H2", ns.Div)

ns.H2.elem = "h2"

--- Implements a ``<h3>`` element.
---
--- @class ammgui.component.block.div.H3: ammgui.component.block.div.Div
ns.H3 = class.create("H3", ns.Div)

ns.H3.elem = "h3"

--- Implements a ``<button>`` element.
---
--- @class ammgui.component.block.div.Button: ammgui.component.block.div.Div
ns.Button = class.create("Button", ns.Div)

ns.Button.elem = "button"

--- Implements a ``<figcaption>`` element.
---
--- @class ammgui.component.block.div.FigCaption: ammgui.component.block.div.Div
ns.FigCaption = class.create("FigCaption", ns.Div)

ns.FigCaption.elem = "figcaption"

return ns
