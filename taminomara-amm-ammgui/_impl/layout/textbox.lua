local class = require "ammcore.class"
local fun = require "ammcore.fun"
local blockBase = require "ammgui._impl.layout.blockBase"
local text = require "ammgui._impl.layout.text"
local log = require "ammcore.log"
local resolved = require "ammgui._impl.css.resolved"
local tracy = require "ammcore.tracy"
local layout= require "ammgui._impl.layout"

--- An implicitly created block of lines.
---
--- !doctype module
--- @class ammgui._impl.layout.textbox
local ns = {}

--- TextBox layout.
---
--- Text box is a block layout algorithm that arranges its children into lines
--- and renders them as inline elements. It is an implicitly created adaptor between
--- block and inline layouts.
---
--- @class ammgui._impl.layout.textbox.TextBox: ammgui._impl.layout.blockBase.BlockBase
ns.TextBox = class.create("TextBox", blockBase.BlockBase)

--- @param css ammgui._impl.css.resolved.Resolved
--- @param children ammgui._impl.layout.Layout[]
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.textbox.TextBox
--- @param self T
--- @return T
function ns.TextBox:New(css, children)
    self = blockBase.BlockBase.New(self, css)

    --- @protected
    --- @type ammgui._impl.layout.Layout[]
    self.children = children

    return self
end

function ns.TextBox:prepareLayout(textMeasure)
    do
        local _ <close> = tracy.zoneScopedN("AmmGui/Impl/PrepareLayout/TextBoxMakeElements")
        self._elements = self:_makeElements()
    end
    for _, element in ipairs(self._elements) do
        element:prepareLayout(textMeasure)
    end
end

function ns.TextBox:calculateIntrinsicContentWidth()
    local minContentWidth, maxContentWidth = 0, 0
    local lineMinWidth, lineMaxWidth = 0, 0
    local nowrap = self.css.textWrapMode == "nowrap"
    local trimStart = self.css.marginTrim == "inline" or self.css.marginTrim == "inline-start"
    local trimEnd = self.css.marginTrim == "inline" or self.css.marginTrim == "inline-end"

    local function resolveSpaceAroundElement(element, isFirst, isLast)
        local left, right = 0, 0
        for _, boxData in ipairs(element.boxData) do
            if boxData.isStart then
                left = left
                    + (self._resolvePercentageOrNil(boxData.parent.css.paddingLeft, 0) or 0)
                    + (self._resolvePercentageOrNil(boxData.parent.css.outlineWidth, 0) or 0)
                if not trimStart or not isFirst then
                    left = left + (self._resolvePercentageOrNil(boxData.parent.css.marginLeft, 0) or 0)
                end
            end
            if boxData.isEnd then
                right = right
                    + (self._resolvePercentageOrNil(boxData.parent.css.paddingRight, 0) or 0)
                    + (self._resolvePercentageOrNil(boxData.parent.css.outlineWidth, 0) or 0)
                if not trimEnd or not isLast then
                    right = right + (self._resolvePercentageOrNil(boxData.parent.css.marginRight, 0) or 0)
                end
            end
        end
        return left, right
    end

    for i, element in ipairs(self._elements) do
        local isFirst = i == 1
        local isLast = i == #self._elements
        if element:isLineBreak() then
            local left, right = resolveSpaceAroundElement(element, isFirst, isLast)
            minContentWidth = math.max(minContentWidth, lineMinWidth + left)
            maxContentWidth = math.max(maxContentWidth, lineMaxWidth + left)
            lineMinWidth = right
            lineMaxWidth = right
        else
            local elementMinWidth, elementMaxWidth = element:getIntrinsicContentWidth()
            local left, right = resolveSpaceAroundElement(element)
            local adjustment = left + right
            lineMaxWidth = lineMaxWidth + elementMaxWidth + adjustment
            if nowrap then
                lineMinWidth = lineMinWidth + elementMaxWidth + adjustment
            elseif not element:canCollapse() then
                lineMinWidth = math.max(lineMinWidth, elementMinWidth + adjustment)
            else
                lineMinWidth = math.max(lineMinWidth, adjustment)
            end
        end
    end

    minContentWidth = math.max(minContentWidth, lineMinWidth)
    maxContentWidth = math.max(maxContentWidth, lineMaxWidth)

    return minContentWidth, maxContentWidth, false
end

function ns.TextBox:calculateContentLayout(availableWidth, availableHeight)
    --- @type { [integer]: ammgui._impl.layout.Element, width: number, heightA: number, heightB: number }[]
    self._lines = {}

    local maxLineWidth, totalHeight = 0, 0

    local trimStart = self.css.marginTrim == "inline" or self.css.marginTrim == "inline-start"
    local trimEnd = self.css.marginTrim == "inline" or self.css.marginTrim == "inline-end"

    --- @type { [integer]: ammgui._impl.layout.Element, width: number, heightA: number, heightB: number }
    local line = {}
    local lineWidth = 0
    local lineIsEmpty = true

    --- @param element ammgui._impl.layout.Element
    local function resolveSpaceAroundElement(element, isFirst, isLast)
        --- We use rawset so that `resolvedBoxData` ends up on the outermost
        --- box value wrapper. This avoids unnecessary access to `__index`
        --- and `__newindex`.
        rawset(element, "resolvedBoxData", {})

        local left, right = 0, 0
        local hasStarts, hasEnds = false, false
        for _, boxData in ipairs(element.boxData) do
            --- @type ammgui._impl.layout.ResolvedElementBoxData
            local resolvedBoxData = {
                isStart = boxData.isStart,
                isEnd = boxData.isEnd,
                parent = boxData.parent,
                nodeEventListener = boxData.nodeEventListener,
                outlineWidth = self._resolvePercentage(boxData.parent.css.outlineWidth, availableWidth),
                paddingTop = self._resolvePercentage(boxData.parent.css.paddingTop, availableWidth),
                paddingBottom = self._resolvePercentage(boxData.parent.css.paddingBottom, availableWidth),
                paddingLeft = 0,
                paddingRight = 0,
                marginLeft = 0,
                marginRight = 0,
                outlineRadius = self._resolvePercentage(boxData.parent.css.outlineRadius, availableHeight),
            }
            if resolvedBoxData.isStart then
                hasStarts = true
                resolvedBoxData.paddingLeft = self._resolvePercentage(boxData.parent.css.paddingLeft, availableWidth)
                if not trimStart or not isFirst then
                    resolvedBoxData.marginLeft = self._resolvePercentageOrNil(
                        boxData.parent.css.marginLeft, availableWidth
                    ) or 0
                end
                left = left
                    + resolvedBoxData.marginLeft
                    + resolvedBoxData.paddingLeft
                    + resolvedBoxData.outlineWidth
            end
            if resolvedBoxData.isEnd then
                hasEnds = true
                resolvedBoxData.paddingRight = self._resolvePercentage(boxData.parent.css.paddingRight, availableWidth)
                if not trimEnd or not isLast then
                    resolvedBoxData.marginRight = self._resolvePercentageOrNil(
                        boxData.parent.css.marginRight, availableWidth
                    ) or 0
                end
                right = right
                    + resolvedBoxData.marginRight
                    + resolvedBoxData.paddingRight
                    + resolvedBoxData.outlineWidth
            end
            table.insert(element.resolvedBoxData, resolvedBoxData)
        end

        local width, heightA, heightB = element:getContentSize(availableWidth, availableHeight)

        rawset(element, "resolvedHeightA", heightA)
        rawset(element, "resolvedHeightB", heightB)
        rawset(element, "totalLeftMargin", left)
        rawset(element, "totalRightMargin", right)
        rawset(element, "totalWidth", left + right + width)
        rawset(element, "hasStarts", hasStarts)
        rawset(element, "hasEnds", hasEnds)
    end

    --- @param element ammgui._impl.layout.Element
    local function removeEnds(element)
        for _, resolvedBoxData in ipairs(element.resolvedBoxData) do
            resolvedBoxData.isEnd = false
            resolvedBoxData.marginRight = 0
            resolvedBoxData.paddingRight = 0
        end
        element.totalWidth = element.totalWidth - element.totalRightMargin
        element.totalRightMargin = 0
        element.hasEnds = false
    end

    --- @param element ammgui._impl.layout.Element
    local function removeStarts(element)
        for _, resolvedBoxData in ipairs(element.resolvedBoxData) do
            resolvedBoxData.isStart = false
            resolvedBoxData.marginLeft = 0
            resolvedBoxData.paddingLeft = 0
        end
        element.totalWidth = element.totalWidth - element.totalLeftMargin
        element.totalLeftMargin = 0
        element.hasStarts = false
    end

    local function pushLine()
        for i = #line, 1, -1 do
            if not line[i]:canCollapse() then
                break
            elseif not line[i]:isCollapsed() then
                lineWidth = lineWidth - line[i].totalWidth
                line[i] = text.TextFragment:NewCollapsed(line[i])
                lineWidth = lineWidth + line[i].totalWidth
            end
        end

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
        self.textLayout.firstBaselineOffset = self.textLayout.firstBaselineOffset or
            self.textLayout.lastBaselineOffset
        totalHeight = totalHeight + lineHeightA + lineHeightB
        line = {}
        lineWidth = 0
        lineIsEmpty = true
    end

    for i, element in ipairs(self._elements) do
        resolveSpaceAroundElement(element, i == 1, i == #self._elements)
        if element:isLineBreak() then
            -- We need to split line break into two collapsed elements:
            -- any left margins are left on the current line,
            -- any right margins are carried over.
            if element.hasStarts then
                local leftElement = text.TextFragment:NewCollapsed(element)
                removeEnds(leftElement)
                table.insert(line, leftElement)
                lineWidth = lineWidth + leftElement.totalWidth
            end
            pushLine()
            if element.hasEnds then
                local rightElement = text.TextFragment:NewCollapsed(element)
                removeStarts(rightElement)
                table.insert(line, rightElement)
                lineWidth = lineWidth + rightElement.totalWidth
            end
        elseif
            availableWidth
            and not element:canCollapse() -- collapsed elements never hang.
            and element.parent.css.textWrapMode ~= "nowrap"
            and lineWidth + element.totalWidth > availableWidth
        then
            pushLine()
            table.insert(line, element)
            lineWidth = lineWidth + element.totalWidth
        else
            lineIsEmpty = lineIsEmpty and element:canCollapse()
            if lineIsEmpty and not element:isCollapsed() then
                element = text.TextFragment:NewCollapsed(element)
            end
            table.insert(line, element)
            lineWidth = lineWidth + element.totalWidth
        end
    end

    if #line > 0 then
        pushLine()
    end

    self:_joinLines()

    local contentSize = Vec2:New(maxLineWidth, totalHeight)
    return contentSize, contentSize -- XXX: no overflow?
end

function ns.TextBox:_joinLines()
    for _, line in ipairs(self._lines) do
        local j = 0
        local canMerge = false
        for _, element in ipairs(line) do
            -- Skip empty elements.
            if
                not element.hasStarts
                and not element.hasEnds
                and (-1e-9 < element.totalWidth and element.totalWidth < 1e-9)
            then
                goto continue
            end
            -- Join text fragments from the same parent to speed things up.
            if element and class.isChildOf(element, text.TextFragment) then
                --- @cast element ammgui._impl.layout.text.TextFragment
                if
                    canMerge
                    and not element.hasStarts
                    and line[j].parent == element.parent
                then
                    line[j] = text.TextFragment.merge(
                        line[j] --[[ @as ammgui._impl.layout.text.TextFragment ]],
                        element
                    )
                else
                    canMerge = not element.hasEnds
                    j = j + 1
                    line[j] = element
                end
            else
                canMerge = false
                j = j + 1
                line[j] = element
            end
            ::continue::
        end
        j = j + 1
        line[j] = nil
    end
end

function ns.TextBox:draw(ctx)
    local y = self.usedLayout.contentPosition.y
    for _, line in ipairs(self._lines) do
        local x = self.usedLayout.contentPosition.x
        y = y + line.heightA
        for _, element in ipairs(line) do
            local l, r = x, x + element.totalWidth
            for i = #element.resolvedBoxData, 1, -1 do
                local resolvedBoxData = element.resolvedBoxData[i]

                l = l + resolvedBoxData.marginLeft
                r = r - resolvedBoxData.marginRight

                local pos = Vec2:New(
                    l,
                    y
                    - resolvedBoxData.outlineWidth
                    - resolvedBoxData.paddingTop
                    - element.resolvedHeightA
                )
                local size = Vec2:New(
                    r - l,
                    2 * resolvedBoxData.outlineWidth
                    + resolvedBoxData.paddingTop
                    + element.resolvedHeightA
                    + element.resolvedHeightB
                    + resolvedBoxData.paddingBottom
                )

                self.drawContainer(
                    ctx,
                    pos,
                    size,
                    resolvedBoxData.parent.css.backgroundColor,
                    resolvedBoxData.outlineWidth,
                    resolvedBoxData.parent.css.outlineTint,
                    resolvedBoxData.outlineRadius,
                    resolvedBoxData.isStart,
                    resolvedBoxData.isEnd
                )

                if resolvedBoxData.nodeEventListener then
                    ctx:pushEventListener(
                        pos,
                        size,
                        resolvedBoxData.nodeEventListener
                    )
                    ctx:noteDebugTarget(
                        pos,
                        size,
                        layout.ElementDebugTarget:New(element, size, resolvedBoxData),
                        resolvedBoxData.nodeEventListener.id
                    )
                end

                l = l + resolvedBoxData.paddingLeft
                if resolvedBoxData.isStart then
                    l = l + resolvedBoxData.outlineWidth
                end
                r = r - resolvedBoxData.paddingRight
                if resolvedBoxData.isEnd then
                    r = r - resolvedBoxData.outlineWidth
                end
            end

            local visible = ctx:pushLayout(
                Vec2:New(l, y - element.resolvedHeightA),
                Vec2:New(r - l, element.resolvedHeightA + element.resolvedHeightB),
                not element.parent.css:overflowVisible()
            )
            if visible then
                element:draw(ctx)
            end
            ctx:popLayout()

            x = x + element.totalWidth
        end
        y = y + line.heightB
    end
end

--- @private
--- @return ammgui._impl.layout.Element[]
function ns.TextBox:_makeElements()
    local elements = {}

    --- @type ammgui._impl.layout.Element?
    local collapsedElement = nil

    local function mergeCollapsedBoxData(element)
        if not collapsedElement then
            collapsedElement = element:withCopiedBoxData()
        else
            local l = collapsedElement.boxData
            local r = element.boxData
            if fun.a.eq(l, r, fun.get("parent")) then
                -- Same set of spans on left and right. We simply
                -- adjust ``isEnd`` in case some span ended at the `element`.
                for i = 1, #l do
                    if r[i].isEnd and not l[i].isEnd then
                        ---@diagnostic disable-next-line: assign-type-mismatch <- wtf luals =(((
                        l[i] = fun.t.update(fun.t.copy(l[i]), { isEnd = true })
                    end
                end
            else
                -- We've found a ``<span>`` boundary.
                -- We need to push current element and make a new collapsed one.
                table.insert(elements, collapsedElement)
                collapsedElement = text.TextFragment:NewCollapsed(element)
            end
        end
    end

    for _, child in ipairs(self.children) do
        for _, element in ipairs(child:asInline()) do
            if element:canCollapse() then
                mergeCollapsedBoxData(element)
            else
                if collapsedElement then
                    table.insert(elements, collapsedElement)
                    collapsedElement = nil
                end
                table.insert(elements, element)
            end
        end
    end

    if collapsedElement then
        table.insert(elements, collapsedElement)
        collapsedElement = nil
    end

    -- Collapse elements around new lines.
    local firstNonCollapsed = 1
    for i = 1, #elements do
        if i >= firstNonCollapsed and elements[i]:isLineBreak() then
            for j = i - 1, firstNonCollapsed, -1 do
                if elements[j]:canCollapse() then
                    if not elements[j]:isCollapsed() then
                        elements[j] = text.TextFragment:NewCollapsed(elements[j])
                    end
                else
                    break
                end
            end
            firstNonCollapsed = i
            for j = i + 1, #elements do
                if elements[j]:canCollapse() then
                    if not elements[j]:isCollapsed() then
                        elements[j] = text.TextFragment:NewCollapsed(elements[j])
                    end
                else
                    firstNonCollapsed = j
                    break
                end
            end
        end
    end
    for j = #elements, firstNonCollapsed, -1 do
        if elements[j]:canCollapse() then
            if not elements[j]:isCollapsed() then
                elements[j] = text.TextFragment:NewCollapsed(elements[j])
            end
        else
            break
        end
    end

    return elements
end

return ns
