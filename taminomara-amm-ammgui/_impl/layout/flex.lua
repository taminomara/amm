local class = require "ammcore.class"
local base = require "ammgui._impl.layout.node"

--- Flex layout.
---
--- !doctype module
--- @class ammgui._impl.layout.flex
local ns = {}

--- Flex layout.
---
--- @class ammgui._impl.layout.flex.Flex: ammgui._impl.layout.node.Node
ns.Flex = class.create("Flex", base.Node)

function ns.Flex:calculateIntrinsicContentWidth()
    local minContentWidth, maxContentWidth = 0, 0
    local columnGap = self._resolvePercentage(self.css.columnGap, 0)

    for i, child in ipairs(self._blockChildren) do
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
        self._mainGap = self._resolvePercentage(self.css.columnGap, availableWidth or 0)
        self._crossGap = self._resolvePercentage(self.css.rowGap, availableHeight or 0)
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
        self._mainGap = self._resolvePercentage(self.css.rowGap, availableHeight or 0)
        self._crossGap = self._resolvePercentage(self.css.columnGap, availableWidth or 0)
    end

    self:_calculateHypotheticalMainSizes(availableWidth, availableHeight)
    if self.css.flexWrap == "wrap" then
        self:_flowLines()
    else
        self:_collectSingleLine()
    end

    local totalCrossSize = 0
    for _, line in ipairs(self._lines) do
        local lineCrossSize, lineCrossSizeA, lineCrossSizeB =
            self:_estimateLineCrossSize(line, availableWidth, availableHeight)

        line.lineCrossSize = line.lineCrossSize or math.max(
            lineCrossSize, lineCrossSizeA + lineCrossSizeB
        )

        local leading = line.lineCrossSize - lineCrossSizeA - lineCrossSizeB
        line.lineCrossSizeA = lineCrossSizeA + leading / 2
        line.lineCrossSizeB = lineCrossSizeB + leading / 2

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

    local contentSize = Vec2:FromTable {
        [self._mainSizeCoord] = contentMainSize,
        [self._crossSizeCoord] = contentCrossSize,
    }

    return contentSize, self:_calculateActualContentSize()
end

--- @param availableWidth number?
--- @param availableHeight number?
function ns.Flex:_calculateHypotheticalMainSizes(availableWidth, availableHeight)
    --- @type table<any, { outerMainSizeAdjustment: number, baseMainSize: number, hypotheticalMainSize: number, targetMainSize: number?, frozen: boolean, isMinViolation: boolean?, isMaxViolation: boolean?, position: ammgui.Vec2?, flexFactor: number? }>
    self._childLayout = {}

    for _, child in ipairs(self._blockChildren) do
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

        --- @type ammgui._impl.layout.blockBase.HorizontalLayout | ammgui._impl.layout.blockBase.VerticalLayout
        local mainSizeLayout = child[self._mainSizeLayoutFunctionName](
            child, availableWidth, availableHeight, child.baseLayout, baseMainSize
        )
        child[self._mainSizeLayoutName] = mainSizeLayout

        --- @type ammgui._impl.layout.blockBase.HorizontalLayout | ammgui._impl.layout.blockBase.VerticalLayout
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
    --- @type { [integer]: ammgui._impl.layout.blockBase.BlockBase, lineCrossSize: number?, lineCrossSizeA: number?, lineCrossSizeB: number?, lineMainSize: number?, position: ammgui.Vec2? }[]
    self._lines = {}

    local columnGap = self._resolvePercentage(self.css.columnGap, self._availableMainSize or 0)
    local currentGap = 0
    local line = {}
    local lineMainSize = 0
    for _, child in ipairs(self._blockChildren) do
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
    for _, child in ipairs(self._blockChildren) do
        lineMainSize = lineMainSize + self._childLayout[child].hypotheticalMainSize
        table.insert(line, child)
    end

    if self._availableMainSize then
        local columnGap = self._resolvePercentage(self.css.columnGap, self._availableMainSize)
        local contentMainSize = math.max(0, self._availableMainSize - columnGap * math.max(0, #self._blockChildren - 1))

        self:_adjustFlexItems(contentMainSize, lineMainSize > contentMainSize)
        for _, child in ipairs(self._blockChildren) do
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
    for _, child in ipairs(self._blockChildren) do
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

    for _, child in ipairs(self._blockChildren) do
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
        for _, child in ipairs(self._blockChildren) do
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
        for _, child in ipairs(self._blockChildren) do
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
        for _, child in ipairs(self._blockChildren) do
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

--- @param line { [integer]: ammgui._impl.layout.blockBase.BlockBase, lineCrossSize: number? }
--- @param availableWidth any
--- @param availableHeight any
--- @return number lineCrossSize
--- @return number lineCrossSizeA
--- @return number lineCrossSizeB
function ns.Flex:_estimateLineCrossSize(line, availableWidth, availableHeight)
    local lineCrossSize = 0
    local lineCrossSizeA = 0
    local lineCrossSizeB = 0

    for _, child in ipairs(line) do
        local childUsedLayout = child:getLayout(availableWidth, availableHeight, true)

        local baselineOffset
        if self._crossSizeCoord == "y" then
            local alignSelf = child.css.alignSelf
            if alignSelf == "auto" then
                alignSelf = self.css.alignItems
            end
            if alignSelf == "first baseline" and child.textLayout.firstBaselineOffset then
                baselineOffset =
                    childUsedLayout[self._effectiveCrossMarginName].x
                    + childUsedLayout.contentPosition.y
                    + child.textLayout.firstBaselineOffset
            elseif alignSelf == "last baseline" and child.textLayout.lastBaselineOffset then
                baselineOffset =
                    childUsedLayout[self._effectiveCrossMarginName].x
                    + childUsedLayout.contentPosition.y
                    + child.textLayout.lastBaselineOffset
            end
        end

        local childHeight =
            childUsedLayout.resolvedBorderBoxSize[self._crossSizeCoord]
            + childUsedLayout[self._effectiveCrossMarginName].x
            + childUsedLayout[self._effectiveCrossMarginName].y

        if baselineOffset then
            lineCrossSizeA = math.max(lineCrossSizeA, baselineOffset)
            lineCrossSizeB = math.max(lineCrossSizeB, childHeight - baselineOffset)
        else
            lineCrossSize = math.max(lineCrossSize, childHeight)
        end
    end
    return lineCrossSize, lineCrossSizeA, lineCrossSizeB
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
                if not self._resolveAbsOrNil(childComputedCrossSize) then
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
                        childComputedCrossSize = { childSize[self._crossSizeCoord], "px" }
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
            local childSize = childUsedLayout.resolvedBorderBoxSize + Vec2:New(
                childUsedLayout.effectiveHorizontalMargin.x
                + childUsedLayout.effectiveHorizontalMargin.y,
                childUsedLayout.effectiveVerticalMargin.x
                + childUsedLayout.effectiveVerticalMargin.y
            )
            local childLayout = self._childLayout[child]
            if alignSelf == "safe start" then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = 0,
                }
            elseif alignSelf == "unsafe start" then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = 0,
                }
            elseif alignSelf == "safe center" then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = math.max(0, (line.lineCrossSize - childSize[self._crossSizeCoord]) / 2),
                }
            elseif alignSelf == "unsafe center" then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = (line.lineCrossSize - childSize[self._crossSizeCoord]) / 2,
                }
            elseif alignSelf == "safe end" then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = math.max(0, line.lineCrossSize - childSize[self._crossSizeCoord]),
                }
            elseif alignSelf == "unsafe end" then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = line.lineCrossSize - childSize[self._crossSizeCoord],
                }
            elseif self._crossSizeCoord == "y" and alignSelf == "first baseline" and child.textLayout.firstBaselineOffset then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] =
                        line.lineCrossSizeA
                        - child.textLayout.firstBaselineOffset
                        - childUsedLayout.contentPosition.y
                        - childUsedLayout.effectiveVerticalMargin.x,
                }
            elseif self._crossSizeCoord == "y" and alignSelf == "last baseline" and child.textLayout.lastBaselineOffset then
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] =
                        line.lineCrossSizeA
                        - child.textLayout.lastBaselineOffset
                        - childUsedLayout.contentPosition.y
                        - childUsedLayout.effectiveVerticalMargin.x,
                }
            else -- Fall back to safe center.
                childLayout.position = Vec2:FromTable {
                    [self._mainSizeCoord] = 0,
                    [self._crossSizeCoord] = math.max(0, (line.lineCrossSize - childSize[self._crossSizeCoord]) / 2),
                }
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
        line.position = Vec2:FromTable {
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

--- @return ammgui.Vec2
function ns.Flex:_calculateActualContentSize()
    local actualContentWidth, actualContentHeight = 0, 0
    for _, line in ipairs(self._lines) do
        for _, child in ipairs(line) do
            local childPosition = line.position + self._childLayout[child].position

            local contentOffset = child.usedLayout.contentPosition.y
            local firstBaselineOffset = child.textLayout.firstBaselineOffset or child.textLayout.lastBaselineOffset
            local lastBaselineOffset = child.textLayout.lastBaselineOffset or child.textLayout.firstBaselineOffset

            if firstBaselineOffset and not self.textLayout.firstBaselineOffset then
                self.textLayout.firstBaselineOffset =
                    childPosition.y + contentOffset + firstBaselineOffset
            end
            if lastBaselineOffset then
                self.textLayout.lastBaselineOffset =
                    childPosition.y + contentOffset + lastBaselineOffset
            end

            local rightBottomCorner = childPosition + child.usedLayout.visibleBorderBoxSize
            actualContentWidth = math.max(actualContentWidth, rightBottomCorner.x)
            actualContentHeight = math.max(actualContentHeight, rightBottomCorner.y)
        end
    end
    return Vec2:New(actualContentWidth, actualContentHeight)
end

function ns.Flex:drawContent(ctx, pos)
    for _, line in ipairs(self._lines) do
        for _, child in ipairs(line) do
            local visible = ctx:pushLayout(
                pos + line.position + self._childLayout[child].position,
                child.usedLayout.visibleBorderBoxSize,
                not child.css:overflowVisible()
            )
            if visible then
                child:draw(ctx)
            end
            ctx:popLayout()
        end
    end
end

function ns.Flex:drawDebugOverlay(ctx, drawContent, drawPadding, drawOutline, drawMargin)
    base.Node.drawDebugOverlay(self, ctx, drawContent, drawPadding, drawOutline, drawMargin)
    if drawContent then
        local position = self.usedLayout.contentPosition
        for _, line in ipairs(self._lines) do
            for _, child in ipairs(line) do
                local childMarginOffset = Vec2:New(
                    child.usedLayout.effectiveHorizontalMargin.x,
                    child.usedLayout.effectiveVerticalMargin.x
                )
                local childMarginSize = childMarginOffset + Vec2:New(
                    child.usedLayout.effectiveHorizontalMargin.y + 1,
                    child.usedLayout.effectiveVerticalMargin.y + 1
                )

                ctx.gpu:drawBox {
                    position = position + line.position + self._childLayout[child].position - childMarginOffset,
                    size = child.usedLayout.visibleBorderBoxSize + childMarginSize,
                    rotation = 0,
                    color = structs.Color { 0, 0, 0, 0 },
                    image = "",
                    imageSize = Vec2:New(0, 0),
                    hasCenteredOrigin = false,
                    horizontalTiling = false,
                    verticalTiling = false,
                    isBorder = false,
                    margin = { top = 0, right = 0, bottom = 0, left = 0 },
                    isRounded = true,
                    radii = structs.Vector4 { 0, 0, 0, 0 },
                    hasOutline = true,
                    outlineThickness = 1,
                    outlineColor = structs.Color { 0x66 / 0xFF, 0x00 / 0xFF, 0x66 / 0xFF, 1 },
                }
            end
        end
    end
end

return ns
