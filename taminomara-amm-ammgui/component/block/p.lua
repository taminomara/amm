local class = require "ammcore.class"
local icom = require "ammgui.component.inline"
local bcom = require "ammgui.component.block"
local util = require "ammgui.component.block.util"
local span = require "ammgui.component.inline.span"
local array = require "ammcore._util.array"

--- Paragraph component.
---
--- !doctype module
--- @class ammgui.component.block.p
local ns = {}

--- Component that holds text.
---
--- @class ammgui.component.block.p.P: ammgui.component.block.Component
ns.P = class.create("P", bcom.Component)

ns.P.elem = "p"

--- @param data ammgui.dom.TextNode
function ns.P:onMount(ctx, data)
    bcom.Component.onMount(self, ctx, data)

    --- @private
    --- @type ammgui.component.inline.ComponentProvider[]
    self._providers = nil

    --- @private
    --- @type ammgui.component.inline.Component[]
    self._children = nil

    self._providers, self._children = icom.Component.syncAll({}, {}, data)
end

--- @param data ammgui.dom.TextNode
function ns.P:onUpdate(ctx, data)
    bcom.Component.onUpdate(self, ctx, data)
    local providers, children, outdated, outdatedCss = icom.Component.syncAll(self._providers, self._children, data)
    self._providers = providers
    self._children = children
    self.outdated = self.outdated or outdated
    self.outdatedCss = self.outdatedCss or outdatedCss
end

function ns.P:propagateCssChanges(ctx)
    for _, child in ipairs(self._children) do
        child:updateCss(ctx)
        self.outdated = self.outdated or child.outdated
    end
end

function ns.P:prepareLayout(textMeasure)
    bcom.Component.prepareLayout(self, textMeasure)
    self._elements = self:_makeElements()
    for _, element in ipairs(self._elements) do
        element.element:prepareLayout(textMeasure)
    end
    if #self._elements > 0 then
        if self.css.marginTrim == "inline" or self.css.marginTrim == "inline-start" then
            self._elements[1].marginLeft = 0
        end
        if self.css.marginTrim == "inline" or self.css.marginTrim == "inline-end" then
            self._elements[#self._elements].marginRight = 0
        end
    end
end

function ns.P:calculateIntrinsicContentWidth()
    local minContentWidth, maxContentWidth = 0, 0

    for _, elementSettings in ipairs(self._elements) do
        local element = elementSettings.element --[[ @as ammgui.component.inline.Element ]]
        local paddingLeftWithUnit = elementSettings.paddingLeft
        local paddingRightWithUnit = elementSettings.paddingRight
        local marginLeftWithUnit = elementSettings.marginLeft
        local marginRightWithUnit = elementSettings.marginRight
        local hasOutlineLeft = paddingLeftWithUnit ~= nil
        local hasOutlineRight = paddingRightWithUnit ~= nil

        local paddingLeft = util.resolveAbsOrNil(paddingLeftWithUnit) or 0
        local paddingRight = util.resolveAbsOrNil(paddingRightWithUnit) or 0
        local marginLeft = util.resolveAbsOrNil(marginLeftWithUnit) or 0
        local marginRight = util.resolveAbsOrNil(marginRightWithUnit) or 0

        local outlineWidth = util.resolvePercentage(element.css.outlineWidth, 0)

        local elementWidth = element:getWidth() + marginLeft + paddingLeft + paddingRight + marginRight
        if hasOutlineLeft then
            elementWidth = elementWidth + outlineWidth
        end
        if hasOutlineRight then
            elementWidth = elementWidth + outlineWidth
        end

        maxContentWidth = maxContentWidth + elementWidth

        if not element:canSkip() then
            minContentWidth = math.max(minContentWidth, elementWidth)
        end
    end

    if self.css.textWrapMode == "nowrap" then
        minContentWidth = maxContentWidth
    end

    return minContentWidth, maxContentWidth, false
end

function ns.P:calculateContentLayout(availableWidth, availableHeight)
    self._lines = {}
    local maxLineWidth, totalHeight = 0, 0
    local shouldWrap = self.css.textWrapMode ~= "nowrap"

    local line = {
        paddingTop = {},
        paddingRight = {},
        paddingBottom = {},
        paddingLeft = {},
        marginLeft = {},
        marginRight = {},
        hasOutlineLeft = {},
        hasOutlineRight = {},
        outlineWidth = {},
        outlineRadius = {},
    }
    local lineWidth = 0

    local function pushLine()
        local lineHeightA, lineHeightB = 0, 0
        for _, element in ipairs(line) do
            local heightA, heightB = element:getAdjustedHeight()
            lineHeightA = math.max(lineHeightA, heightA)
            lineHeightB = math.max(lineHeightB, heightB)
        end
        line.width = lineWidth
        line.heightA = lineHeightA
        line.heightB = lineHeightB
        table.insert(self._lines, line)
        maxLineWidth = math.max(maxLineWidth, lineWidth)
        totalHeight = totalHeight + lineHeightA + lineHeightB
    end

    for _, elementSettings in ipairs(self._elements) do
        local element = elementSettings.element --[[ @as ammgui.component.inline.Element ]]
        local paddingLeftWithUnit = elementSettings.paddingLeft
        local paddingRightWithUnit = elementSettings.paddingRight
        local marginLeftWithUnit = elementSettings.marginLeft
        local marginRightWithUnit = elementSettings.marginRight
        local hasOutlineLeft = paddingLeftWithUnit ~= nil
        local hasOutlineRight = paddingRightWithUnit ~= nil

        local paddingLeft = util.resolvePercentageOrNil(paddingLeftWithUnit, availableWidth or 0) or 0
        local paddingRight = util.resolvePercentageOrNil(paddingRightWithUnit, availableWidth or 0) or 0
        local marginLeft = util.resolvePercentageOrNil(marginLeftWithUnit, availableWidth or 0) or 0
        local marginRight = util.resolvePercentageOrNil(marginRightWithUnit, availableWidth or 0) or 0

        local paddingTop = util.resolvePercentage(element.css.paddingTop, availableWidth or 0)
        local paddingBottom = util.resolvePercentage(element.css.paddingBottom, availableWidth or 0)

        local outlineRadius = util.resolvePercentage(element.css.outlineRadius, availableHeight or 0)
        local outlineWidth = util.resolvePercentage(element.css.outlineWidth, availableHeight or 0)

        local elementWidth = element:getWidth() + marginLeft + paddingLeft + paddingRight + marginRight
        if hasOutlineLeft then
            elementWidth = elementWidth + outlineWidth
        end
        if hasOutlineRight then
            elementWidth = elementWidth + outlineWidth
        end

        if shouldWrap and availableWidth and lineWidth + elementWidth > availableWidth then
            -- This line is full, start a new one.
            while
                #line > 0
                and not line.hasOutlineRight[#line]
                and line.paddingRight[#line] == 0
                and line[#line]:canSkip()
            do
                -- Clean up spaces at the end of the line.
                lineWidth = lineWidth - table.remove(line):getWidth()
                lineWidth = lineWidth - table.remove(line.paddingLeft)
                lineWidth = lineWidth - table.remove(line.paddingRight)
                lineWidth = lineWidth - table.remove(line.marginLeft)
                lineWidth = lineWidth - table.remove(line.marginRight)
                local outlineWidth = table.remove(line.outlineWidth)
                local hasOutlineLeft = table.remove(line.hasOutlineLeft)
                if hasOutlineLeft then lineWidth = lineWidth - outlineWidth end
                local hasOutlineRight = table.remove(line.hasOutlineRight)
                if hasOutlineRight then lineWidth = lineWidth - outlineWidth end
                table.remove(line.paddingTop)
                table.remove(line.paddingBottom)
                table.remove(line.outlineRadius)
            end
            if #line > 0 then
                pushLine()
            end
            if element:canSkip() then
                lineWidth = 0
                line = {
                    paddingTop = {},
                    paddingRight = {},
                    paddingBottom = {},
                    paddingLeft = {},
                    marginLeft = {},
                    marginRight = {},
                    hasOutlineLeft = {},
                    hasOutlineRight = {},
                    outlineWidth = {},
                    outlineRadius = {},
                }
            else
                lineWidth = elementWidth
                line = {
                    element,
                    paddingTop = { paddingTop },
                    paddingRight = { paddingRight },
                    paddingBottom = { paddingBottom },
                    paddingLeft = { paddingLeft },
                    marginLeft = { marginLeft },
                    marginRight = { marginRight },
                    hasOutlineLeft = { hasOutlineLeft },
                    hasOutlineRight = { hasOutlineRight },
                    outlineWidth = { outlineWidth },
                    outlineRadius = { outlineRadius },
                }
            end
        elseif #line > 0 or not element:canSkip() then
            table.insert(line, element)
            table.insert(line.paddingTop, paddingTop)
            table.insert(line.paddingRight, paddingRight)
            table.insert(line.paddingBottom, paddingBottom)
            table.insert(line.paddingLeft, paddingLeft)
            table.insert(line.marginLeft, marginLeft)
            table.insert(line.marginRight, marginRight)
            table.insert(line.hasOutlineLeft, hasOutlineLeft)
            table.insert(line.hasOutlineRight, hasOutlineRight)
            table.insert(line.outlineWidth, outlineWidth)
            table.insert(line.outlineRadius, outlineRadius)
            lineWidth = lineWidth + elementWidth
        end
    end

    if #line > 0 then
        pushLine()
    end

    self:_joinLines()

    local contentSize = structs.Vector2D { maxLineWidth, totalHeight }
    return contentSize, contentSize -- XXX: no overflow?
end

function ns.P:_joinLines()
    for _, line in ipairs(self._lines) do
        local lastWordIndex = nil
        for i, element in ipairs(line) do
            if class.isChildOf(element, span.Word) then
                --- @cast element ammgui.component.inline.span.Word
                if
                    lastWordIndex
                    and not line.hasOutlineRight[lastWordIndex]
                    and line.paddingRight[lastWordIndex] == 0
                    and line.marginRight[lastWordIndex] == 0
                    and not line.hasOutlineLeft[i]
                    and line.paddingLeft[i] == 0
                    and line.marginLeft[i] == 0
                    and rawequal(line[lastWordIndex].css, element.css)
                then
                    line[lastWordIndex] = line[lastWordIndex] .. element
                    line.paddingRight[lastWordIndex] = line.paddingRight[i]
                    line.marginRight[lastWordIndex] = line.marginRight[i]
                    line.hasOutlineRight[lastWordIndex] = line.hasOutlineRight[i]
                    line[i] = false
                else
                    lastWordIndex = i
                end
            else
                lastWordIndex = nil
            end
        end
    end
end

function ns.P:draw(ctx)
    bcom.Component.draw(self, ctx)

    local y = self.usedLayout.contentPosition.y
    for _, line in ipairs(self._lines) do
        local x = self.usedLayout.contentPosition.x
        y = y + line.heightA
        for i, element in ipairs(line) do
            if not element then
                goto continue
            end

            --- @cast element ammgui.component.inline.Element
            local width = element:getWidth()
            local heightA, heightB = element:getHeight()
            local paddingTop = line.paddingTop[i]
            local paddingRight = line.paddingRight[i]
            local marginLeft = line.marginLeft[i]
            local marginRight = line.marginRight[i]
            local paddingBottom = line.paddingBottom[i]
            local paddingLeft = line.paddingLeft[i]
            local hasOutlineLeft = line.hasOutlineLeft[i]
            local hasOutlineRight = line.hasOutlineRight[i]
            local outlineWidth = line.outlineWidth[i]
            local outlineRadius = line.outlineRadius[i]

            local outlineWidthLeft = hasOutlineLeft and outlineWidth or 0
            local outlineWidthRight = hasOutlineRight and outlineWidth or 0

            x = x + marginLeft

            self:drawContainer(
                ctx,
                structs.Vector2D {
                    x = x,
                    y = y - outlineWidth - paddingTop - heightA,
                },
                structs.Vector2D {
                    x = outlineWidthLeft + paddingLeft + width + paddingRight + outlineWidthRight,
                    y = outlineWidth + paddingTop + heightA + heightB + paddingBottom + outlineWidth,
                },
                element.css.backgroundColor,
                outlineWidth,
                element.css.outlineTint,
                outlineRadius,
                hasOutlineLeft,
                hasOutlineRight
            )

            x = x + outlineWidthLeft + paddingLeft

            local visible = ctx:pushLayout(
                structs.Vector2D { x = x, y = y - heightA },
                structs.Vector2D { x = width, y = heightA + heightB },
                element.css.overflow == "hidden"
            )
            if visible then
                element:render(ctx)
            end
            ctx:popLayout()

            x = x + width + paddingRight + outlineWidthRight + marginRight

            ::continue::
        end
        y = y + line.heightB
    end
end

--- @private
function ns.P:_makeElements()
    local elements = {}
    local lastIsSpace = true
    for _, component in ipairs(self._children) do
        --- @type [number, "px"|"%"]?
        local paddingLeft = component.css.paddingLeft
        --- @type [number, "px"|"%"]
        local paddingRight = component.css.paddingRight

        --- @type [number, "px"|"%"]|"auto"?
        local marginLeft = component.css.marginLeft
        --- @type [number, "px"|"%"]|"auto"
        local marginRight = component.css.marginRight

        for _, element in ipairs(component:getElements()) do
            local isSpace = element:canSkip()
            if not isSpace or (isSpace and not lastIsSpace) then
                table.insert(elements, {
                    element = element,
                    paddingLeft = paddingLeft,
                    marginLeft = marginLeft,
                })
                paddingLeft = nil
                marginLeft = nil
            end
            lastIsSpace = isSpace
        end

        if not paddingLeft or not marginLeft then
            -- PaddingLeft was inserted and set to `nil`:
            -- set paddingRight to last element in this component.
            elements[#elements].paddingRight = paddingRight
            elements[#elements].marginRight = marginRight
        elseif paddingLeft[1] > 0 or paddingRight[1] > 0 or marginLeft[1] > 0 or marginRight[1] > 0 then
            -- PaddingLeft wasn't inserted because there were no non-whitespace
            -- elements: insert a dummy word.
            -- TODO: don't use word, create a simpler element.
            table.insert(elements, {
                element = span.Word:New("", component.css),
                paddingLeft = paddingLeft,
                marginLeft = marginLeft,
                paddingRight = paddingRight,
                marginRight = marginRight,
            })
        end
    end
    return elements
end

function ns.P:reprChildren()
    return array.map(self._children, function (x) return x:repr() end)
end

--- Implements a ``<text>`` element.
---
--- @class ammgui.component.block.p.Text: ammgui.component.block.p.P
ns.Text = class.create("Text", ns.P)

ns.Text.elem = "text"

--- Implements a ``<h1>`` element.
---
--- @class ammgui.component.block.p.H1: ammgui.component.block.p.P
ns.H1 = class.create("H1", ns.P)

ns.H1.elem = "h1"

--- Implements a ``<h2>`` element.
---
--- @class ammgui.component.block.p.H2: ammgui.component.block.p.P
ns.H2 = class.create("H2", ns.P)

ns.H2.elem = "h2"

--- Implements a ``<h3>`` element.
---
--- @class ammgui.component.block.p.H3: ammgui.component.block.p.P
ns.H3 = class.create("H3", ns.P)

ns.H3.elem = "h3"

--- Implements a ``<button>`` element.
---
--- @class ammgui.component.block.p.Button: ammgui.component.block.p.P
ns.Button = class.create("Button", ns.P)

ns.Button.elem = "button"

--- Implements a ``<figcaption>`` element.
---
--- @class ammgui.component.block.p.FigCaption: ammgui.component.block.p.P
ns.FigCaption = class.create("FigCaption", ns.P)

ns.FigCaption.elem = "figcaption"

return ns
