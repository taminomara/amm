local class = require "ammcore.class"
local log = require "ammcore.log"
local array = require "ammcore._util.array"
local base = require "ammgui.component.base"
local util = require "ammgui.component.block.util"
local defer = require "ammcore.defer"

--- Components that implement block DOM nodes.
---
--- !doctype module
--- @class ammgui.component.block
local ns = {}

local logger = log.Logger:New()

local function runEventHandler(handler, ...)
    local result = nil
    if handler then
        local ok, err = defer.xpcall(function(...) result = handler(...) end, ...)
        if not ok then
            logger:error("Error in event handler: %s\n%s", err.message, err.trace)
        end
    end
    return result
end

--- An interface that abstracts over a single component and a list of components.
---
--- @class ammgui.component.block.ComponentProvider: ammcore.class.Base
ns.ComponentProvider = class.create("ComponentProvider")

--- @param key integer | string | nil
---
--- !doctype classmethod
--- @generic T: ammgui.component.block.ComponentProvider
--- @param self T
--- @return T
function ns.ComponentProvider:New(key)
    self = class.Base.New(self)

    --- Key for synchronizing arrays of nodes.
    ---
    --- @type integer | string | nil
    self.key = key

    return self
end

--- Called when component is initialized.
---
--- !doc abstract
--- @param data ammgui.dom.block.Node user-provided component data.
function ns.ComponentProvider:onMount(ctx, data)
    error("not implemented")
end

--- Called when component is updated.
---
--- !doc abstract
--- @param data ammgui.dom.block.Node user-provided component data.
function ns.ComponentProvider:onUpdate(ctx, data)
    error("not implemented")
end

--- Called when component is destroyed.
---
--- !doc abstract
function ns.ComponentProvider:onUnmount(ctx)
    error("not implemented")
end

--- Called to collect actual component implementations.
---
--- Should add actual component implementations to the given array.
---
--- @param components ammgui.component.block.Component[]
function ns.ComponentProvider:collect(components)
    error("not implemented")
end

--- Process a reference.
---
--- @param ref ammgui.component.block.func.Ref<ammgui.component.block.Component?>
function ns.ComponentProvider:noteRef(ref)
    error("not implemented")
end

--- Base for all block components.
---
--- @class ammgui.component.block.Component: ammgui.component.base.Component, ammgui.component.block.ComponentProvider, ammgui.eventManager.EventListener
ns.Component = class.create("Component", base.Component)

--- Name of a DOM node that corresponds to this component.
---
--- !doc const
--- !doctype classattribute
--- @type string
ns.Component.elem = nil


--- Contains base metrics calculated during the layout step.
---
--- @class ammgui.component.block.BaseLayout
--- @field isReplaced boolean indicates whether this is a "replaced" element (i.e. an image) or an actual block.
--- @field preferredAspectRatio number? preferred aspect ratio of a replaced element.
--- @field outlineWidth number resolved outline width, in pixels.
--- @field outlineRadius number resolved outline radius, in pixels.
--- @field paddingTop number resolved top padding.
--- @field paddingRight number resolved right padding.
--- @field paddingBottom number resolved bottom padding.
--- @field paddingLeft number resolved left padding.
--- @field marginTop number resolved top margin.
--- @field marginRight number? resolved right margin, `nil` if ``"auto"``.
--- @field marginBottom number resolved bottom margin.
--- @field marginLeft number? resolved left margin, `nil` if ``"auto"``.

--- Contains metrics for horizontal component layout.
---
--- At the stage when these are calculated, final component's dimensions
--- are not yet known. However, since AmmGui only uses vertical writing mode,
--- all widths are actually resolved at this step.
---
--- @class ammgui.component.block.HorizontalLayout
--- @field usedSize [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto" the actual algorithm that was used to calculate width.
--- @field usedMinSize [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto" the actual algorithm that was used to calculate min width.
--- @field usedMaxSize [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto" the actual algorithm that was used to calculate max width.
--- @field resolvedContentMinSize number resolved min width of the component's content.
--- @field resolvedContentMaxSize number resolved max width of the component's content.
--- @field potentialContentSize number width of the component's content before applying ``min-`` and ``max-`` modifiers.
--- @field resolvedContentSize number resolved width of the component's content.

--- Contains metrics for vertical component layout.
---
--- At the stage when these are calculated, final component's dimensions
--- are not yet known, hence some values are not resolved.
---
--- @class ammgui.component.block.VerticalLayout
--- @field usedSize [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto" the actual algorithm that was used to calculate height.
--- @field usedMinSize [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto" the actual algorithm that was used to calculate min height.
--- @field usedMaxSize [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto" the actual algorithm that was used to calculate max height.
--- @field resolvedContentMinSize number resolved min height of the component's content.
--- @field resolvedContentMaxSize number resolved max height of the component's content.
--- @field potentialContentSize number? height of the component's content before applying ``min-`` and ``max-`` modifiers.
--- @field resolvedContentSize number? resolved height of the component's content.

--- Contains final layout metrics.
---
--- These metrics are resolved values form css, adjusted by the actual layout context
--- of the block.
---
--- @class ammgui.component.block.UsedLayout
--- @field contentPosition Vector2D position of the content box relative to the border box; includes padding and outline offset.
--- @field potentialContentSize Vector2D size of the component's content before applying ``min-`` and ``max-`` modifiers.
--- @field resolvedContentSize Vector2D resolved size of the component's content.
--- @field actualContentSize Vector2D actual size of the component's content. Can be larger than `resolvedContentWidth`, in which case component overflows.
--- @field visibleContentSize Vector2D visible size of the component's content. This is `actualContentSize` if ``overflow: visible``, `resolvedContentSize` otherwise.
--- @field resolvedBorderBoxSize Vector2D resolved size of the component's border box.
--- @field actualBorderBoxSize Vector2D actual size of the component. Can be larger than `resolvedBorderBoxSize`, in which case component overflows.
--- @field visibleBorderBoxSize Vector2D visible size of the component. This is `actualBorderBoxSize` if ``overflow: visible``, `resolvedBorderBoxSize` otherwise.
--- @field collapsedMarginTop Vector2D value for top margin, including any margins that were collapsed from children. First vector element is maximum of all collapsed positive margins, second vector element is minimum of all collapsed negative margins.
--- @field collapsedMarginBottom Vector2D value for bottom margin, including any margins that were collapsed from children. First vector element is maximum of all collapsed positive margins, second vector element is minimum of all collapsed negative margins.
--- @field effectiveVerticalMargin Vector2D top and bottom margins, used if margins of this component don't collapse into its parent.
--- @field effectiveHorizontalMargin Vector2D left and right margin with resolved ``"auto"`` values.

--- Used layout metrics. These are set by the `calculateLayout` method
--- to be later reused in the `draw` call.
---
--- @type ammgui.component.block.BaseLayout
ns.Component.baseLayout = nil

--- Used layout metrics. These are set by the `calculateLayout` method
--- to be later reused in the `draw` call.
---
--- @type ammgui.component.block.HorizontalLayout
ns.Component.horizontalLayout = nil

--- Used layout metrics. These are set by the `calculateLayout` method
--- to be later reused in the `draw` call.
---
--- @type ammgui.component.block.VerticalLayout
ns.Component.verticalLayout = nil

--- Used layout metrics. These are set by the `calculateLayout` method
--- to be later reused in the `draw` call.
---
--- @type ammgui.component.block.UsedLayout
ns.Component.usedLayout = nil

--- Parent component, if any.
---
--- @type ammgui.component.block.Component?
ns.Component.parent = nil

--- `true` when component is mounted.
---
--- @private
--- @type boolean
ns.Component._isActive = false

--- Called when component is initialized.
---
--- !doc virtual
--- @param data ammgui.dom.block.Node user-provided component data.
function ns.Component:onMount(ctx, data)
    self._isActive = true
    ns.Component.onUpdate(self, ctx, data)
    if data.initialStyle then
        self:setInlineCss(data.initialStyle)
    end
    if data.initialClass then
        self:setClasses(data.initialClass)
    end
end

--- Called when component is updated.
---
--- If new data causes changes in layout, `onUpdate` handler should set `outdated`
--- to `true` to make sure that its layout is properly recalculated.
---
--- Changes to inline CSS styles and set of component's classes and pseudoclasses
--- should be handled through appropriate functions. If CSS settings change,
--- `outdated` will be set automatically during the CSS synchronization pass.
---
--- !doc virtual
--- @param data ammgui.dom.block.Node user-provided component data.
function ns.Component:onUpdate(ctx, data)
    if data.style then
        self:setInlineCss(data.style)
    end
    if data.class then
        self:setClasses(data.class)
    end

    self._onMouseEnterHandler = data.onMouseEnter
    self._onMouseMoveHandler = data.onMouseMove
    self._onMouseExitHandler = data.onMouseExit
    self._onMouseDownHandler = data.onMouseDown
    self._onMouseUpHandler = data.onMouseUp
    self._onClickHandler = data.onClick
    self._onRightClickHandler = data.onRightClick
    self._onMouseWheelHandler = data.onMouseWheel
    self._dragTarget = data.dragTarget
    if data.isDraggable == nil then
        self._isDraggable =
            data.onDragStart ~= nil
            or data.onDrag ~= nil
            or data.onDragEnd ~= nil
    else
        self._isDraggable = data.isDraggable
    end
    self._onDragStartHandler = data.onDragStart
    self._onDragHandler = data.onDrag
    self._onDragEndHandler = data.onDragEnd
end

--- Called when component is destroyed.
---
--- !doc virtual
function ns.Component:onUnmount(ctx)
    self._isActive = false
end

--- A single component just adds itself to the list (see `ComponentProvider.collect`).
---
--- @param components ammgui.component.block.Component[]
function ns.Component:collect(components)
    table.insert(components, self)
end

function ns.Component:noteRef(ref)
    ref.current = self
end

--- Called to prepare for layout estimation.
---
--- If this component is outdated, this function will reset layout cache
--- and set `outdated` flag to `false`.
---
--- !doc abstract
--- @param textMeasure ammgui.component.context.TextMeasure
function ns.Component:prepareLayout(textMeasure)
    if self.outdated then
        self._cachedIntrinsicContentWidth = nil
        self._cachedExtrinsicBorderBoxWidth = nil
        self._cachedExtrinsicOuterWidth = nil
        self._cachedLayoutParams = nil
        self.baseLayout = nil
        self.horizontalLayout = nil
        self.verticalLayout = nil
        self.usedLayout = nil
        self.usedLayout = nil
        self._cachedContentLayout = nil
        self._cachedContentLayoutParams = nil
    end
    self.outdated = false
end

--- Called to estimate component's intrinsic dimensions.
---
--- This function is called when container needs to estimate component's dimensions
--- in order to pack all of its contents.
---
--- It should return intrinsic content width (i.e. not including paddings, and
--- not using ``width`` and its ``min-`` and ``max-`` settings) calculated for two cases:
---
--- - ``min-content``: minimum width that the content can take, i.e. width
---   of the container if every wrapping opportunity is taken;
--- - ``max-content``: maximum width that the content can take, i.e. width
---   of the container if nothing wraps.
---
--- !doc abstract
--- @return number minContentWidth content width in min-content mode.
--- @return number maxContentWidth content width in max-content mode.
--- @return boolean isReplaced `true` if component is replaced, i.e. it is an image or other content that can't adjust its width.
--- @return number? preferredAspectRatio if component is replaced, can be used to determine its height from its intrinsic width.
function ns.Component:calculateIntrinsicContentWidth()
    error("not implemented")
end

--- Get or recalculate cached result of `calculateIntrinsicContentWidth`.
---
--- @return number minContentWidth content width in min-content mode.
--- @return number maxContentWidth content width in max-content mode.
--- @return boolean isReplaced `true` if component is replaced, i.e. it is an image or other content that can't adjust its width.
--- @return number? preferredAspectRatio if component is replaced, can be used to determine its height from its intrinsic width.
function ns.Component:getIntrinsicContentWidth()
    if not self._cachedIntrinsicContentWidth then
        self._cachedIntrinsicContentWidth = { self:calculateIntrinsicContentWidth() }
    end

    ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
    return table.unpack(self._cachedIntrinsicContentWidth)
end

--- Get extrinsic border box width. That is, intrinsic content width adjusted
--- by ``width``, ``min-`` and ``max-width``, ``padding``, and ``outlineWidth``
--- CSS properties.
---
--- @return number minBorderBoxWidth border box width in min-content mode.
--- @return number maxBorderBoxWidth border box width in max-content mode.
--- @return boolean isReplaced `true` if component is replaced, i.e. it is an image or other content that can't adjust its width.
--- @return number? preferredAspectRatio if component is replaced, can be used to determine its height from its intrinsic width.
function ns.Component:calculateExtrinsicBorderBoxWidth()
    --[[
    - This function is governed by css-2, §10.2-§10.7, and css-sizing-3, §5.
    - This function deals with block-level, non-replaced elements in normal flow;
      However, under css-sizing-3, §5.1, intrinsic sizes are calculated
      as if for floating, non-replaced elements.
    - This function is only called from `CalculateIntrinsicContentWidth`,
      because `calculateLayout` uses `CalculateIntrinsicContentWidth`.
    - Thus, parent component is always sized under `min-content`/`max-content` rules,
      so we might assume we don't know its size.
    - Therefore, `width: auto` is treated as `fit-content`, and therefore depends
      on component's intrinsic sizes.

    1. Resolve paddings and outline width. Relative values are treated as `0`.
    2. For `width`, `min-width` and `max-width`, resolve `min-content-width` and `max-content-width`:
       1. If `min-content`, result for `max-content-width` is equal to result for `min-content-width`.
       2. If `max-content`, result for `min-content-width` is equal to result for `max-content-width`.
       3. If `px`, result for `min-content-width` and `max-content-width` is equal to the given value.
       4. If `%`, `auto`, or `fit-content`, result for `min-content-width` and `max-content-width`
           is equal to results of `CalculateIntrinsicContentWidth` plus paddings and outline
           from step 1.
    3. Clamp `min-content-width` and `max-content-width` calculated for `width`
      by respective `min-content-width` and `max-content-width` calculated
      for `min-width` and `max-width`.
    ]]

    local paddingLeft = util.resolvePercentage(self.css.paddingLeft, 0)
    local paddingRight = util.resolvePercentage(self.css.paddingRight, 0)
    local outlineWidth = util.resolvePercentage(self.css.outlineWidth, 0)
    local contentWidthAdjustment = 2 * outlineWidth + paddingLeft + paddingRight

    local minContentWidth, maxContentWidth, isReplaced, preferredAspectRatio = self:getIntrinsicContentWidth()

    local function resolveWidth(widthWithUnit)
        local width = util.resolveAbsOrNil(widthWithUnit)
        if width then
            return width, width
        else
            local minBorderBoxWidth = minContentWidth + contentWidthAdjustment
            local maxBorderBoxWidth = maxContentWidth + contentWidthAdjustment
            if widthWithUnit == "min-content" then
                maxBorderBoxWidth = minBorderBoxWidth
            elseif widthWithUnit == "max-content" then
                minBorderBoxWidth = maxBorderBoxWidth
            end
            return minBorderBoxWidth, maxBorderBoxWidth
        end
    end

    local minBorderBoxWidth, maxBorderBoxWidth = resolveWidth(self.css.width)
    local minBorderBoxMinWidth, maxBorderBoxMinWidth = resolveWidth(self.css.minWidth)
    local minBorderBoxMaxWidth, maxBorderBoxMaxWidth = resolveWidth(self.css.maxWidth)

    minBorderBoxWidth = math.max(minBorderBoxMinWidth, math.min(minBorderBoxWidth, minBorderBoxMaxWidth))
    maxBorderBoxWidth = math.max(maxBorderBoxMinWidth, math.min(maxBorderBoxWidth, maxBorderBoxMaxWidth))

    return minBorderBoxWidth, maxBorderBoxWidth, isReplaced, preferredAspectRatio
end

--- Get or recalculate cached result of `calculateExtrinsicBorderBoxWidth`.
---
--- @return number minBorderBoxWidth border box width in min-content mode.
--- @return number maxBorderBoxWidth border box width in max-content mode.
--- @return boolean isReplaced `true` if component is replaced, i.e. it is an image or other content that can't adjust its width.
--- @return number? preferredAspectRatio if component is replaced, can be used to determine its height from its intrinsic width.
function ns.Component:getExtrinsicBorderBoxWidth()
    if not self._cachedExtrinsicBorderBoxWidth then
        self._cachedExtrinsicBorderBoxWidth = { self:calculateExtrinsicBorderBoxWidth() }
    end

    ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
    return table.unpack(self._cachedExtrinsicBorderBoxWidth)
end

--- Get extrinsic outer width. That is, extrinsic border box width adjusted
--- by `marginLeft` and `marginRight` CSS properties.
---
--- @return number minOuterWidth outer width in min-content mode.
--- @return number maxOuterWidth outer width in max-content mode.
--- @return boolean isReplaced `true` if component is replaced, i.e. it is an image or other content that can't adjust its width.
--- @return number? preferredAspectRatio if component is replaced, can be used to determine its height from its intrinsic width.
function ns.Component:calculateExtrinsicOuterWidth()
    local minBorderBoxWidth, maxBorderBoxWidth, isReplaced, preferredAspectRatio = self:getExtrinsicBorderBoxWidth()
    local marginLeft = util.resolvePercentageOrNil(self.css.marginLeft, 0) or 0
    local marginRight = util.resolvePercentageOrNil(self.css.marginRight, 0) or 0
    return
        minBorderBoxWidth + marginLeft + marginRight,
        maxBorderBoxWidth + marginLeft + marginRight,
        isReplaced,
        preferredAspectRatio
end

--- Get or recalculate cached result of `calculateExtrinsicOuterWidth`.
---
--- @return number minOuterWidth outer width in min-content mode.
--- @return number maxOuterWidth outer width in max-content mode.
--- @return boolean isReplaced `true` if component is replaced, i.e. it is an image or other content that can't adjust its width.
--- @return number? preferredAspectRatio if component is replaced, can be used to determine its height from its intrinsic width.
function ns.Component:getExtrinsicOuterWidth()
    if not self._cachedExtrinsicOuterWidth then
        self._cachedExtrinsicOuterWidth = { self:calculateExtrinsicOuterWidth() }
    end

    ---@diagnostic disable-next-line: redundant-return-value, return-type-mismatch
    return table.unpack(self._cachedExtrinsicOuterWidth)
end

--- Called to finalize component's layout.
---
--- Receives final dimensions of the container, runs `calculateContentLayout`
--- and returns data for `usedLayout`.
---
--- Parent component can tweak layout process by overriding `baseLayout`,
--- `horizontalLayout`, and `verticalLayout` before calling this method.
--- This is used in flexboxes and tables that have custom code for calculating
--- component width.
---
--- @param availableWidth number?
--- @param availableHeight number?
--- @return ammgui.component.block.UsedLayout used layout data.
function ns.Component:calculateLayout(availableWidth, availableHeight)
    self.baseLayout =
        self.baseLayout
        or self:determineBaseLayout(availableWidth, availableHeight)
    self.horizontalLayout =
        self.horizontalLayout
        or self:determineHorizontalLayout(availableWidth, availableHeight, self.baseLayout)
    self.verticalLayout =
        self.verticalLayout
        or self:determineVerticalLayout(availableWidth, availableHeight, self.baseLayout)

    local potentialContentWidth = self.horizontalLayout.potentialContentSize
    local resolvedContentWidth = self.horizontalLayout.resolvedContentSize
    local potentialContentHeight = self.verticalLayout.potentialContentSize
    local resolvedContentHeight = self.verticalLayout.resolvedContentSize

    if potentialContentWidth and not potentialContentHeight and self.baseLayout.preferredAspectRatio then
        potentialContentWidth = potentialContentHeight * self.baseLayout.preferredAspectRatio
        resolvedContentWidth =
            math.max(self.horizontalLayout.resolvedContentMinSize,
                math.min(potentialContentWidth, self.horizontalLayout.resolvedContentMaxSize))
    end
    if not potentialContentWidth and potentialContentHeight and self.baseLayout.preferredAspectRatio then
        potentialContentHeight = potentialContentWidth / self.baseLayout.preferredAspectRatio
        resolvedContentHeight =
            math.max(self.verticalLayout.resolvedContentMinSize,
                math.min(potentialContentHeight, self.verticalLayout.resolvedContentMaxSize))
    end

    local
    contentSize,
    actualContentSize,
    collapsedMarginTop,
    collapsedMarginBottom = self:getContentLayout(resolvedContentWidth, resolvedContentHeight)

    potentialContentWidth = potentialContentWidth or contentSize.x
    resolvedContentWidth = resolvedContentWidth or
        math.max(self.horizontalLayout.resolvedContentMinSize,
            math.min(potentialContentWidth, self.horizontalLayout.resolvedContentMaxSize))

    potentialContentHeight = potentialContentHeight or contentSize.y
    resolvedContentHeight = resolvedContentHeight or
        math.max(self.verticalLayout.resolvedContentMinSize,
            math.min(potentialContentHeight, self.verticalLayout.resolvedContentMaxSize))

    local potentialContentSize = structs.Vector2D { potentialContentWidth, potentialContentHeight }

    local resolvedContentSize = structs.Vector2D { resolvedContentWidth, resolvedContentHeight }

    local resolvedBorderBoxSize = structs.Vector2D {
        resolvedContentSize.x
        + self.baseLayout.paddingLeft
        + self.baseLayout.paddingRight
        + 2 * self.baseLayout.outlineWidth,
        resolvedContentSize.y
        + self.baseLayout.paddingTop
        + self.baseLayout.paddingBottom
        + 2 * self.baseLayout.outlineWidth,
    }

    actualContentSize = structs.Vector2D {
        math.max(actualContentSize.x, resolvedContentSize.x),
        math.max(actualContentSize.y, resolvedContentSize.y),
    }

    local actualBorderBoxSize = structs.Vector2D {
        self.baseLayout.outlineWidth
        + self.baseLayout.paddingLeft
        + math.max(
            resolvedContentSize.x
            + self.baseLayout.paddingRight
            + self.baseLayout.outlineWidth,
            actualContentSize.x
        ),
        self.baseLayout.outlineWidth
        + self.baseLayout.paddingTop
        + math.max(
            resolvedContentSize.y
            + self.baseLayout.paddingBottom
            + self.baseLayout.outlineWidth,
            actualContentSize.y
        ),
    }

    local visibleContentSize, visibleBorderBoxSize
    if self.css.overflow == "hidden" then
        visibleContentSize = resolvedContentSize
        visibleBorderBoxSize = resolvedBorderBoxSize
    else
        visibleContentSize = actualContentSize
        visibleBorderBoxSize = actualBorderBoxSize
    end

    local contentPosition = structs.Vector2D {
        self.baseLayout.paddingLeft + self.baseLayout.outlineWidth,
        self.baseLayout.paddingTop + self.baseLayout.outlineWidth,
    }

    collapsedMarginTop = collapsedMarginTop or structs.Vector2D { 0, 0 }
    if self.baseLayout.marginTop > 0 then
        collapsedMarginTop = structs.Vector2D {
            math.max(collapsedMarginTop.x, self.baseLayout.marginTop),
            collapsedMarginTop.y,
        }
    else
        collapsedMarginTop = structs.Vector2D {
            collapsedMarginTop.x,
            math.min(collapsedMarginTop.y, self.baseLayout.marginTop),
        }
    end
    collapsedMarginBottom = collapsedMarginBottom or structs.Vector2D { 0, 0 }
    if self.baseLayout.marginBottom > 0 then
        collapsedMarginBottom = structs.Vector2D {
            math.max(collapsedMarginBottom.x, self.baseLayout.marginBottom),
            collapsedMarginBottom.y,
        }
    else
        collapsedMarginBottom = structs.Vector2D {
            collapsedMarginBottom.x, math.min(collapsedMarginBottom.y,
            self.baseLayout.marginBottom),
        }
    end
    local effectiveVerticalMargin = structs.Vector2D {
        collapsedMarginTop.x + collapsedMarginTop.y,
        collapsedMarginBottom.x + collapsedMarginBottom.y,
    }

    local effectiveMarginLeft, effectiveMarginRight
    if not self.baseLayout.marginLeft and not self.baseLayout.marginRight and availableWidth then
        effectiveMarginLeft = (availableWidth - resolvedBorderBoxSize.x) / 2
        effectiveMarginRight = availableWidth - effectiveMarginLeft
    else
        effectiveMarginLeft = self.baseLayout.marginLeft or 0
        effectiveMarginRight = self.baseLayout.marginRight or 0
    end

    local effectiveHorizontalMargin = structs.Vector2D { effectiveMarginLeft, effectiveMarginRight }

    return {
        contentPosition = contentPosition,
        potentialContentSize = potentialContentSize,
        resolvedContentSize = resolvedContentSize,
        actualContentSize = actualContentSize,
        visibleContentSize = visibleContentSize,
        resolvedBorderBoxSize = resolvedBorderBoxSize,
        actualBorderBoxSize = actualBorderBoxSize,
        visibleBorderBoxSize = visibleBorderBoxSize,
        collapsedMarginTop = collapsedMarginTop,
        collapsedMarginBottom = collapsedMarginBottom,
        effectiveVerticalMargin = effectiveVerticalMargin,
        effectiveHorizontalMargin = effectiveHorizontalMargin,
    }
end

--- Default logic for calculating base layout metrics.
---
--- @param availableWidth number?
--- @param availableHeight number?
--- @return ammgui.component.block.BaseLayout
function ns.Component:determineBaseLayout(availableWidth, availableHeight)
    local _, _, isReplaced, preferredAspectRatio = self:getIntrinsicContentWidth()
    return {
        isReplaced = isReplaced,
        preferredAspectRatio = preferredAspectRatio,
        outlineWidth = util.resolvePercentage(self.css.outlineWidth, availableHeight or 0),
        outlineRadius = util.resolvePercentage(self.css.outlineRadius, availableHeight or 0),
        paddingTop = util.resolvePercentage(self.css.paddingTop, availableWidth or 0),
        paddingRight = util.resolvePercentage(self.css.paddingRight, availableWidth or 0),
        paddingBottom = util.resolvePercentage(self.css.paddingBottom, availableWidth or 0),
        paddingLeft = util.resolvePercentage(self.css.paddingLeft, availableWidth or 0),
        marginTop = util.resolvePercentageOrNil(self.css.marginTop, availableWidth or 0) or 0,
        marginRight = util.resolvePercentageOrNil(self.css.marginRight, availableWidth or 0),
        marginBottom = util.resolvePercentageOrNil(self.css.marginBottom, availableWidth or 0) or 0,
        marginLeft = util.resolvePercentageOrNil(self.css.marginLeft, availableWidth or 0),
    }
end

--- Default logic for calculating horizontal layout metrics.
---
--- @param availableWidth number?
--- @param availableHeight number?
--- @param computedWidth [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"?
--- @param computedMinWidth [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"?
--- @param computedMaxWidth [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"?
--- @param baseLayout ammgui.component.block.BaseLayout
--- @return ammgui.component.block.HorizontalLayout
function ns.Component:determineHorizontalLayout(availableWidth, availableHeight, baseLayout, computedWidth,
                                                computedMinWidth, computedMaxWidth)
    local minContentWidth, maxContentWidth = self:getIntrinsicContentWidth()

    local usedWidth = self:_determineUsedWidth(computedWidth or self.css.width, availableWidth, baseLayout)
    local usedMinWidth = self:_determineUsedWidth(computedMinWidth or self.css.minWidth, availableWidth, baseLayout)
    local usedMaxWidth = self:_determineUsedWidth(computedMaxWidth or self.css.maxWidth, availableWidth, baseLayout)

    local resolvedContentMinWidth =
        math.max(0.0, self:_determineResolvedWidth(
            usedMinWidth,
            availableWidth,
            minContentWidth,
            maxContentWidth,
            baseLayout)
        )
    local resolvedContentMaxWidth =
        math.max(0.0,
            self:_determineResolvedWidth(
                usedMaxWidth,
                availableWidth,
                minContentWidth,
                maxContentWidth,
                baseLayout)
        )
    local potentialContentWidth =
        self:_determineResolvedWidth(
            usedWidth,
            availableWidth,
            minContentWidth,
            maxContentWidth,
            baseLayout
        )

    local resolvedContentWidth =
        potentialContentWidth
        and math.max(resolvedContentMinWidth, math.min(potentialContentWidth, resolvedContentMaxWidth))

    return {
        usedSize = usedWidth,
        usedMinSize = usedMinWidth,
        usedMaxSize = usedMaxWidth,
        resolvedContentMinSize = resolvedContentMinWidth,
        resolvedContentMaxSize = resolvedContentMaxWidth,
        potentialContentSize = potentialContentWidth,
        resolvedContentSize = resolvedContentWidth,
    }
end

--- Default logic for calculating vertical layout metrics.
---
--- @param availableWidth number?
--- @param availableHeight number?
--- @param baseLayout ammgui.component.block.BaseLayout
--- @param computedHeight [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"?
--- @param computedMinHeight [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"?
--- @param computedMaxHeight [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"?
--- @return ammgui.component.block.VerticalLayout
function ns.Component:determineVerticalLayout(availableWidth, availableHeight, baseLayout, computedHeight,
                                              computedMinHeight, computedMaxHeight)
    local usedHeight = self:_determineUsedHeight(computedHeight or self.css.height, availableHeight)
    local usedMinHeight = self:_determineUsedHeight(computedMinHeight or self.css.minHeight, availableHeight)
    local usedMaxHeight = self:_determineUsedHeight(computedMaxHeight or self.css.maxHeight, availableHeight)

    local resolvedContentMinHeight =
        math.max(0.0,
            self:_determineResolvedHeight(
                usedMinHeight,
                availableHeight,
                baseLayout
            ) or 0
        )
    local resolvedContentMaxHeight =
        math.max(0.0,
            self:_determineResolvedHeight(
                usedMaxHeight,
                availableHeight,
                baseLayout
            ) or math.huge
        )
    local potentialContentHeight =
        self:_determineResolvedHeight(
            usedHeight,
            availableHeight,
            baseLayout
        )

    local resolvedContentHeight =
        potentialContentHeight
        and math.max(resolvedContentMinHeight, math.min(potentialContentHeight, resolvedContentMaxHeight))

    return {
        usedSize = usedHeight,
        usedMinSize = usedMinHeight,
        usedMaxSize = usedMaxHeight,
        resolvedContentMinSize = resolvedContentMinHeight,
        resolvedContentMaxSize = resolvedContentMaxHeight,
        potentialContentSize = potentialContentHeight,
        resolvedContentSize = resolvedContentHeight,
    }
end

--- @param computedWidth [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"
--- @param availableWidth number?
--- @param baseLayout ammgui.component.block.BaseLayout
--- @return [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"
function ns.Component:_determineUsedWidth(computedWidth, availableWidth, baseLayout)
    if not availableWidth and (
            computedWidth == "auto"
            or computedWidth == "fit-content"
            or type(computedWidth) == "table" and computedWidth[2] == "%"
        ) then
        return "max-content"
    elseif baseLayout.isReplaced and computedWidth == "auto" then
        return "max-content"
    else
        return computedWidth
    end
end

--- @param usedWidth [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"
--- @param availableWidth number?
--- @param minContentWidth number
--- @param maxContentWidth number
--- @param baseLayout ammgui.component.block.BaseLayout
--- @return number
function ns.Component:_determineResolvedWidth(usedWidth, availableWidth, minContentWidth, maxContentWidth, baseLayout)
    availableWidth = availableWidth or 0
    if usedWidth == "auto" then
        return availableWidth
            - (baseLayout.marginLeft or 0)
            - baseLayout.paddingLeft
            - baseLayout.paddingRight
            - (baseLayout.marginRight or 0)
            - 2 * baseLayout.outlineWidth
    elseif usedWidth == "min-content" then
        return minContentWidth
    elseif usedWidth == "max-content" then
        return maxContentWidth
    elseif usedWidth == "fit-content" then
        local availableContentWidth = availableWidth
            - (baseLayout.marginLeft or 0)
            - baseLayout.paddingLeft
            - baseLayout.paddingRight
            - (baseLayout.marginRight or 0)
            - 2 * baseLayout.outlineWidth
        return math.max(minContentWidth, math.min(availableContentWidth, maxContentWidth))
    elseif true then -- elseif boxSizing == "border-box" then
        --- @cast usedWidth [number, "px"|"%"]
        return util.resolvePercentage(usedWidth, availableWidth)
            - baseLayout.paddingLeft
            - baseLayout.paddingRight
            - 2 * baseLayout.outlineWidth
    else
        --- @cast usedWidth [number, "px"|"%"]
        return util.resolvePercentage(usedWidth, availableWidth)
    end
end

--- @param computedHeight [number, "px"|"%"]|"min-content"|"max-content"|"fit-content"|"auto"
--- @param availableHeight number?
--- @return [number, "px"|"%"]|"auto"
function ns.Component:_determineUsedHeight(computedHeight, availableHeight)
    if not availableHeight and (
            type(computedHeight) == "table" and computedHeight[2] == "%"
        ) then
        return "auto"
    elseif computedHeight == "min-content" or computedHeight == "max-content" or computedHeight == "fit-content" then
        -- These only make sense in vertical writing mode, which we don't support.
        return "auto"
    else
        return computedHeight --[[ @as [number, "px"|"%"]|"auto" ]]
    end
end

--- @param usedHeight [number, "px"|"%"]|"auto"
--- @param availableHeight number?
--- @param baseLayout ammgui.component.block.BaseLayout
--- @return number?
function ns.Component:_determineResolvedHeight(usedHeight, availableHeight, baseLayout)
    availableHeight = availableHeight or 0
    if usedHeight == "auto" then
        return nil
    elseif true then -- elseif boxSizing == "border-box" then
        --- @cast usedHeight [number, "px"|"%"]
        return util.resolvePercentage(usedHeight, availableHeight)
            - baseLayout.paddingTop
            - baseLayout.paddingBottom
            - 2 * baseLayout.outlineWidth
    else
        --- @cast usedHeight [number, "px"|"%"]
        return util.resolvePercentage(usedHeight, availableHeight)
    end
end

--- Get or recalculate cached result of `calculateLayout`.
---
--- Set `usedLayout` to `nil` to force recalculation.
---
--- @param availableWidth number? available content width.
--- @param availableHeight number? available content height.
--- @param honorPrecalculated boolean? honor pre-calculated horizontal and vertical layouts.
--- @return ammgui.component.block.UsedLayout used layout data.
function ns.Component:getLayout(availableWidth, availableHeight, honorPrecalculated)
    local layoutParams = { availableWidth, availableHeight, honorPrecalculated }
    if
        not self.baseLayout
        or not self.horizontalLayout
        or not self.verticalLayout
        or not self.usedLayout
        or not self._cachedLayoutParams
        or not array.eq(self._cachedLayoutParams, layoutParams)
    then
        if not honorPrecalculated then
            self.horizontalLayout = nil
            self.verticalLayout = nil
        end
        self._cachedLayoutParams = layoutParams
        self.usedLayout = self:calculateLayout(availableWidth, availableHeight)
    end

    return self.usedLayout
end

--- Run layout on component's children and return size of the content box.
---
--- If content box size is greater than the given available size,
--- the component overflows.
---
--- Note that `usedLayout` is not set at this stage.
---
--- !doc abstract
--- @param availableWidth number? available content width.
--- @param availableHeight number? available content height.
--- @return Vector2D contentSize final content size.
--- @return Vector2D actualContentSize final content size, including overflow. Used to calculate scroll box inner size.
--- @return Vector2D? collapsedMarginTop collapsed margin from top child.
--- @return Vector2D? collapsedMarginBottom collapsed margin from bottom child.
function ns.Component:calculateContentLayout(availableWidth, availableHeight)
    error("not implemented")
end

--- Get or recalculate cached result of `calculateContentLayout`.
---
--- @param availableWidth number? available content width.
--- @param availableHeight number? available content height.
--- @return Vector2D contentSize final content size.
--- @return Vector2D actualContentSize final content size, including overflow. Used to calculate scroll box inner size.
--- @return Vector2D? collapsedMarginTop collapsed margin from top child.
--- @return Vector2D? collapsedMarginBottom collapsed margin from bottom child.
function ns.Component:getContentLayout(availableWidth, availableHeight)
    local layoutParams = { availableWidth, availableHeight }
    if
        not self._cachedContentLayout
        or not self._cachedContentLayoutParams
        or not array.eq(self._cachedContentLayoutParams, layoutParams)
    then
        self._cachedContentLayoutParams = layoutParams
        self._cachedContentLayout = { self:calculateContentLayout(availableWidth, availableHeight) }
    end

    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(self._cachedContentLayout)
end

--- Called to draw the component on screen. Use data from `usedLayout`
--- to draw component's content.
---
--- !doc abstract
--- @param ctx ammgui.component.context.RenderingContext
function ns.Component:draw(ctx)
    self:drawContainer(
        ctx,
        structs.Vector2D { 0, 0 },
        self.usedLayout.resolvedBorderBoxSize,
        self.css.backgroundColor,
        self.baseLayout.outlineWidth,
        self.css.outlineTint,
        self.baseLayout.outlineRadius
    )

    ctx:pushEventListener(
        structs.Vector2D { 0, 0 },
        self.usedLayout.resolvedBorderBoxSize,
        self
    )
end

function ns.Component:isActive()
    return self._isActive
end

function ns.Component:onMouseEnter(pos, modifiers, propagate)
    self:setPseudoclass("hover")
    if propagate and self._onMouseEnterHandler then
        propagate = runEventHandler(self._onMouseEnterHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseMove(pos, modifiers, propagate)
    if propagate and self._onMouseMoveHandler then
        propagate = runEventHandler(self._onMouseMoveHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseExit(pos, modifiers, propagate)
    self:unsetPseudoclass("hover")
    if propagate and self._onMouseExitHandler then
        propagate = runEventHandler(self._onMouseExitHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseDown(pos, modifiers, propagate)
    if propagate and self._onMouseDownHandler then
        propagate = runEventHandler(self._onMouseDownHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseUp(pos, modifiers, propagate)
    if propagate and self._onMouseUpHandler then
        propagate = runEventHandler(self._onMouseUpHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onClick(pos, modifiers, propagate)
    if propagate and self._onClickHandler then
        propagate = runEventHandler(self._onClickHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onRightClick(pos, modifiers, propagate)
    if propagate and self._onRightClickHandler then
        propagate = runEventHandler(self._onRightClickHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseWheel(pos, delta, modifiers, propagate)
    if propagate and self._onMouseWheelHandler then
        propagate = runEventHandler(self._onMouseWheelHandler, pos, delta, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:isDraggable()
    return self._isDraggable
end

function ns.Component:isDragTarget()
    return self._dragTarget
end

function ns.Component:onDragStart(pos, origin, modifiers, target)
    self:setPseudoclass("drag")
    if self._onDragStartHandler then
        return self._onDragStartHandler(pos, origin, modifiers, target)
    end
end

function ns.Component:onDrag(pos, origin, modifiers, target)
    if self._onDragHandler then
        return self._onDragHandler(pos, origin, modifiers, target)
    end
end

function ns.Component:onDragEnd(pos, origin, modifiers, target)
    self:unsetPseudoclass("drag")
    if self._onDragEndHandler then
        self._onDragEndHandler(pos, origin, modifiers, target)
    end
end

function ns.Component:onDragEnter(status)
    if status ~= "none" then
        self:setPseudoclass("drop")
        for _, pseudo in ipairs { "ok", "warn", "err" } do
            if pseudo == status then
                self:setPseudoclass("drop-" .. pseudo)
            else
                self:unsetPseudoclass("drop-" .. pseudo)
            end
        end
    end
end

function ns.Component:onDragExit()
    self:unsetPseudoclass("drop")
    self:unsetPseudoclass("drop-ok")
    self:unsetPseudoclass("drop-warn")
    self:unsetPseudoclass("drop-err")
end

--- Sync one DOM node with its component or provider.
---
--- @param ctx ammgui.component.context.RenderingContext
--- @param provider ammgui.component.block.ComponentProvider? component that was updated.
--- @param node ammgui.dom.block.Node
--- @return ammgui.component.block.ComponentProvider provider
function ns.Component.syncOne(ctx, provider, node)
    ---@diagnostic disable-next-line: invisible
    local nodeComponent = node._component
    if provider and nodeComponent == provider.__class then
        provider:onUpdate(ctx, node)
    else
        if provider then
            provider:onUnmount(ctx)
        end
        provider = nodeComponent:New(node.key)
        provider:onMount(ctx, node)
    end
    if node.ref then
        provider:noteRef(node.ref)
    end
    return provider
end

--- Sync array of DOM nodes with their providers.
---
--- @param ctx ammgui.component.context.RenderingContext
--- @param providers ammgui.component.block.ComponentProvider[]
--- @param nodes ammgui.dom.block.Node[]
--- @return ammgui.component.block.ComponentProvider[] providers
function ns.Component.syncProviders(ctx, providers, nodes)
    local providerByKey = {}
    for i, provider in ipairs(providers) do
        local key = provider.key or i
        if providerByKey[key] then
            logger:warning(
                "multiple components with the same key %s: %s, %s",
                log.pp(key), providerByKey[key], provider
            )
        else
            providerByKey[key] = provider
        end
    end

    local newProviders = {}
    for i, node in ipairs(nodes) do
        ---@diagnostic disable-next-line: invisible
        if node._isBlockNode then
            --- @cast node ammgui.dom.block.Node
            local key = node.key or i
            local provider = ns.Component.syncOne(ctx, providerByKey[key], node)
            table.insert(newProviders, provider)
            providerByKey[key] = nil
        else
            error(string.format("not a dom node: %s", log.pp(node)))
        end
    end

    return newProviders
end

--- Sync array of DOM nodes with their components.
---
--- @param ctx ammgui.component.context.RenderingContext
--- @param providers ammgui.component.block.ComponentProvider[]
--- @param components ammgui.component.block.Component[]
--- @param nodes ammgui.dom.block.Node[]
--- @param parent ammgui.component.block.Component
--- @return ammgui.component.block.ComponentProvider[] providers
--- @return ammgui.component.block.Component[] components
--- @return boolean outdated
--- @return boolean outdatedCss
function ns.Component.syncAll(ctx, providers, components, nodes, parent)
    local newProviders = ns.Component.syncProviders(ctx, providers, nodes)

    local newComponents = {}
    for _, provider in ipairs(newProviders) do
        provider:collect(newComponents)
    end

    local outdated, outdatedCss = false, false
    for _, component in ipairs(newComponents) do
        outdated = outdated or component.outdated
        outdatedCss = outdatedCss or component.outdatedCss
        component.parent = parent
    end

    -- Mark as outdated if number or order of components changed.
    outdated = outdated or not array.eq(components, newComponents)

    return newProviders, newComponents, outdated, outdatedCss
end

--- @param context ammgui.component.context.RenderingContext
function ns.Component:drawDebugOverlay(context)
    -- Resolved content.
    do
        context.gpu:drawRect(
            self.usedLayout.contentPosition,
            self.usedLayout.resolvedContentSize,
            structs.Color { 0.5, 0.5, 0.7, 0.5 },
            "",
            0
        )
    end
    -- Actual content.
    do
        local a = self.usedLayout.contentPosition
        local b = a + self.usedLayout.actualContentSize
        context.gpu:drawLines(
            {
                structs.Vector2D { a.x, a.y },
                structs.Vector2D { b.x, a.y },
                structs.Vector2D { b.x, b.y },
                structs.Vector2D { a.x, b.y },
                structs.Vector2D { a.x, a.y },
            },
            1,
            structs.Color { 0.5, 0.5, 0.7, 1 }
        )
    end
    -- Resolved border box.
    do
        context.gpu:pushClipRect(self.usedLayout.contentPosition, self.usedLayout.resolvedContentSize)
        context.gpu:drawRect(
            structs.Vector2D { 0, 0 },
            self.usedLayout.resolvedBorderBoxSize,
            structs.Color { 0.5, 0.7, 0.5, 0.5 },
            "",
            0
        )
        context.gpu:popClip()
    end
    -- Actual border box.
    do
        local a = structs.Vector2D { 0, 0 }
        local b = a + self.usedLayout.actualBorderBoxSize
        context.gpu:drawLines(
            {
                structs.Vector2D { a.x, a.y },
                structs.Vector2D { b.x, a.y },
                structs.Vector2D { b.x, b.y },
                structs.Vector2D { a.x, b.y },
                structs.Vector2D { a.x, a.y },
            },
            1,
            structs.Color { 0.5, 0.7, 0.5, 1 }
        )
    end
end

return ns
