local class = require "ammcore.class"
local bcom = require "ammgui.component.block"
local util = require "ammgui.component.block.util"
local array= require "ammcore._util.array"

--- Flex component.
---
--- !doctype module
--- @class ammgui.component.block.flex
local ns = {}

--- Flex component.
---
--- @class ammgui.component.block.flex.Flex: ammgui.component.block.Component
ns.Flex = class.create("Flex", bcom.Component)

ns.Flex.elem = "flex"

--- @param data ammgui.dom.FlexNode
function ns.Flex:onMount(ctx, data)
    bcom.Component.onMount(self, ctx, data)

    --- @private
    --- @type ammgui.component.block.ComponentProvider[]
    self._providers = nil

    --- @private
    --- @type ammgui.component.block.Component[]
    self._children = nil

    self._providers, self._children = bcom.Component.syncAll(ctx, {}, {}, data, self)
end

--- @param data ammgui.dom.FlexNode
function ns.Flex:onUpdate(ctx, data)
    bcom.Component.onUpdate(self, ctx, data)
    local providers, children, outdated, outdatedCss = bcom.Component.syncAll(ctx, self._providers, self._children, data,
        self)
    self._providers = providers
    self._children = children
    self.outdated = self.outdated or outdated
    self.outdatedCss = self.outdatedCss or outdatedCss
end

function ns.Flex:propagateCssChanges(ctx)
    for _, child in ipairs(self._children) do
        child:updateCss(ctx)
        self.outdated = self.outdated or child.outdated
    end
end

function ns.Flex:prepareLayout(textMeasure)
    bcom.Component.prepareLayout(self, textMeasure)
    for _, child in ipairs(self._children) do
        if child.outdated then
            child:prepareLayout(textMeasure)
        end
    end
end

function ns.Flex:calculateIntrinsicContentWidth()
    local minContentWidth, maxContentWidth = 0, 0
    local columnGap = util.resolvePercentage(self.css.columnGap, 0)

    for i, child in ipairs(self._children) do
        if i > 1 then
            if self.css.flexWrap == "wrap" then
                maxContentWidth = maxContentWidth + columnGap
            else
                minContentWidth = minContentWidth + columnGap
                maxContentWidth = maxContentWidth + columnGap
            end
        end

        local childMinOuterWidth, childMaxOuterWidth = child:getExtrinsicOuterWidth()

        if self.css.flexWrap == "wrap" then
            minContentWidth = math.max(minContentWidth, childMinOuterWidth)
            maxContentWidth = maxContentWidth + childMaxOuterWidth
        else
            minContentWidth = minContentWidth + childMinOuterWidth
            maxContentWidth = maxContentWidth + childMaxOuterWidth
        end
    end

    return minContentWidth, maxContentWidth, false
end

function ns.Flex:calculateContentLayout(availableWidth, availableHeight)
    -- According to css-flexbox-1, §9

    if self.css.flexDirection == "row" then
        self._availableMainSize = availableWidth
        self._availableCrossSize = availableHeight
        self._mainSizeCoord = "x"
        self._crossSizeCoord = "y"
        self._mainSizeName = "width"
        self._crossSizeName = "height"
        self._mainSizeLayoutName = "horizontalLayout"
        self._crossSizeLayoutName = "verticalLayout"
        self._mainSizeLayoutFunctionName = "determineHorizontalLayout"
        self._crossSizeLayoutFunctionName = "determineVerticalLayout"
        self._effectiveMainMarginName = "effectiveHorizontalMargin"
        self._effectiveCrossMarginName = "effectiveVerticalMargin"
        self._mainGap = util.resolvePercentage(self.css.columnGap, availableWidth or 0)
        self._crossGap = util.resolvePercentage(self.css.rowGap, availableHeight or 0)
    else
        self._availableMainSize = availableHeight
        self._availableCrossSize = availableWidth
        self._mainSizeCoord = "y"
        self._crossSizeCoord = "x"
        self._mainSizeName = "height"
        self._crossSizeName = "width"
        self._mainSizeLayoutName = "verticalLayout"
        self._crossSizeLayoutName = "horizontalLayout"
        self._mainSizeLayoutFunctionName = "determineVerticalLayout"
        self._crossSizeLayoutFunctionName = "determineHorizontalLayout"
        self._effectiveMainMarginName = "effectiveVerticalMargin"
        self._effectiveCrossMarginName = "effectiveHorizontalMargin"
        self._mainGap = util.resolvePercentage(self.css.rowGap, availableHeight or 0)
        self._crossGap = util.resolvePercentage(self.css.columnGap, availableWidth or 0)
    end

    self:_calculateHypotheticalMainSizes(availableWidth, availableHeight)
    if self.css.flexWrap == "wrap" then
        self:_flowLines()
    else
        self:_collectSingleLine()
    end

    local totalCrossSize = 0
    for _, line in ipairs(self._lines) do
        line.lineCrossSize = line.lineCrossSize or self:_estimateLineCrossSize(line, availableWidth, availableHeight)
        totalCrossSize = totalCrossSize + line.lineCrossSize
    end

    local freeCrossSpace = 0
    if self._availableCrossSize then
        local contentCrossSize = math.max(0, self._availableCrossSize - self._crossGap * math.max(0, #self._lines - 1))
        freeCrossSpace = contentCrossSize - totalCrossSize
        if freeCrossSpace > 0 and self.css.alignContent == "stretch" then
            for _, line in ipairs(self._lines) do
                line.lineCrossSize = line.lineCrossSize + freeCrossSpace / #self._lines
            end
            freeCrossSpace = 0
        end
    end

    self:_alignItems(availableWidth, availableHeight)
    local contentCrossSize = self:_alignContent(freeCrossSpace)
    local contentMainSize = self:_justifyItems()

    local contentSize = structs.Vector2D {
        [self._mainSizeCoord] = contentMainSize,
        [self._crossSizeCoord] = contentCrossSize,
    }

    return contentSize, self:_calculateActualContentSize()
end

--- @param availableWidth number?
--- @param availableHeight number?
function ns.Flex:_calculateHypotheticalMainSizes(availableWidth, availableHeight)
    --- @type table<any, { outerMainSizeAdjustment: number, baseMainSize: number, hypotheticalMainSize: number, targetMainSize: number?, frozen: boolean, isMinViolation: boolean?, isMaxViolation: boolean?, position: Vector2D?, flexFactor: number? }>
    self._childLayout = {}

    for _, child in ipairs(self._children) do
        local baseMainSize = child.css.flexBasis
        if baseMainSize == "auto" then
            baseMainSize = child.css[self._mainSizeName]
            if baseMainSize == "auto" then
                -- TODO: handle aspect ratio and orthogonal flow here
                if self.css[self._mainSizeName] == "min-content" then
                    baseMainSize = "min-content"
                else
                    baseMainSize = "max-content"
                end
            end
        end
        local baseCrossSize = child.css[self._crossSizeName]
        if baseCrossSize == "auto" then
            baseCrossSize = "fit-content"
        end

        child.baseLayout = child:determineBaseLayout(availableWidth, availableHeight)

        --- @type ammgui.component.block.HorizontalLayout | ammgui.component.block.VerticalLayout
        local mainSizeLayout = child[self._mainSizeLayoutFunctionName](
            child, availableWidth, availableHeight, child.baseLayout, baseMainSize
        )
        child[self._mainSizeLayoutName] = mainSizeLayout

        --- @type ammgui.component.block.HorizontalLayout | ammgui.component.block.VerticalLayout
        local crossSizeLayout = child[self._crossSizeLayoutFunctionName](
            child, availableWidth, availableHeight, child.baseLayout, baseCrossSize
        )
        child[self._crossSizeLayoutName] = crossSizeLayout

        child.usedLayout = nil

        local potentialContentMainSize = mainSizeLayout.potentialContentSize
        local resolvedContentMainSize = mainSizeLayout.resolvedContentSize

        if not potentialContentMainSize or not resolvedContentMainSize then
            local usedLayout = child:getLayout(availableWidth, availableHeight, true)
            potentialContentMainSize = usedLayout.potentialContentSize[self._mainSizeCoord]
            resolvedContentMainSize = usedLayout.resolvedContentSize[self._mainSizeCoord]
        end

        local outerMainSizeAdjustment
        if self.css.flexDirection == "row" then
            outerMainSizeAdjustment =
                (child.baseLayout.marginLeft or 0)
                + child.baseLayout.paddingLeft
                + child.baseLayout.paddingRight
                + (child.baseLayout.marginRight or 0)
                + 2 * child.baseLayout.outlineWidth
        else
            outerMainSizeAdjustment =
                (child.baseLayout.marginTop or 0)
                + child.baseLayout.paddingTop
                + child.baseLayout.paddingBottom
                + (child.baseLayout.marginBottom or 0)
                + 2 * child.baseLayout.outlineWidth
        end

        self._childLayout[child] = {
            outerMainSizeAdjustment = outerMainSizeAdjustment,
            baseMainSize = potentialContentMainSize + outerMainSizeAdjustment,
            hypotheticalMainSize = resolvedContentMainSize + outerMainSizeAdjustment,
            frozen = false,
        }
    end
end

function ns.Flex:_flowLines()
    --- @type { [integer]: ammgui.component.block.Component, lineCrossSize: number?, lineMainSize: number?, position: Vector2D? }[]
    self._lines = {}

    local columnGap = util.resolvePercentage(self.css.columnGap, self._availableMainSize or 0)
    local currentGap = 0
    local line = {}
    local lineMainSize = 0
    for _, child in ipairs(self._children) do
        local childLayout = self._childLayout[child]
        childLayout.targetMainSize = childLayout.hypotheticalMainSize
        childLayout.frozen = true
        local childMainSize = currentGap + childLayout.targetMainSize
        if self._availableMainSize and lineMainSize + childMainSize > self._availableMainSize then
            if #line > 0 then
                table.insert(self._lines, line)
            end

            line = { child }
            lineMainSize = childLayout.targetMainSize
            currentGap = columnGap
        else
            table.insert(line, child)
            lineMainSize = lineMainSize + childMainSize
            currentGap = columnGap
        end
    end
    if #line > 0 then
        table.insert(self._lines, line)
    end
end

function ns.Flex:_collectSingleLine()
    local lineMainSize = 0
    local line = { lineCrossSize = self._availableCrossSize }
    for _, child in ipairs(self._children) do
        lineMainSize = lineMainSize + self._childLayout[child].hypotheticalMainSize
        table.insert(line, child)
    end

    if self._availableMainSize then
        local columnGap = util.resolvePercentage(self.css.columnGap, self._availableMainSize)
        local contentMainSize = math.max(0, self._availableMainSize - columnGap * math.max(0, #self._children - 1))

        self:_adjustFlexItems(contentMainSize, lineMainSize > contentMainSize)
        for _, child in ipairs(self._children) do
            local childLayout = self._childLayout[child]
            child[self._mainSizeLayoutName].resolvedContentSize =
                childLayout.targetMainSize - childLayout.outerMainSizeAdjustment
            child.usedLayout = nil
        end
    end

    self._lines = { line }
end

--- @param contentMainSize number
function ns.Flex:_adjustFlexItems(contentMainSize, isShrink)
    for _, child in ipairs(self._children) do
        local childLayout = self._childLayout[child]
        if
            (
                not isShrink and (
                    child.css.flexGrow < 1e-9
                    or childLayout.baseMainSize > childLayout.hypotheticalMainSize
                )
            ) or (
                isShrink and (
                    child.css.flexShrink < 1e-9
                    or childLayout.baseMainSize < childLayout.hypotheticalMainSize
                )
            )
        then
            childLayout.targetMainSize = childLayout.hypotheticalMainSize
            childLayout.frozen = true
        end
    end

    for _, child in ipairs(self._children) do
        local childLayout = self._childLayout[child]
        if isShrink then
            childLayout.flexFactor = child.css.flexShrink * (
                childLayout.baseMainSize - childLayout.outerMainSizeAdjustment
            )
        else
            childLayout.flexFactor = child.css.flexGrow
        end
    end

    while true do
        local hasUnfrozenItems = false
        local remainingFreeSpace = contentMainSize
        local totalFlexFactor = 0
        for _, child in ipairs(self._children) do
            local childLayout = self._childLayout[child]
            if not childLayout.frozen then
                hasUnfrozenItems = true
                remainingFreeSpace = remainingFreeSpace - childLayout.baseMainSize
                totalFlexFactor = totalFlexFactor + childLayout.flexFactor
            else
                remainingFreeSpace = remainingFreeSpace - childLayout.targetMainSize
            end
        end
        if not hasUnfrozenItems then
            break
        end
        local totalViolation = 0
        for _, child in ipairs(self._children) do
            local childLayout = self._childLayout[child]
            if not childLayout.frozen then
                local unclampedTargetWidth = childLayout.baseMainSize +
                    remainingFreeSpace * (childLayout.flexFactor / totalFlexFactor)
                childLayout.targetMainSize = childLayout.outerMainSizeAdjustment +
                    math.max(child[self._mainSizeLayoutName].resolvedContentMinSize,
                        math.min(math.max(0, unclampedTargetWidth - childLayout.outerMainSizeAdjustment),
                            child[self._mainSizeLayoutName].resolvedContentMaxSize))
                totalViolation = totalViolation + childLayout.targetMainSize - unclampedTargetWidth
                childLayout.isMinViolation = unclampedTargetWidth < childLayout.targetMainSize
                childLayout.isMaxViolation = unclampedTargetWidth > childLayout.targetMainSize
            end
        end
        local freezeAllItems = -1e-9 < totalViolation and totalViolation < 1e-9
        local freezeMinViolatedItems = totalViolation > 0
        local freezeMaxViolatedItems = totalViolation < 0
        for _, child in ipairs(self._children) do
            local childLayout = self._childLayout[child]
            childLayout.frozen = childLayout.frozen
                or freezeAllItems
                or (childLayout.isMinViolation and freezeMinViolatedItems)
                or (childLayout.isMaxViolation and freezeMaxViolatedItems)
                or false
            hasUnfrozenItems = hasUnfrozenItems or not childLayout.frozen
        end
        if not hasUnfrozenItems then
            break
        end
    end
end

--- @param line { [integer]: ammgui.component.block.Component, lineCrossSize: number? }
--- @param availableWidth any
--- @param availableHeight any
function ns.Flex:_estimateLineCrossSize(line, availableWidth, availableHeight)
    local lineCrossSize = 0

    for _, child in ipairs(line) do
        local childUsedLayout = child:getLayout(availableWidth, availableHeight, true)
        lineCrossSize = math.max(
            lineCrossSize,
            childUsedLayout.resolvedBorderBoxSize[self._crossSizeCoord]
            + childUsedLayout[self._effectiveCrossMarginName].x
            + childUsedLayout[self._effectiveCrossMarginName].y
        )
    end
    return lineCrossSize
end

--- @param availableWidth number?
--- @param availableHeight number?
function ns.Flex:_alignItems(availableWidth, availableHeight)
    local crossMarginNameA, crossMarginNameB
    if self.css.flexDirection == "row" then
        crossMarginNameA, crossMarginNameB = "marginTop", "marginBottom"
    else
        crossMarginNameA, crossMarginNameB = "marginLeft", "marginRight"
    end

    for _, line in ipairs(self._lines) do
        local lineMainSize = 0
        for _, child in ipairs(line) do
            local alignSelf = child.css.alignSelf
            if alignSelf == "auto" then
                alignSelf = self.css.alignItems
            end
            if alignSelf == "stretch" then
                local childUsedLayout = child:getLayout(availableWidth, availableHeight, true)
                local childComputedCrossSize = child.css[self._crossSizeName]
                if not util.resolveAbsOrNil(childComputedCrossSize) then
                    if
                        childComputedCrossSize == "auto"
                        and child.css[crossMarginNameA] ~= "auto"
                        and child.css[crossMarginNameB] ~= "auto"
                    then
                        childComputedCrossSize = {
                            math.max(
                                0,
                                line.lineCrossSize
                                - childUsedLayout[self._effectiveCrossMarginName].x
                                - childUsedLayout[self._effectiveCrossMarginName].y
                            ),
                            "px",
                        }
                    else
                        local childSize = childUsedLayout.resolvedBorderBoxSize
                        childComputedCrossSize = { childSize.y, "px" }
                    end
                    -- force recalculation according to css-flexbox-1, 9.4.11
                    child[self._crossSizeLayoutName] = child[self._crossSizeLayoutFunctionName](
                        child, availableWidth, availableHeight, child.baseLayout, childComputedCrossSize
                    )
                    child.usedLayout = nil
                end
                alignSelf = "safe start"
            end
            local childUsedLayout = child:getLayout(availableWidth, availableHeight, true)
            local childSize = childUsedLayout.resolvedBorderBoxSize + structs.Vector2D {
                childUsedLayout.effectiveHorizontalMargin.x
                + childUsedLayout.effectiveHorizontalMargin.y,
                childUsedLayout.effectiveVerticalMargin.x
                + childUsedLayout.effectiveVerticalMargin.y,
            }
            local childLayout = self._childLayout[child]
            if alignSelf == "safe start" then
                childLayout.position = structs.Vector2D {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = 0,
                }
            elseif alignSelf == "unsafe start" then
                childLayout.position = structs.Vector2D {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = 0,
                }
            elseif alignSelf == "safe center" then
                childLayout.position = structs.Vector2D {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = math.max(0, (line.lineCrossSize - childSize[self._crossSizeCoord]) / 2),
                }
            elseif alignSelf == "unsafe center" then
                childLayout.position = structs.Vector2D {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = (line.lineCrossSize - childSize[self._crossSizeCoord]) / 2,
                }
            elseif alignSelf == "safe end" then
                childLayout.position = structs.Vector2D {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = math.max(0, line.lineCrossSize - childSize[self._crossSizeCoord]),
                }
            elseif alignSelf == "unsafe end" then
                childLayout.position = structs.Vector2D {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = line.lineCrossSize - childSize[self._crossSizeCoord],
                }
            -- TODO:
            -- elseif alignSelf == "first baseline" then
            -- elseif alignSelf == "last baseline" then
            else
                childLayout.position = structs.Vector2D { 0, 0 }
            end
            childLayout.position[self._crossSizeCoord] =
                childLayout.position[self._crossSizeCoord]
                + childUsedLayout[self._effectiveCrossMarginName].x
            lineMainSize = lineMainSize + childSize[self._mainSizeCoord]
        end
        line.lineMainSize = lineMainSize
    end
end

--- @param freeCrossSpace number
--- @return number
function ns.Flex:_alignContent(freeCrossSpace)
    local crossSpaceBefore, crossSpaceBetween, crossSpaceAfter = 0, self._crossGap, 0

    if self.css.alignContent == "start" or self.css.alignContent == "stretch" then
        crossSpaceAfter = freeCrossSpace
    elseif self.css.alignContent == "center" then
        crossSpaceBefore = freeCrossSpace / 2
        crossSpaceAfter = freeCrossSpace - crossSpaceBefore
    elseif self.css.alignContent == "end" then
        crossSpaceBefore = freeCrossSpace
    elseif self.css.alignContent == "space-between" then
        if #self._lines >= 2 then
            local additionalGap = freeCrossSpace / (#self._lines - 1)
            crossSpaceBetween = crossSpaceBetween + additionalGap
        end
    elseif self.css.alignContent == "space-around" then
        if #self._lines >= 1 then
            local additionalGap = freeCrossSpace / #self._lines
            crossSpaceBefore = additionalGap / 2
            crossSpaceAfter = additionalGap - crossSpaceBefore
            crossSpaceBetween = crossSpaceBetween + additionalGap
        end
    elseif self.css.alignContent == "space-evenly" then
        if #self._lines >= 1 then
            local additionalGap = freeCrossSpace / (#self._lines + 1)
            crossSpaceBefore = additionalGap
            crossSpaceAfter = additionalGap
            crossSpaceBetween = crossSpaceBetween + additionalGap
        end
    end

    local pos = crossSpaceBefore
    for i, line in ipairs(self._lines) do
        if i > 1 then
            pos = pos + crossSpaceBetween
        end
        line.position = structs.Vector2D {
            [self._mainSizeCoord] = 0,
            [self._crossSizeCoord] = pos,
        }
        pos = pos + line.lineCrossSize
    end

    return pos + crossSpaceAfter
end

--- @return number
function ns.Flex:_justifyItems()
    local maxMainSize = 0
    local availableMainSize = self._availableMainSize or 0
    for _, line in ipairs(self._lines) do
        local contentMainSize = math.max(0, availableMainSize - self._mainGap * math.max(0, #line - 1))
        local freeMainSize = math.max(0, contentMainSize - line.lineMainSize)
        local crossSpaceBefore, crossSpaceBetween, crossSpaceAfter = 0, self._mainGap, 0

        if self.css.justifyContent == "start" or self.css.justifyContent == "stretch" then
            crossSpaceAfter = freeMainSize
        elseif self.css.justifyContent == "center" then
            crossSpaceBefore = freeMainSize / 2
            crossSpaceAfter = freeMainSize - crossSpaceBefore
        elseif self.css.justifyContent == "end" then
            crossSpaceBefore = freeMainSize
        elseif self.css.justifyContent == "space-between" then
            if #line >= 2 then
                local additionalGap = freeMainSize / (#line - 1)
                crossSpaceBetween = crossSpaceBetween + additionalGap
            end
        elseif self.css.justifyContent == "space-around" then
            if #line >= 1 then
                local additionalGap = freeMainSize / #line
                crossSpaceBefore = additionalGap / 2
                crossSpaceAfter = additionalGap - crossSpaceBefore
                crossSpaceBetween = crossSpaceBetween + additionalGap
            end
        elseif self.css.justifyContent == "space-evenly" then
            if #line >= 1 then
                local additionalGap = freeMainSize / (#line + 1)
                crossSpaceBefore = additionalGap
                crossSpaceAfter = additionalGap
                crossSpaceBetween = crossSpaceBetween + additionalGap
            end
        end

        local pos = crossSpaceBefore
        for i, child in ipairs(line) do
            if i > 1 then
                pos = pos + crossSpaceBetween
            end
            pos = pos + child.usedLayout[self._effectiveMainMarginName].x
            self._childLayout[child].position[self._mainSizeCoord] = pos
            pos = pos + child.usedLayout.resolvedBorderBoxSize[self._mainSizeCoord]
            pos = pos + child.usedLayout[self._effectiveMainMarginName].y
        end
        maxMainSize = math.max(maxMainSize, pos + crossSpaceAfter)
    end
    return maxMainSize
end

--- @return Vector2D
function ns.Flex:_calculateActualContentSize()
    local actualContentWidth, actualContentHeight = 0, 0
    for _, line in ipairs(self._lines) do
        for _, child in ipairs(line) do
            local rightBottomCorner =
                line.position
                + self._childLayout[child].position
                + child.usedLayout.visibleBorderBoxSize
            actualContentWidth = math.max(actualContentWidth, rightBottomCorner.x)
            actualContentHeight = math.max(actualContentHeight, rightBottomCorner.y)
        end
    end
    return structs.Vector2D { actualContentWidth, actualContentHeight }
end

function ns.Flex:draw(ctx)
    bcom.Component.draw(self, ctx)

    local position = self.usedLayout.contentPosition
    for _, line in ipairs(self._lines) do
        for _, child in ipairs(line) do
            local visible = ctx:pushLayout(
                position + line.position + self._childLayout[child].position,
                child.usedLayout.visibleBorderBoxSize,
                child.css.overflow == "hidden"
            )
            if visible then
                child:draw(ctx)
            end
            ctx:popLayout()
        end
    end
end

function ns.Flex:reprChildren()
    return array.map(self._children, function (x) return x:repr() end)
end

return ns
