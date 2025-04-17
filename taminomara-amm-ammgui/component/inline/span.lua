local class = require "ammcore.class"
local log = require "ammcore.log"
local base = require "ammgui.component.base"
local array = require "ammcore._util.array"
local icom = require "ammgui.component.inline"

--- Span element.
---
--- !doctype module
--- @class ammgui.component.inline.span
local ns = {}

--- Implements a string component.
---
--- @class ammgui.component.inline.span.Span: ammgui.component.inline.Component
ns.Span = class.create("Span", icom.Component)

ns.Span.elem = "span"

--- @param data ammgui.dom.SpanNode
function ns.Span:onMount(data)
    icom.Component.onMount(self, data)
    self.text = table.concat(data):gsub("[\a\r\t\v\b]", "")
end

--- @param data ammgui.dom.SpanNode
function ns.Span:onUpdate(data)
    icom.Component.onUpdate(self, data)
    local text = table.concat(data):gsub("[\a\r\t\v\b]", "")
    if text ~= self.text then
        self.outdated = true
        self._elementsCache = nil
        self.text = text
    end
end

function ns.Span:calculateElements()
    local result = {}

    if self.css.textWrapMode == "nowrap" then
        local spaceBefore, word, spaceAfter = self.text:gsub("%s+", " "):match("^(%s*)(.-)(%s*)$")
        if spaceBefore:len() > 0 then
            table.insert(result, ns.Word:New(" ", self.css))
        end
        if word:len() > 0 then
            table.insert(result, ns.Word:New(word, self.css))
        end
        if spaceAfter:len() > 0 then
            table.insert(result, ns.Word:New(" ", self.css))
        end
    else
        for space, word in self.text:gmatch("(%s*)([^%s%p]*[%p]*)") do
            if space:len() > 0 then
                table.insert(result, ns.Word:New(" ", self.css))
            end
            if word:len() > 0 then
                table.insert(result, ns.Word:New(word, self.css))
            end
        end
    end

    return result
end

--- A single word or whitespace.
---
--- @class ammgui.component.inline.span.Word: ammgui.component.inline.Element
ns.Word = class.create("Word", icom.Element)

--- @param word string
--- @param css ammgui.css.rule.Resolved
---
--- !doctype classmethod
--- @generic T: ammgui.component.inline.span.Word
--- @param self T
--- @return T
function ns.Word:New(word, css)
    self = icom.Element.New(self, css)

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

function ns.Word:onCssUpdate()
    self._cachedWidth = nil
    self._cachedHeight = nil
end

function ns.Word:prepareLayout(textMeasure)
    if not self._cachedWidth or not self._cachedHeight or not self._cachedBaseline then
        textMeasure:addRequest(
            self.word,
            self:getSize(),
            self.css.fontFamily == "monospace",
            function (size, baseline)
                self._cachedWidth = size.x --[[ @as integer ]]
                self._cachedHeight = size.y --[[ @as integer ]]
                self._cachedBaseline = baseline --[[ @as integer ]]
            end
        )
    end
end

function ns.Word:getWidth()
    assert(self._cachedWidth)
    return self._cachedWidth
end

function ns.Word:getHeight()
    assert(self._cachedHeight)
    assert(self._cachedBaseline)
    return self._cachedHeight + self._cachedBaseline, -self._cachedBaseline
end

function ns.Word:canSkip()
    return self.word == " "
end

--- @param context ammgui.component.context.RenderingContext
function ns.Word:render(context)
    if not self:canSkip() then
        context.gpu:drawText(
            structs.Vector2D { x = 0, y = 0 },
            self.word,
            self:getSize(),
            self.css.color,
            self.css.fontFamily == "monospace"
        )
    end
end

--- @param lhs ammgui.component.inline.span.Word
--- @param rhs ammgui.component.inline.span.Word
function ns.Word.__concat(lhs, rhs)
    local res = ns.Word:New(lhs.word .. rhs.word, lhs.css)
    if lhs._cachedWidth and rhs._cachedWidth then
        res._cachedWidth = lhs._cachedWidth + rhs._cachedWidth
    end
    res._cachedHeight = lhs._cachedHeight
    res._cachedBaseline = lhs._cachedBaseline
    res._cachedSize = lhs._cachedSize
    res._cachedAdjustedHeightA = lhs._cachedAdjustedHeightA
    res._cachedAdjustedHeightB = lhs._cachedAdjustedHeightB
    return res
end

--- Implements a ``<em>`` element.
---
--- @class ammgui.component.inline.span.Em: ammgui.component.inline.span.Span
ns.Em = class.create("Em", ns.Span)

ns.Em.elem = "em"

--- Implements a ``<code>`` element.
---
--- @class ammgui.component.inline.span.Code: ammgui.component.inline.span.Span
ns.Code = class.create("Code", ns.Span)

ns.Code.elem = "code"

return ns
