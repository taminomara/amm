local class = require "ammcore.class"
local fun = require "ammcore.fun"
local tracy = require "ammcore.tracy"

--- Layout calculation algorithms.
---
--- This module contains implementations for layout engines. It's general structure
--- mirrors the one of components:
---
--- .. code-block:: text
---
---    Layout
---     |
---     +-- Text
---     |
---     +-- BlockBase
---          |
---          +-- TextBox
---          |
---          +-- Node
---               |
---               +-- Block
---               |
---               +-- Flex
---               |
---              ...
---
--- !doctype module
--- @class ammgui._impl.layout
local ns = {}

--- Base class for layout calculation.
---
--- Layout can be performed in two modes (a.k.a. flows): inline and block
--- (AmmGui treats other flows like flex or grid as variants of block).
---
--- In inline flow, the layout algorithm should split a node into inline elements
--- and return them to be further handled by textbox. When an element with
--- ``display`` other than ``inline`` is laid out in inline mode, it is wrapped
--- into a special element that behaves like ``inline-block``.
---
--- In block flow, the layout algorithm should determine size of the node,
--- and calculate positions of its children. To do so, it must first collect
--- all inline children into text boxes. Inline elements should never be laid out
--- in block flow.
---
--- @class ammgui._impl.layout.Layout: ammcore.class.Base
ns.Layout = class.create("Layout")

--- @param css ammgui._impl.css.resolved.Resolved
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.Layout
--- @param self T
--- @return T
function ns.Layout:New(css)
    self = class.Base.New(self)

    --- Currently used CSS settings for this element.
    ---
    --- @type ammgui._impl.css.resolved.Resolved
    self.css = css

    return self
end

--- Set new CSS styles.
---
--- This function should be called when CSS styles change, but layout wasn't affected.
---
--- @param css ammgui._impl.css.resolved.Resolved
function ns.Layout:updateCss(css)
    self.css = css
end

--- Prepare for layout calculation.
---
--- !doc virtual
--- @param textMeasure ammgui._impl.context.textMeasure.TextMeasure
function ns.Layout:prepareLayout(textMeasure)
    -- nothing to do here
end

--- Check whether this is an inline or a block element.
---
--- Returns `true` for text fragments and nodes with ``display: inline``
--- and ``inline-block``.
---
--- @return boolean
function ns.Layout:isInline()
    error("not implemented")
end

--- Get inline elements.
---
--- This function always returns, regardless of `isInline` result.
---
--- @return ammgui._impl.layout.Element[]
function ns.Layout:asInline()
    error("not implemented")
end

--- Get block layout implementation for this engine.
---
--- If `isInline` returns `false`, this function can throw an error.
---
--- @return ammgui._impl.layout.blockBase.BlockBase
function ns.Layout:asBlock()
    error("not implemented")
end

--- Helper for drawing container's background and margins.
---
--- @param ctx ammgui._impl.context.render.Context
--- @param position ammgui.Vec2
--- @param size ammgui.Vec2
--- @param backgroundColor Color
--- @param outlineWidth number
--- @param outlineTint Color
--- @param outlineRadius number
--- @param hasOutlineLeft boolean?
--- @param hasOutlineRight boolean?
function ns.Layout.drawContainer(
    ctx,
    position,
    size,
    backgroundColor,
    outlineWidth,
    outlineTint,
    outlineRadius,
    hasOutlineLeft,
    hasOutlineRight
)
    local _ <close> = tracy.zoneScopedN("AmmGui/DrawContainer")

    if
        backgroundColor.a == 0
        and (outlineTint.a == 0 or outlineWidth == 0)
    then
        return
    end

    if hasOutlineLeft == nil then
        hasOutlineLeft = true
    end
    if hasOutlineRight == nil then
        hasOutlineRight = true
    end

    ctx.gpu:pushClipRect(position, size)

    local dp = Vec2:New(0, 0)
    local ds = Vec2:New(0, 0)

    if not hasOutlineLeft then
        dp = dp - Vec2:New(2 * outlineWidth, 0)
        ds = ds + Vec2:New(2 * outlineWidth, 0)
    end
    if not hasOutlineRight then
        ds = ds + Vec2:New(2 * outlineWidth, 0)
    end

    do
        local _ <close> = tracy.zoneScopedN("AmmGui/DrawContainer/DrawBox")

        ctx.gpu:drawBox {
            position = position + dp,
            size = size + ds,
            rotation = 0,
            color = backgroundColor,
            image = "",
            imageSize = Vec2:New(0, 0),
            hasCenteredOrigin = false,
            horizontalTiling = false,
            verticalTiling = false,
            isBorder = false,
            margin = { top = 0, right = 0, bottom = 0, left = 0 },
            isRounded = true,
            radii = structs.Vector4 {
                hasOutlineLeft and outlineRadius or 0,
                hasOutlineRight and outlineRadius or 0,
                hasOutlineRight and outlineRadius or 0,
                hasOutlineLeft and outlineRadius or 0,
            },
            hasOutline = true,
            outlineThickness = outlineWidth,
            outlineColor = outlineTint,
        }
    end

    ctx.gpu:popClip()
end

--- Helper for drawing debug overlay.
---
--- @param ctx ammgui._impl.context.render.Context
--- @param pos ammgui.Vec2
--- @param size ammgui.Vec2
--- @param holePos ammgui.Vec2
--- @param holeSize ammgui.Vec2
--- @param color Color
function ns.Layout.drawRectangleWithHole(ctx, pos, size, holePos, holeSize, color)
    ctx.gpu:drawRect(
        pos,
        Vec2:New(size.x, holePos.y - pos.y),
        color,
        "",
        0
    )
    ctx.gpu:drawRect(
        Vec2:New(pos.x, holePos.y + holeSize.y),
        Vec2:New(size.x, size.y - holeSize.y - (holePos.y - pos.y)),
        color,
        "",
        0
    )
    ctx.gpu:drawRect(
        Vec2:New(pos.x, holePos.y),
        Vec2:New(holePos.x - pos.x, holeSize.y),
        color,
        "",
        0
    )
    ctx.gpu:drawRect(
        Vec2:New(holePos.x + holeSize.x, holePos.y),
        Vec2:New(size.x - holeSize.x - (holePos.x - pos.x), holeSize.y),
        color,
        "",
        0
    )
end

--- Data about margins, paddings and outlines of a ``<span>`` element.
---
--- @class ammgui._impl.layout.ElementBoxData
--- @field isStart boolean indicates that this is a start of a ``<span>``.
--- @field isEnd boolean indicates that this is an end of a ``<span>``.
--- @field parent ammgui._impl.layout.Layout span or text that created this box data.
--- @field nodeEventListener ammgui._impl.eventListener.EventListener? event listener attached to the parent node.

--- Data about margins, paddings and outlines of a ``<span>`` element,
--- resolved by textbox.
---
--- @class ammgui._impl.layout.ResolvedElementBoxData
--- @field isStart boolean indicates that this is a start of a ``<span>``.
--- @field isEnd boolean indicates that this is an end of a ``<span>``.
--- @field parent ammgui._impl.layout.Layout span or text that created this box data.
--- @field nodeEventListener ammgui._impl.eventListener.EventListener?
--- @field outlineWidth number
--- @field paddingTop number
--- @field paddingRight number
--- @field paddingBottom number
--- @field paddingLeft number
--- @field marginLeft number
--- @field marginRight number
--- @field outlineRadius number

--- A single non-breaking element of a text.
---
--- When something is rendered inline, it is first broken into elements, then those
--- elements are wrapped into lines and displayed. In general, we have three kinds
--- of elements:
---
--- - text fragments, those represent a single non-breakable word;
--- - block elements, they wrap nodes that have ``display`` other than ``inline``
---   or ``inline-block``, whenever these nodes are rendered in an inline context;
--- - inline-block elements, they wrap nodes that have ``display: inline-block``.
---
--- @class ammgui._impl.layout.Element: ammcore.class.Base
ns.Element = class.create("Element")

--- @param parent ammgui._impl.layout.Layout
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.Element
--- @param self T
--- @return T
function ns.Element:New(parent)
    self = class.Base.New(self)

    --- Span or text fragment that created this element.
    ---
    --- @type ammgui._impl.layout.Layout
    self.parent = parent

    --- Data about all ``<span>`` elements that wrap this text element.
    ---
    --- Used to calculate distance between elements and properly draw all backgrounds
    --- and outlines.
    ---
    --- @type ammgui._impl.layout.ElementBoxData[]
    self.boxData = {}

    --- Box data resolved and cached by textbox.
    ---
    --- This value is mutated by textbox. It is always reset
    --- when textbox runs layout algorithm.
    ---
    --- @type ammgui._impl.layout.ResolvedElementBoxData[]
    self.resolvedBoxData = nil

    --- Resolved total left margin, includes all left outlines, paddings, and margins
    --- from `resolvedBoxData`.
    ---
    --- @type number?
    self.totalLeftMargin = nil

    --- Resolved height above the baseline.
    ---
    --- @type number?
    self.resolvedHeightA = nil

    --- Resolved height below the baseline.
    ---
    --- @type number?
    self.resolvedHeightB = nil

    --- Resolved total right margin, includes all right outlines, paddings, and margins
    --- from `resolvedBoxData`.
    ---
    --- @type number?
    self.totalRightMargin = nil

    --- Resolved total element width, includes resolved total left and right margins,
    --- plus element's own width.
    ---
    --- @type number?
    self.totalWidth = nil

    --- Set to `true` by textbox if this element appears in the beginning of a span.
    ---
    --- @type boolean
    self.hasStarts = false

    --- Set to `true` by textbox if this element appears in the end of a span.
    ---
    --- @type boolean
    self.hasEnds = false

    --- @protected
    --- @type integer?
    self._cachedFontSize = nil

    --- @protected
    --- @type [number, number]?
    self._cachedIntrinsicWidth = nil

    --- @protected
    --- @type [number | false, number | false]?
    self._cachedSizeParams = nil

    --- @protected
    --- @type [number, number, number]?
    self._cachedSize = nil

    --- @protected
    --- @type [number, number]?
    self._cachedAdjustedHeight = nil

    return self
end

--- Pre-calculate dimensions of a text fragment.
---
--- Note that this function is called from ``textbox``, not from ``text``.
---
--- !doc virtual
--- @param textMeasure ammgui._impl.context.textMeasure.TextMeasure
function ns.Element:prepareLayout(textMeasure)
    -- nothing to do here.
end

--- Returns a light proxy for the element with a new box data added
--- to the `boxData` stack.
---
--- @param boxData ammgui._impl.layout.ElementBoxData
--- @return ammgui._impl.layout.Element
function ns.Element:withBoxData(boxData)
    local wrapper = self:withCopiedBoxData()
    table.insert(wrapper.boxData, boxData)
    return wrapper
end

--- Returns a light proxy for the element with box data array copied.
---
--- This function is used when nodes and textbox mutates box data.
---
--- @return ammgui._impl.layout.Element
function ns.Element:withCopiedBoxData()
    --- @type { __originalTextElement: ammgui._impl.layout.Element }
    local originalElement = self
    while originalElement.__originalTextElement do
        originalElement = originalElement.__originalTextElement
    end
    return setmetatable(
        { boxData = fun.a.copy(self.boxData), __originalTextElement = originalElement },
        { __index = originalElement, __newindex = originalElement }
    )
end

--- Return element's size in points.
---
--- @return integer size element's text size.
function ns.Element:getFontSize()
    if not self._cachedFontSize then
        local size = table.unpack(self.parent.css.fontSize) * 400 / 726
        self._cachedFontSize = math.max(math.floor(size + 0.5), 1)
    end

    return self._cachedFontSize
end

--- Calculate height of this element adjusted for line height.
---
--- @param availableWidth number? available content width.
--- @param availableHeight number? available content height.
--- @return number aboveBaseLine height that this element extends above the base line.
--- @return number belowBaseLine height that this element extends below the base line.
function ns.Element:calculateAdjustedHeight(availableWidth, availableHeight)
    local _, heightA, heightB = self:getContentSize(availableWidth, availableHeight)
    local lineHeight, unit = table.unpack(self.parent.css.lineHeight)
    if unit == "" then
        lineHeight = lineHeight * (heightA + heightB)
    end
    local leading = (lineHeight - heightA - heightB) / 2
    return heightA + leading, heightB + leading
end

--- Get or recalculate cached result of `calculateAdjustedHeight`.
---
--- @param availableWidth number? available content width.
--- @param availableHeight number? available content height.
--- @return number aboveBaseLine height that this element extends above the base line.
--- @return number belowBaseLine height that this element extends below the base line.
function ns.Element:getAdjustedHeight(availableWidth, availableHeight)
    local sizeParams = { availableWidth or false, availableHeight or false }
    if not self._cachedAdjustedHeight or not fun.a.eq(sizeParams, self._cachedSizeParams) then
        self._cachedAdjustedHeight = { self:calculateAdjustedHeight(availableWidth, availableHeight) }
    end

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._cachedAdjustedHeight)
end

--- Calculate intrinsic width of this element.
---
--- !doc abstract
--- @return number minContentWidth content width in min-content mode.
--- @return number maxContentWidth content width in max-content mode.
function ns.Element:calculateIntrinsicContentWidth()
    error("not implemented")
end

--- Get or recalculate cached result of `calculateIntrinsicContentWidth`.
---
--- @return number minContentWidth content width in min-content mode.
--- @return number maxContentWidth content width in max-content mode.
function ns.Element:getIntrinsicContentWidth()
    if not self._cachedIntrinsicWidth then
        self._cachedIntrinsicWidth = { self:calculateIntrinsicContentWidth() }
    end

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._cachedIntrinsicWidth)
end

--- Calculate content size of the element.
---
--- !doc abstract
--- @param availableWidth number? available content width.
--- @param availableHeight number? available content height.
--- @return number contentWidth content width of this element.
--- @return number aboveBaseLine height that this element extends above the base line.
--- @return number belowBaseLine height that this element extends below the base line.
function ns.Element:calculateContentSize(availableWidth, availableHeight)
    error("not implemented")
end

--- Get or recalculate cached result of `calculateSize`.
---
--- !doc abstract
--- @param availableWidth number? available content width.
--- @param availableHeight number? available content height.
--- @return number contentWidth content width of this element.
--- @return number aboveBaseLine height that this element extends above the base line.
--- @return number belowBaseLine height that this element extends below the base line.
function ns.Element:getContentSize(availableWidth, availableHeight)
    local sizeParams = { availableWidth or false, availableHeight or false }
    if not self._cachedSize or not fun.a.eq(sizeParams, self._cachedSizeParams) then
        self._cachedSize = { self:calculateContentSize(availableWidth, availableHeight) }
    end

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._cachedSize)
end

--- Indicates that this element acts like a white space, and can be skipped
--- when wrapping text.
---
--- Note that all line breaks should return `false` here, because we can't collapse them.
---
--- !doc virtual
--- @return boolean canCollapse can be removed from the text when wrapping it.
function ns.Element:canCollapse()
    return false
end

--- Indicates that this element is already collapsed.
---
--- !doc virtual
--- @return boolean isCollapsed this element is collapsed.
function ns.Element:isCollapsed()
    return false
end

--- Indicates that this element serves as a line break. This element will be skipped.
---
--- !doc virtual
--- @return boolean isLineBreak a line break should not be rendered.
function ns.Element:isLineBreak()
    return false
end

--- Render this element.
---
--- !doc virtual
--- @param ctx ammgui._impl.context.render.Context
function ns.Element:draw(ctx)
    -- local width, uHeightA, uHeightB = table.unpack(self._cachedSize)
    -- local heightA, heightB = table.unpack(self._cachedAdjustedHeight)

    -- local paddingPos = Vec2:New( self.paddingLeft, uHeightA - heightA + self.paddingTop )
    -- local paddingSize = Vec2:New(
    --     width + self.paddingLeft + self.paddingRight,
    --     heightA + heightB + self.paddingTop + self.paddingBottom,
    -- )

    -- ctx:pushEventListener(paddingPos, paddingSize, self.parent)
    -- ctx:noteDebugTarget(self, self.parent.id)
end

---
---
--- @class ammgui._impl.layout._index.ElementDebugTarget: ammcore.class.Base, ammgui._impl.context.render.SupportsDebugOverlay
ns.ElementDebugTarget = class.create("ElementDebugTarget")

--- @param element ammgui._impl.layout.Element
--- @param size ammgui.Vec2
--- @param resolvedBoxData ammgui._impl.layout.ResolvedElementBoxData
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout._index.ElementDebugTarget
--- @param self T
--- @return T
function ns.ElementDebugTarget:New(element, size, resolvedBoxData)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui._impl.layout.Element
    self._element = element

    --- @private
    --- @type ammgui.Vec2
    self._size = size

    --- @private
    --- @type ammgui._impl.layout.ResolvedElementBoxData
    self._resolvedBoxData = resolvedBoxData

    return self
end

--- Render debug overlay for an element.
---
--- @param ctx ammgui._impl.context.render.Context
--- @param drawContent boolean
--- @param drawPadding boolean
--- @param drawOutline boolean
--- @param drawMargin boolean
function ns.ElementDebugTarget:drawDebugOverlay(ctx, drawContent, drawPadding, drawOutline, drawMargin)
    local outlineWidthLeft = self._resolvedBoxData.isStart and self._resolvedBoxData.outlineWidth or 0
    local outlineWidthRight = self._resolvedBoxData.isEnd and self._resolvedBoxData.outlineWidth or 0

    local contentPos = Vec2:New(
        self._resolvedBoxData.paddingLeft + outlineWidthLeft,
        self._resolvedBoxData.paddingTop + self._resolvedBoxData.outlineWidth
    )
    local contentSize = self._size - Vec2:New(
        outlineWidthLeft + self._resolvedBoxData.paddingLeft + self._resolvedBoxData.paddingRight + outlineWidthRight,
        self._resolvedBoxData.paddingTop + self._resolvedBoxData.paddingBottom + 2 * self._resolvedBoxData.outlineWidth
    )

    -- Content.
    if drawContent then
        ctx.gpu:drawRect(
            contentPos,
            contentSize,
            structs.Color { 0x54 / 0xff, 0xA9 / 0xff, 0xCE / 0xff, 0.5 },
            "",
            0
        )
        ctx.gpu:drawLines(
            {
                contentPos + Vec2:New(0, self._element.resolvedHeightA),
                contentPos + Vec2:New(contentSize.x, self._element.resolvedHeightA),
            },
            1,
            structs.Color { 0x54 / 0xff, 0xA9 / 0xff, 0xCE / 0xff, 1 }
        )
    end

    local paddingPos = contentPos - Vec2:New(self._resolvedBoxData.paddingLeft, self._resolvedBoxData.paddingTop)
    local paddingSize = contentSize + Vec2:New(
        self._resolvedBoxData.paddingLeft + self._resolvedBoxData.paddingRight,
        self._resolvedBoxData.paddingTop + self._resolvedBoxData.paddingBottom
    )

    -- Padding.
    if drawPadding then
        ns.Layout.drawRectangleWithHole(
            ctx,
            paddingPos,
            paddingSize,
            contentPos,
            contentSize,
            structs.Color { 0xA4 / 0xff, 0xA0 / 0xff, 0xC6 / 0xff, 0.5 }
        )
    end

    local outlinePos = paddingPos - Vec2:New(outlineWidthLeft, self._resolvedBoxData.outlineWidth)
    local outlineSize = paddingSize + Vec2:New(
        outlineWidthLeft + outlineWidthRight,
        2 * self._resolvedBoxData.outlineWidth
    )

    -- Outline
    if drawOutline then
        ns.Layout.drawRectangleWithHole(
            ctx,
            outlinePos,
            outlineSize,
            paddingPos,
            paddingSize,
            structs.Color { 0xC9 / 0xff, 0x85 / 0xff, 0x31 / 0xff, 0.5 }
        )
    end

    local marginLeft = math.max(self._resolvedBoxData.marginLeft, 0)
    local marginRight = math.max(self._resolvedBoxData.marginRight, 0)

    local marginPos = outlinePos - Vec2:New(marginLeft, 0)
    local marginSize = outlineSize + Vec2:New(marginLeft + marginRight, 0)

    -- Margin
    if drawMargin then
        ns.Layout.drawRectangleWithHole(
            ctx,
            marginPos,
            marginSize,
            outlinePos,
            outlineSize,
            structs.Color { 0xEC / 0xff, 0x8F / 0xff, 0x82 / 0xff, 0.5 }
        )
    end
end

return ns
