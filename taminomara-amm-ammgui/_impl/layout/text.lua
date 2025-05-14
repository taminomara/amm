local class = require "ammcore.class"
local fun = require "ammcore.fun"
local base = require "ammgui._impl.layout"

--- Text fragment.
---
--- !doctype module
--- @class ammgui._impl.layout.text
local ns = {}

--- Layout for text fragments.
---
--- This is a layout algorithm that deals with pieces of raw text.
--- It wraps them and returns an array of inline elements.
---
--- @class ammgui._impl.layout.text.Text: ammgui._impl.layout.Layout
ns.Text = class.create("Text", base.Layout)

--- @param css ammgui._impl.css.resolved.Resolved
--- @param text string text contents.
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.text.Text
--- @param self T
--- @return T
function ns.Text:New(css, text)
    self = base.Layout.New(self, css)

    --- @private
    --- @type string
    self._text = text

    --- @private
    --- @type ammgui._impl.layout.text.TextFragment[]
    self._fragments = nil

    return self
end

function ns.Text:isInline()
    return true
end

function ns.Text:asInline()
    if not self._fragments then
        self._fragments = {}
        local collapseSpaces = false

        local text = self._text
        if collapseSpaces then
            text = text:gsub("[\t ]+", " ")
        end
        text = text:gsub("[\r\v\b\f]", "")

        local re = self.css.textWrapMode == "wrap"
            and "([\n ]*)([^\n %p]*%p*)"
            or "(\n*)([^\n]*)"
        for spaces, word in self._text:gmatch(re) do
            for space, newline in spaces:gmatch("( *)(\n?)") do
                if space:len() > 0 then
                    table.insert(self._fragments, ns.TextFragment:New(" ", self, collapseSpaces, false))
                end
                if newline:len() > 0 then
                    table.insert(self._fragments, ns.TextFragment:New("", self, false, true))
                end
            end
            if word:len() > 0 then
                table.insert(self._fragments, ns.TextFragment:New(word, self, false, false))
            end
        end
    end

    return self._fragments
end

function ns.Text:asBlock()
    assert(false, "text fragment can't be displayed as a block")
end

--- A single word or whitespace.
---
--- @class ammgui._impl.layout.text.TextFragment: ammgui._impl.layout.Element
ns.TextFragment = class.create("TextFragment", base.Element)

--- @param text string
--- @param parent ammgui._impl.layout.Layout
--- @param canCollapse boolean
--- @param isLineBreak boolean
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.text.TextFragment
--- @param self T
--- @return T
function ns.TextFragment:New(text, parent, canCollapse, isLineBreak)
    self = base.Element.New(self, parent)

    --- Well, it's a word. Or a single space.
    ---
    --- @type string
    self.text = text

    --- @private
    --- @type boolean
    self._canCollapse = canCollapse

    --- @private
    --- @type boolean
    self._isLineBreak = isLineBreak

    --- @package
    --- @type integer?
    self._cachedWidth = nil

    --- @package
    --- @type integer?
    self._cachedHeight = nil

    --- @package
    --- @type integer?
    self._cachedBaseline = nil

    --- @private
    --- @type ammgui._impl.layout.Element
    self._collapsed = nil

    return self
end

--- Create an empty text fragment that will replace a collapsed text element.
---
--- @param collapsed ammgui._impl.layout.Element
--- @return ammgui._impl.layout.text.TextFragment
function ns.TextFragment:NewCollapsed(collapsed)
    --- @type { __originalTextElement: ammgui._impl.layout.Element }
    local originalElement = collapsed
    while originalElement.__originalTextElement do
        originalElement = originalElement.__originalTextElement
    end

    self = ns.TextFragment.New(
        self,
        "",
        originalElement.parent,
        true,
        false
    )

    self.boxData = fun.a.copy(collapsed.boxData)
    self.resolvedBoxData = collapsed.resolvedBoxData and fun.a.copy(collapsed.resolvedBoxData)
    self.totalLeftMargin = collapsed.totalLeftMargin
    self.totalRightMargin = collapsed.totalRightMargin
    self.resolvedHeightA = collapsed.resolvedHeightA
    self.resolvedHeightB = collapsed.resolvedHeightB
    if self.totalLeftMargin and self.totalRightMargin then
        self.totalWidth = self.totalLeftMargin + self.totalRightMargin
    end
    self.hasStarts = collapsed.hasStarts
    self.hasEnds = collapsed.hasEnds

    self._collapsed = originalElement

    return self
end

--- Pre-calculate dimensions of a text fragment.
---
--- @param textMeasure ammgui._impl.context.textMeasure.TextMeasure
function ns.TextFragment:prepareLayout(textMeasure)
    if
        not self._collapsed and (
            not self._cachedWidth
            or not self._cachedHeight
            or not self._cachedBaseline
        ) then
        textMeasure:addRequest(
            self.text,
            self:getFontSize(),
            self.parent.css.fontFamily == "monospace",
            function(size, baseline)
                self._cachedWidth = size.x --[[ @as integer ]]
                self._cachedHeight = size.y --[[ @as integer ]]
                self._cachedBaseline = baseline --[[ @as integer ]]
            end
        )
    end
end

function ns.TextFragment:calculateIntrinsicContentWidth()
    if self._collapsed then
        return 0, 0
    else
        return self._cachedWidth, self._cachedWidth
    end
end

function ns.TextFragment:calculateContentSize(availableWidth, availableHeight)
    if self._collapsed then
        return self._collapsed:getContentSize(availableWidth, availableHeight)
    else
        return
            assert(self._cachedWidth),
            assert(self._cachedHeight + self._cachedBaseline),
            assert(-self._cachedBaseline)
    end
end

function ns.TextFragment:canCollapse()
    return self._canCollapse
end

function ns.TextFragment:isCollapsed()
    return self._collapsed ~= nil
end

function ns.TextFragment:isLineBreak()
    return self._isLineBreak
end

function ns.TextFragment:draw(ctx)
    if not self:isCollapsed() then
        ctx.gpu:drawText(
            Vec2:New(0, 0),
            self.text,
            self:getFontSize(),
            self.parent.css.color,
            self.parent.css.fontFamily == "monospace"
        )
    end
end

--- @param lhs ammgui._impl.layout.text.TextFragment
--- @param rhs ammgui._impl.layout.text.TextFragment
function ns.TextFragment.merge(lhs, rhs)
    local res = ns.TextFragment:New(
        lhs.text .. rhs.text,
        lhs.parent,
        lhs._canCollapse and rhs._canCollapse,
        false
    )

    if lhs._cachedWidth and rhs._cachedWidth then
        res._cachedWidth = lhs._cachedWidth + rhs._cachedWidth
        res._cachedIntrinsicWidth = { res._cachedWidth, res._cachedWidth }
    end

    if lhs._cachedSize then
        res._cachedSize = { res._cachedWidth, table.unpack(lhs._cachedSize, 2) }
    end

    res._cachedSizeParams = lhs._cachedSizeParams
    res._cachedHeight = lhs._cachedHeight
    res._cachedBaseline = lhs._cachedBaseline
    res._cachedFontSize = lhs._cachedFontSize
    res._cachedAdjustedHeight = lhs._cachedAdjustedHeight

    res.resolvedHeightA = lhs.resolvedHeightA
    res.resolvedHeightB = lhs.resolvedHeightB
    res.totalLeftMargin = lhs.totalLeftMargin
    res.totalRightMargin = rhs.totalRightMargin
    if res._cachedWidth and res.totalLeftMargin and res.totalRightMargin then
        res.totalWidth = res._cachedWidth + res.totalLeftMargin + res.totalRightMargin
    end
    res.hasStarts = lhs.hasStarts
    res.hasEnds = rhs.hasEnds

    assert(#lhs.resolvedBoxData == #rhs.resolvedBoxData)
    res.resolvedBoxData = lhs.resolvedBoxData
    for i, boxData in ipairs(rhs.resolvedBoxData) do
        res.resolvedBoxData[i].isEnd = boxData.isEnd
        res.resolvedBoxData[i].paddingRight = boxData.paddingRight
        res.resolvedBoxData[i].marginRight = boxData.marginRight
    end

    return res
end

return ns
