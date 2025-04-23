local class = require "ammcore.class"
local base = require "ammgui.component.base"
local icom = require "ammgui.component.inline"

--- Span element.
---
--- !doctype module
--- @class ammgui.component.inline.text
local ns = {}

--- Implements a string component.
---
--- @class ammgui.component.inline.text.Text: ammgui.component.inline.Component
ns.Text = class.create("Text", icom.Component)

ns.Text.elem = ""

--- @param data ammgui.dom.SpanNode
function ns.Text:onMount(ctx, data)
    icom.Component.onMount(self, ctx, data)
    self.text = table.concat(data):gsub("[\a\r\t\v\b]", "")
end

--- @param data ammgui.dom.SpanNode
function ns.Text:onUpdate(ctx, data)
    icom.Component.onUpdate(self, ctx, data)
    local text = table.concat(data):gsub("[\a\r\t\v\b]", "")
    if text ~= self.text then
        self.outdated = true
        self._elementsCache = nil
        self.text = text
    end
end

function ns.Text:calculateElements()
    local result = {}

    if self.css.textWrapMode == "nowrap" then
        local spaceBefore, word, spaceAfter = self.text:gsub("%s+", " "):match("^(%s*)(.-)(%s*)$")
        if spaceBefore:len() > 0 then
            table.insert(result, ns.Word:New(" ", self.css, self))
        end
        if word:len() > 0 then
            table.insert(result, ns.Word:New(word, self.css, self))
        end
        if spaceAfter:len() > 0 then
            table.insert(result, ns.Word:New(" ", self.css, self))
        end
    else
        for space, word in self.text:gmatch("(%s*)([^%s%p]*[%p]*)") do
            if space:len() > 0 then
                table.insert(result, ns.Word:New(" ", self.css, self))
            end
            if word:len() > 0 then
                table.insert(result, ns.Word:New(word, self.css, self))
            end
        end
    end

    return result
end

function ns.Text:repr()
    local repr = base.Component.repr(self)
    repr.inlineContent = self.text
    return repr
end

--- A single word or whitespace.
---
--- @class ammgui.component.inline.text.Word: ammgui.component.inline.Element
ns.Word = class.create("Word", icom.Element)

--- @param word string
--- @param css ammgui.css.rule.Resolved
--- @param parent ammgui.component.inline.Component
---
--- !doctype classmethod
--- @generic T: ammgui.component.inline.text.Word
--- @param self T
--- @return T
function ns.Word:New(word, css, parent)
    self = icom.Element.New(self, css, parent)

    --- Well, it's a word. Or a single space.
    ---
    --- @type string
    self.word = word

    --- @package
    --- @type integer?
    self._cachedWidth = nil

    --- @package
    --- @type integer?
    self._cachedHeight = nil

    --- @package
    --- @type integer?
    self._cachedBaseline = nil

    return self
end

function ns.Word:prepareLayout(textMeasure)
    icom.Element.prepareLayout(self, textMeasure)

    if not self._cachedWidth or not self._cachedHeight or not self._cachedBaseline then
        textMeasure:addRequest(
            self.word,
            self:getFontSize(),
            self.css.fontFamily == "monospace",
            function(size, baseline)
                self._cachedWidth = size.x --[[ @as integer ]]
                self._cachedHeight = size.y --[[ @as integer ]]
                self._cachedBaseline = baseline --[[ @as integer ]]
            end
        )
    end
end

function ns.Word:calculateIntrinsicContentWidth()
    return self._cachedWidth, self._cachedWidth
end

function ns.Word:calculateContentSize(availableWidth, availableHeight)
    return
        self._cachedWidth,
        self._cachedBaseline,
        self._cachedHeight - self._cachedBaseline
end

function ns.Word:canSkip()
    return self.word == " "
end

--- @param ctx ammgui.component.context.RenderingContext
function ns.Word:draw(ctx)
    icom.Element.draw(self, ctx)
    if not self:canSkip() then
        ctx.gpu:drawText(
            structs.Vector2D { x = 0, y = 0 },
            self.word,
            self:getFontSize(),
            self.css.color,
            self.css.fontFamily == "monospace"
        )
    end
end

--- @param lhs ammgui.component.inline.text.Word
--- @param rhs ammgui.component.inline.text.Word
function ns.Word.__concat(lhs, rhs)
    local res = ns.Word:New(lhs.word .. rhs.word, lhs.css, lhs.parent)

    if lhs._cachedWidth and rhs._cachedWidth then
        res._cachedWidth = lhs._cachedWidth + rhs._cachedWidth
        res._cachedIntrinsicWidth = { res._cachedWidth, res._cachedWidth }
    end

    if lhs._cachedSize then
        res._cachedSize = { res._cachedWidth, lhs._cachedSize[2], lhs._cachedSize[3] }
    end

    res._cachedSizeParams = lhs._cachedSizeParams
    res._cachedHeight = lhs._cachedHeight
    res._cachedBaseline = lhs._cachedBaseline
    res._cachedFontSize = lhs._cachedFontSize
    res._cachedAdjustedHeight = lhs._cachedAdjustedHeight
    res.marginLeft = lhs.marginLeft
    res.marginRight = rhs.marginRight
    res.paddingTop = lhs.paddingTop
    res.paddingRight = rhs.paddingRight
    res.paddingBottom = lhs.paddingBottom
    res.paddingLeft = lhs.paddingLeft
    res.hasOutlineLeft = lhs.hasOutlineLeft
    res.hasOutlineRight = rhs.hasOutlineRight
    res.outlineWidth = lhs.outlineWidth
    res.outlineRadius = lhs.outlineRadius

    return res
end

--- Implements a ``<span>`` element.
---
--- @class ammgui.component.inline.text.Span: ammgui.component.inline.text.Text
ns.Span = class.create("Span", ns.Text)

ns.Span.elem = "span"

--- Implements a ``<em>`` element.
---
--- @class ammgui.component.inline.text.Em: ammgui.component.inline.text.Text
ns.Em = class.create("Em", ns.Text)

ns.Em.elem = "em"

--- Implements a ``<code>`` element.
---
--- @class ammgui.component.inline.text.Code: ammgui.component.inline.text.Text
ns.Code = class.create("Code", ns.Text)

ns.Code.elem = "code"

return ns
