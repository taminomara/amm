local class = require "ammcore.class"
local base = require "ammgui._impl.layout.node"

--- Block layout.
---
--- !doctype module
--- @class ammgui._impl.layout.block
local ns = {}

--- Block layout.
---
--- @class ammgui._impl.layout.block.Block: ammgui._impl.layout.node.Node
ns.Block = class.create("Block", base.Node)

function ns.Block:calculateIntrinsicContentWidth()
    local minContentWidth, maxContentWidth = 0, 0

    for _, child in ipairs(self._blockChildren) do
        local childMinOuterWidth, childMaxOuterWidth = child:getExtrinsicOuterWidth()
        minContentWidth = math.max(minContentWidth, childMinOuterWidth)
        maxContentWidth = math.max(maxContentWidth, childMaxOuterWidth)
    end

    return minContentWidth, maxContentWidth, false
end

function ns.Block:calculateContentLayout(availableWidth, availableHeight)
    local trimTopMargin = self.css.marginTrim == "block" or self.css.marginTrim == "block-start"
    local trimBottomMargin = self.css.marginTrim == "block" or self.css.marginTrim == "block-end"

    local canCollapseTopMargin =
        self.baseLayout.paddingTop == 0
        and self.baseLayout.outlineWidth == 0
        and self.css:overflowVisible()
    local canCollapseBottomMargin =
        self.baseLayout.paddingBottom == 0
        and self.baseLayout.outlineWidth == 0
        and self.css:overflowVisible()
    local collapsedMarginTop, collapsedMarginBottom = nil, nil

    local maxContentWidth, maxActualContentWidth = 0, 0
    local currentY, maxActualContentHeight = 0, 0

    self._childPositions = {}

    local previousChildMarginBottom = 0

    for i, child in ipairs(self._blockChildren) do
        local childLayoutData = child:getLayout(availableWidth, availableHeight)

        if i > 1 then
            if previousChildMarginBottom > 0 and childLayoutData.effectiveVerticalMargin.x > 0 then
                currentY = currentY + math.max(
                    previousChildMarginBottom,
                    childLayoutData.effectiveVerticalMargin.x
                )
            elseif previousChildMarginBottom < 0 and childLayoutData.effectiveVerticalMargin.x < 0 then
                currentY = currentY + math.min(
                    previousChildMarginBottom,
                    childLayoutData.effectiveVerticalMargin.x
                )
            else
                currentY = currentY + previousChildMarginBottom + childLayoutData.effectiveVerticalMargin.x
            end
        elseif not trimTopMargin then
            if canCollapseTopMargin then
                collapsedMarginTop = childLayoutData.collapsedMarginTop
            else
                currentY = currentY + childLayoutData.effectiveVerticalMargin.x
            end
        end

        local contentOffset = child.usedLayout.contentPosition.y
        local firstBaselineOffset = child.textLayout.firstBaselineOffset or child.textLayout.lastBaselineOffset
        local lastBaselineOffset = child.textLayout.lastBaselineOffset or child.textLayout.firstBaselineOffset

        if firstBaselineOffset and not self.textLayout.firstBaselineOffset then
            self.textLayout.firstBaselineOffset =
                currentY + contentOffset + firstBaselineOffset
        end
        if lastBaselineOffset then
            self.textLayout.lastBaselineOffset =
                currentY + contentOffset + lastBaselineOffset
        end

        self._childPositions[child] = Vec2:New(
            childLayoutData.effectiveHorizontalMargin.x,
            currentY
        )

        maxActualContentHeight = math.max(
            maxActualContentHeight, currentY + childLayoutData.visibleBorderBoxSize.y
        )
        currentY = currentY + childLayoutData.resolvedBorderBoxSize.y

        maxContentWidth = math.max(
            maxContentWidth,
            childLayoutData.effectiveHorizontalMargin.x
            + childLayoutData.resolvedBorderBoxSize.x
            + childLayoutData.effectiveHorizontalMargin.y
        )
        maxActualContentWidth = math.max(
            maxActualContentWidth,
            childLayoutData.effectiveHorizontalMargin.x
            + childLayoutData.visibleBorderBoxSize.x
        )

        if i < #self._blockChildren then
            previousChildMarginBottom = childLayoutData.effectiveVerticalMargin.y
        elseif not trimBottomMargin then
            if canCollapseBottomMargin then
                collapsedMarginBottom = childLayoutData.collapsedMarginBottom
            else
                currentY = currentY + childLayoutData.effectiveVerticalMargin.y
            end
        end
    end

    return
        Vec2:New( maxContentWidth, currentY ),
        Vec2:New( maxActualContentWidth, maxActualContentHeight ),
        collapsedMarginTop,
        collapsedMarginBottom
end

function ns.Block:drawContent(ctx, pos)
    for _, child in ipairs(self._blockChildren) do
        local visible = ctx:pushLayout(
            pos + self._childPositions[child],
            child.usedLayout.visibleBorderBoxSize,
            not child.css:overflowVisible()
        )
        if visible then
            child:draw(ctx)
        end
        ctx:popLayout()
    end
end

return ns
