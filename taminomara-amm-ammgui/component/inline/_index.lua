local class = require "ammcore.class"
local log = require "ammcore.log"
local base = require "ammgui.component.base"
local fun = require "ammcore.fun"

--- Components that implement inline DOM nodes.
---
--- !doctype module
--- @class ammgui.component.inline
local ns = {}

local logger = log.Logger:New()

--- An inline component of a text paragraph.
---
--- @class ammgui.component.inline.Component: ammgui.component.base.Component
ns.Component = class.create("Component", base.Component)

--- Name of a DOM node that corresponds to this component.
---
--- @type string
ns.Component.elem = nil

--- Split this node into an array of render-able elements.
---
--- @return ammgui.component.inline.Element[]
function ns.Component:calculateElements()
    error("not implemented")
end

--- Get or recalculate cached result of `calculateElements`.
---
--- Calling this function will reset `outdated` status.
---
--- @return ammgui.component.inline.Element[]
function ns.Component:getElements()
    if not self._elementsCache then
        self._elementsCache = self:calculateElements()
    end
    self.outdated = false
    return self._elementsCache
end

function ns.Component:propagateCssChanges(ctx)
    if self._elementsCache then
        for _, element in ipairs(self._elementsCache) do
            element.css = self.css
        end
    end
end

--- A single non-breaking element of a text.
---
--- @class ammgui.component.inline.Element: ammcore.class.Base, ammgui.component.base.SupportsDebugOverlay
ns.Element = class.create("Element")

--- @param css ammgui.css.rule.Resolved
--- @param parent ammgui.component.inline.Component
---
--- !doctype classmethod
--- @generic T: ammgui.component.inline.Element
--- @param self T
--- @return T
function ns.Element:New(css, parent)
    self = class.Base.New(self)

    --- Component that created this element.
    ---
    --- @type ammgui.component.inline.Component
    self.parent = parent

    --- Css data for this word.
    ---
    --- @type ammgui.css.rule.Resolved
    self.css = css

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

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.marginLeft = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.marginRight = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.paddingTop = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.paddingRight = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.paddingBottom = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.paddingLeft = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type boolean
    self.hasOutlineLeft = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type boolean
    self.hasOutlineRight = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.outlineWidth = nil

    --- Layout data, calculated by `ammgui.component.block.textbox.TextBox`.
    ---
    --- @type number
    self.outlineRadius = nil

    return self
end

--- Called to prepare for layout estimation.
---
--- This function primarily exists to measure string widths in batch,
--- as repeated calls to `gpu:measureText` are quite expensive.
---
--- !doc abstract
--- @param textMeasure ammgui.component.context.TextMeasure
function ns.Element:prepareLayout(textMeasure)
    if self.parent.outdated then
        self._cachedIntrinsicWidth = nil
        self._cachedFontSize = nil
        self._cachedSizeParams = nil
        self._cachedSize = nil
        self._cachedAdjustedHeight = nil
    end
end

--- Return element's size in points.
---
--- @return integer size element's text size.
function ns.Element:getFontSize()
    if not self._cachedFontSize then
        local size = table.unpack(self.css.fontSize) * 400 / 726
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
    local lineHeight, unit = table.unpack(self.css.lineHeight)
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
--- !doc virtual
--- @return boolean canSkip can be removed from the text when wrapping it.
function ns.Element:canSkip()
    return false
end

--- Render this element.
---
--- !doc abstract
--- @param ctx ammgui.component.context.RenderingContext
function ns.Element:draw(ctx)
    local width, uHeightA, uHeightB = table.unpack(self._cachedSize)
    local heightA, heightB = table.unpack(self._cachedAdjustedHeight)

    local paddingPos = structs.Vector2D { self.paddingLeft, uHeightA - heightA + self.paddingTop }
    local paddingSize = structs.Vector2D {
        width + self.paddingLeft + self.paddingRight,
        heightA + heightB + self.paddingTop + self.paddingBottom,
    }

    ctx:pushEventListener(paddingPos, paddingSize, self.parent)
    ctx:noteDebugTarget(self, self.parent.id)
end

function ns.Element:drawDebugOverlay(ctx, drawContent, drawPadding, drawOutline, drawMargin)
    local width, uHeightA, uHeightB = table.unpack(self._cachedSize)
    local heightA, heightB = table.unpack(self._cachedAdjustedHeight)

    local contentPos = structs.Vector2D { 0, uHeightA - heightA }
    local contentSize = structs.Vector2D { width, heightA + heightB }

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
                structs.Vector2D { 0, uHeightA },
                structs.Vector2D { width, uHeightA },
            },
            1,
            structs.Color { 0x54 / 0xff, 0xA9 / 0xff, 0xCE / 0xff, 1 }
        )
        ctx.gpu:drawLines(
            {
                structs.Vector2D { 0, 0 },
                structs.Vector2D { width, 0 },
            },
            1,
            structs.Color { 0x54 / 0xff, 0xA9 / 0xff, 0xCE / 0xff, 0.3 }
        )
        ctx.gpu:drawLines(
            {
                structs.Vector2D { 0, uHeightA + uHeightB },
                structs.Vector2D { width, uHeightA + uHeightB },
            },
            1,
            structs.Color { 0x54 / 0xff, 0xA9 / 0xff, 0xCE / 0xff, 0.3 }
        )
    end

    local paddingPos = contentPos - structs.Vector2D { self.paddingLeft, self.paddingTop }
    local paddingSize = contentSize + structs.Vector2D {
        self.paddingLeft + self.paddingRight,
        self.paddingTop + self.paddingBottom,
    }

    -- Padding.
    if drawPadding then
        ns.Component.drawRectangleWithHole(
            ctx,
            paddingPos,
            paddingSize,
            contentPos,
            contentSize,
            structs.Color { 0xA4 / 0xff, 0xA0 / 0xff, 0xC6 / 0xff, 0.5 }
        )
    end

    local outlineWidthLeft = self.hasOutlineLeft and self.outlineWidth or 0
    local outlineWidthRight = self.hasOutlineRight and self.outlineWidth or 0

    local outlinePos = paddingPos - structs.Vector2D { outlineWidthLeft, self.outlineWidth }
    local outlineSize = paddingSize + structs.Vector2D {
        outlineWidthLeft + outlineWidthRight,
        2 * self.outlineWidth,
    }

    -- Outline
    if drawOutline then
        ns.Component.drawRectangleWithHole(
            ctx,
            outlinePos,
            outlineSize,
            paddingPos,
            paddingSize,
            structs.Color { 0xC9 / 0xff, 0x85 / 0xff, 0x31 / 0xff, 0.5 }
        )
    end

    local marginLeft = math.max(self.marginLeft, 0)
    local marginRight = math.max(self.marginRight, 0)

    local marginPos = outlinePos - structs.Vector2D { marginLeft, 0 }
    local marginSize = outlineSize + structs.Vector2D { marginLeft + marginRight, 0 }

    -- Margin
    if drawMargin then
        ns.Component.drawRectangleWithHole(
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
