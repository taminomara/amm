local class = require "ammcore.class"
local icom = require "ammgui.component.inline"
local bcom = require "ammgui.component.block"
local util = require "ammgui.component.block.util"
local span = require "ammgui.component.inline.text"
local fun = require "ammcore.fun"

--- Paragraph component.
---
--- !doctype module
--- @class ammgui.component.block.p
local ns = {}

--- Component that holds text.
---
--- @class ammgui.component.block.textbox.TextBox: ammgui.component.block.Component
ns.TextBox = class.create("TextBox", bcom.Component)

ns.TextBox.elem = ""

--- @param data ammgui.dom.DivNode
function ns.TextBox:onMount(ctx, data)
    bcom.Component.onMount(self, ctx, data)

    --- @private
    --- @type ammgui.component.base.ComponentProvider[]
    self._providers = nil

    --- @private
    --- @type ammgui.component.inline.Component[]
    self._children = nil

    self._providers, self._children = icom.Component.syncAll(ctx, {}, {}, data, self)
end

--- @param data ammgui.dom.DivNode
function ns.TextBox:onUpdate(ctx, data)
    bcom.Component.onUpdate(self, ctx, data)
    local providers, children, outdated, outdatedCss = icom.Component.syncAll(
        ctx, self._providers, self._children, data, self
    )
    self._providers = providers
    self._children = children
    self.outdated = self.outdated or outdated
    self.outdatedCss = self.outdatedCss or outdatedCss
end

function ns.TextBox:propagateCssChanges(ctx)
    for _, child in ipairs(self._children) do
        child:updateCss(ctx)
        self.outdated = self.outdated or child.outdated
    end
end

function ns.TextBox:prepareLayout(textMeasure)
    bcom.Component.prepareLayout(self, textMeasure)
    self._elements = self:_makeElements()
    for _, element in ipairs(self._elements) do
        element.element:prepareLayout(textMeasure)
    end
    if #self._elements > 0 then
        if self.css.marginTrim == "inline" or self.css.marginTrim == "inline-start" then
            self._elements[1].marginLeft = { 0, "px" }
        end
        if self.css.marginTrim == "inline" or self.css.marginTrim == "inline-end" then
            self._elements[#self._elements].marginRight = { 0, "px" }
        end
    end
end

function ns.TextBox:calculateIntrinsicContentWidth()
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

        local elementMinWidth, elementMaxWidth = element:getIntrinsicContentWidth()
        local adjustment = marginLeft + paddingLeft + paddingRight + marginRight
        if hasOutlineLeft then
            adjustment = adjustment + outlineWidth
        end
        if hasOutlineRight then
            adjustment = adjustment + outlineWidth
        end

        maxContentWidth = maxContentWidth + elementMaxWidth + adjustment

        if not element:canSkip() then
            minContentWidth = math.max(minContentWidth, elementMinWidth + adjustment)
        end
    end

    if self.css.textWrapMode == "nowrap" then
        minContentWidth = maxContentWidth
    end

    return minContentWidth, maxContentWidth, false
end

function ns.TextBox:calculateContentLayout(availableWidth, availableHeight)
    --- @type { [integer]: ammgui.component.inline.Element | false, width: number, heightA: number, heightB: number }[]
    self._lines = {}

    local maxLineWidth, totalHeight = 0, 0
    local shouldWrap = self.css.textWrapMode ~= "nowrap"

    --- @type { [integer]: ammgui.component.inline.Element, width: number, heightA: number, heightB: number }
    local line = {}
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
        self.textLayout.lastBaselineOffset = totalHeight + lineHeightA
        self.textLayout.firstBaselineOffset = self.textLayout.firstBaselineOffset or self.textLayout.lastBaselineOffset
        totalHeight = totalHeight + lineHeightA + lineHeightB
    end

    for _, elementSettings in ipairs(self._elements) do
        local element = elementSettings.element --[[ @as ammgui.component.inline.Element ]]
        local paddingLeftWithUnit = elementSettings.paddingLeft
        local paddingRightWithUnit = elementSettings.paddingRight
        local marginLeftWithUnit = elementSettings.marginLeft
        local marginRightWithUnit = elementSettings.marginRight

        element.hasOutlineLeft = paddingLeftWithUnit ~= nil
        element.hasOutlineRight = paddingRightWithUnit ~= nil

        element.paddingLeft = util.resolvePercentageOrNil(paddingLeftWithUnit, availableWidth or 0) or 0
        element.paddingRight = util.resolvePercentageOrNil(paddingRightWithUnit, availableWidth or 0) or 0
        element.marginLeft = util.resolvePercentageOrNil(marginLeftWithUnit, availableWidth or 0) or 0
        element.marginRight = util.resolvePercentageOrNil(marginRightWithUnit, availableWidth or 0) or 0

        element.paddingTop = util.resolvePercentage(element.css.paddingTop, availableWidth or 0)
        element.paddingBottom = util.resolvePercentage(element.css.paddingBottom, availableWidth or 0)

        element.outlineRadius = util.resolvePercentage(element.css.outlineRadius, availableHeight or 0)
        element.outlineWidth = util.resolvePercentage(element.css.outlineWidth, availableHeight or 0)

        local elementWidth = element:getWidth() + element.marginLeft + element.paddingLeft + element.paddingRight +
            element.marginRight
        if element.hasOutlineLeft then
            elementWidth = elementWidth + element.outlineWidth
        end
        if element.hasOutlineRight then
            elementWidth = elementWidth + element.outlineWidth
        end

        if shouldWrap and availableWidth and lineWidth + elementWidth > availableWidth then
            -- This line is full, start a new one.
            while
                #line > 0
                and not line[#line].hasOutlineRight
                and line[#line].paddingRight == 0
                and line[#line]:canSkip()
            do
                -- Clean up spaces at the end of the line.
                local element = table.remove(line)
                lineWidth = lineWidth - element:getWidth()
                lineWidth = lineWidth - element.paddingLeft
                lineWidth = lineWidth - element.paddingRight
                lineWidth = lineWidth - element.marginLeft
                lineWidth = lineWidth - element.marginRight
                if element.hasOutlineLeft then lineWidth = lineWidth - element.outlineWidth end
                if element.hasOutlineRight then lineWidth = lineWidth - element.outlineWidth end
            end
            if #line > 0 then
                pushLine()
            end
            if element:canSkip() then
                lineWidth = 0
                line = {}
            else
                lineWidth = elementWidth
                line = { element }
            end
        elseif #line > 0 or not element:canSkip() then
            table.insert(line, element)
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

function ns.TextBox:_joinLines()
    for _, line in ipairs(self._lines) do
        local lastWordIndex = nil
        for i, element in ipairs(line) do
            if element and class.isChildOf(element, span.Word) then
                --- @cast element ammgui.component.inline.text.Word
                if
                    lastWordIndex
                    and not line[lastWordIndex].hasOutlineRight
                    and line[lastWordIndex].paddingRight == 0
                    and line[lastWordIndex].marginRight == 0
                    and not element.hasOutlineLeft
                    and element.paddingLeft == 0
                    and element.marginLeft == 0
                    and rawequal(line[lastWordIndex].css, element.css)
                then
                    line[lastWordIndex] = line[lastWordIndex] .. element
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

function ns.TextBox:draw(ctx)
    bcom.Component.draw(self, ctx)

    local y = self.usedLayout.contentPosition.y
    for _, line in ipairs(self._lines) do
        local x = self.usedLayout.contentPosition.x
        y = y + line.heightA
        for _, element in ipairs(line) do
            if not element then
                goto continue
            end

            --- @cast element ammgui.component.inline.Element
            local width = element:getWidth()
            local heightA, heightB = element:getAdjustedHeight()
            local uHeightA, uHeightB = element:getHeight()

            local outlineWidthLeft = element.hasOutlineLeft and element.outlineWidth or 0
            local outlineWidthRight = element.hasOutlineRight and element.outlineWidth or 0

            x = x + element.marginLeft

            self.drawContainer(
                ctx,
                structs.Vector2D {
                    x = x,
                    y = y - element.outlineWidth - element.paddingTop - heightA,
                },
                structs.Vector2D {
                    x = outlineWidthLeft + element.paddingLeft + width + element.paddingRight + outlineWidthRight,
                    y = element.outlineWidth + element.paddingTop + heightA + heightB + element.paddingBottom + element.outlineWidth,
                },
                element.css.backgroundColor,
                element.outlineWidth,
                element.css.outlineTint,
                element.outlineRadius,
                element.hasOutlineLeft,
                element.hasOutlineRight
            )

            x = x + outlineWidthLeft + element.paddingLeft

            local visible = ctx:pushLayout(
                structs.Vector2D { x = x, y = y - uHeightA },
                structs.Vector2D { x = width, y = uHeightA + uHeightB },
                element.css.overflow == "hidden"
            )
            if visible then
                element:draw(ctx)
            end
            ctx:popLayout()

            x = x + width + element.paddingRight + outlineWidthRight + element.marginRight

            ::continue::
        end
        y = y + line.heightB
    end
end

--- @private
function ns.TextBox:_makeElements()
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
                element = span.Word:New("", component.css, component),
                paddingLeft = paddingLeft,
                marginLeft = marginLeft,
                paddingRight = paddingRight,
                marginRight = marginRight,
            })
        end
    end
    return elements
end

function ns.TextBox:reprChildren()
    return fun.a.map(self._children, function(x) return x:repr() end)
end

return ns
