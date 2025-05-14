local class = require "ammcore.class"
local base = require "ammgui._impl.layout"
local blockBase = require "ammgui._impl.layout.blockBase"
local textbox = require "ammgui._impl.layout.textbox"
local fun = require "ammcore.fun"
local eventListener = require "ammgui._impl.eventListener"
local resolved = require "ammgui._impl.css.resolved"

--- Base class node layouts that can have child elements.
---
--- !doctype module
--- @class ammgui._impl.layout.node
local ns = {}

--- Node with facilities to group inline children into text boxes.
---
--- @class ammgui._impl.layout.node.Node: ammgui._impl.layout.blockBase.BlockBase
ns.Node = class.create("Node", blockBase.BlockBase)

--- @param css ammgui._impl.css.resolved.Resolved
--- @param children ammgui._impl.layout.Layout[]
--- @param nodeEventListener ammgui._impl.eventListener.EventListener
--- @param previous ammgui._impl.layout.node.Node?
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.node.Node
--- @param self T
--- @return T
function ns.Node:New(css, children, nodeEventListener, previous)
    self = blockBase.BlockBase.New(self, css)

    --- @protected
    --- @type ammgui._impl.layout.Layout[]
    self.children = children

    --- @private
    --- @type ammgui._impl.css.resolved.Resolved
    self._textboxCss = resolved.Resolved:New(
        {
            {
                all = "unset",
                compiledSelectors = {},
                isLayoutSafe = false,
            },
        },
        {},
        css,
        css.theme,
        css.units
    )

    --- @private
    --- @type ammgui._impl.eventListener.EventListener
    self._nodeEventListener = nodeEventListener

    --- @protected
    --- @type ammgui._impl.layout.blockBase.BlockBase[]
    self._blockChildren = self:collectBlockChildren()

    if previous then
        self.scroll = previous.scroll
        self.hover = previous.hover
        self.scrollHover = previous.scrollHover
        self.scrollDrag = previous.scrollDrag
        self.stick = previous.stick
        self._mouseWheelFactor = previous._mouseWheelFactor
        self._listener = previous._listener
        self._listener.x.node = self
        self._listener.x.parent = nodeEventListener
        self._listener.y.node = self
        self._listener.y.parent = nodeEventListener
    else
        --- @type ammgui.Vec2
        self.scroll = Vec2:New( 0, 0 )

        --- @type boolean
        self.hover = false

        --- @type { x: boolean, y: boolean }
        self.scrollHover = { x = false, y = false }

        --- @type { x: boolean, y: boolean }
        self.scrollDrag = { x = false, y = false }

        --- @type { x: boolean, y: boolean }
        self.stick = { x = false, y = false }

        --- @private
        --- @type number
        self._mouseWheelFactor = 30

        --- @private
        self._listener = {
            x = ns.ScrollbarEventListener:New(self, nodeEventListener, "x", "y", "overflowX"),
            y = ns.ScrollbarEventListener:New(self, nodeEventListener, "y", "x", "overflowY"),
        }
    end

    return self
end

function ns.Node:asInline()
    if self.css.display == "inline" then
        --- @type ammgui._impl.layout.Element[]
        local elements = {}
        for _, child in ipairs(self.children) do
            fun.a.extend(elements, child:asInline())
        end
        for i, element in ipairs(elements) do
            elements[i] = element:withBoxData {
                isStart = i == 1,
                isEnd = i == #elements,
                parent = self,
                nodeEventListener = self._nodeEventListener,
            }
        end
        return elements
    else
        return blockBase.BlockBase.asInline(self)
    end
end

function ns.Node:updateCss(css)
    if css ~= self.css then
        base.Layout.updateCss(self, css)

        local textboxCss = resolved.Resolved:New(
            {
                {
                    all = "initial",
                    compiledSelectors = {},
                    isLayoutSafe = false,
                },
            },
            {},
            css,
            css.theme,
            css.units
        )

        for _, child in ipairs(self._blockChildren) do
            if child.css == self._textboxCss then
                child:updateCss(textboxCss)
            end
        end

        self._textboxCss = textboxCss
    end
end

function ns.Node:prepareLayout(textMeasure)
    for _, child in ipairs(self._blockChildren) do
        child:prepareLayout(textMeasure)
    end
end

--- Collect inline children into text boxes, and return an array of block children.
---
--- @return ammgui._impl.layout.blockBase.BlockBase[]
function ns.Node:collectBlockChildren()
    if self.css.display == "inline" then
        return {}
    end

    local children = {}
    local inlineElements = {}
    for _, child in ipairs(self.children) do
        if child:isInline() then
            table.insert(inlineElements, child)
        else
            if #inlineElements > 0 then
                table.insert(children, textbox.TextBox:New(self._textboxCss, inlineElements))
                inlineElements = {}
            end
            table.insert(children, child)
        end
    end
    if #inlineElements > 0 then
        table.insert(children, textbox.TextBox:New(self._textboxCss, inlineElements))
        inlineElements = {}
    end
    return children
end

function ns.Node:draw(ctx)
    local hasScrollX = self.css.overflowX == "scroll"
    local hasScrollY = self.css.overflowY == "scroll"

    local contentPosition = Vec2:New(
        self.usedLayout.contentPosition.x,
        self.usedLayout.contentPosition.y
    )

    if hasScrollX then
        self:_clampScroll("x")
        contentPosition.x = contentPosition.x - math.floor(self.scroll.x)
    end
    if hasScrollY then
        self:_clampScroll("y")
        contentPosition.y = contentPosition.y - math.floor(self.scroll.y)
    end

    blockBase.BlockBase.draw(self, ctx)
    ctx:pushEventListener(
        Vec2:New( 0, 0 ),
        self.usedLayout.resolvedBorderBoxSize,
        self._nodeEventListener
    )
    ctx:noteDebugTarget(
        Vec2:New( 0, 0 ),
        self.usedLayout.resolvedBorderBoxSize,
        self,
        self._nodeEventListener.id
    )

    self:drawContent(ctx, contentPosition)

    if hasScrollX then
        self:_drawScrollBox(ctx, "x", "y")
    end
    if hasScrollY then
        self:_drawScrollBox(ctx, "y", "x")
    end
end

function ns.Node:onMouseEnter(pos, modifiers)
    self.hover = true
end

function ns.Node:onMouseExit(pos, modifiers)
    self.hover = false
end

function ns.Node:onMouseWheel(pos, delta, modifiers, propagate)
    if propagate then
        local direction = modifiers & 8 > 0 and "x" or "y" -- Shift pressed?

        if
            (direction == "x" and self.css.overflowX ~= "scroll")
            or (direction == "y" and self.css.overflowY ~= "scroll")
        then
            return propagate
        end

        local scrollableSize = self.usedLayout.actualBorderBoxSize[direction]
        local viewportSize = self.usedLayout.resolvedBorderBoxSize[direction]

        if viewportSize + 0.5 >= scrollableSize then
            return propagate
        end

        local scrollPosA = 0
        local scrollPosB = math.max(0, scrollableSize - viewportSize)
        local scrollPos = math.max(scrollPosA,
            math.min(scrollPosB, self.scroll[direction] - delta * self._mouseWheelFactor))

        -- Only propagate event if we scrolled less than 1px.
        propagate = math.abs(scrollPos - self.scroll[direction]) < 1
        self.scroll[direction] = scrollPos
        self.stick[direction] = scrollPos >= scrollPosB - 5
    end
    return propagate
end

--- @param ctx ammgui._impl.context.render.Context
--- @param pos ammgui.Vec2
function ns.Node:drawContent(ctx, pos)
    error("not implemented")
end

function ns.Node:_clampScroll(direction)
    local scrollableSize = self.usedLayout.actualBorderBoxSize[direction]
    local viewportSize = self.usedLayout.resolvedBorderBoxSize[direction]

    local scrollPosA = 0
    local scrollPosB = math.max(0, scrollableSize - viewportSize)

    if self.stick[direction] then
        self.scroll[direction] = scrollPosB
    else
        self.scroll[direction] = math.max(scrollPosA, math.min(scrollPosB, self.scroll[direction]))
    end
end

--- @param ctx ammgui._impl.context.render.Context
function ns.Node:_drawScrollBox(ctx, direction, crossDirection)
    local scrollableSize = self.usedLayout.actualBorderBoxSize[direction]
    local viewportSize = self.usedLayout.resolvedBorderBoxSize[direction]

    if viewportSize + 0.5 >= scrollableSize then -- +0.5 to compensate for rounding errors.
        return
    end

    local scrollPosA = 0
    local scrollPosB = math.max(0, scrollableSize - viewportSize)
    local scrollPos = math.max(scrollPosA, math.min(scrollPosB, self.scroll[direction]))

    local scrollPosRatio = (scrollPos - scrollPosA) / (scrollPosB - scrollPosA)

    local scrollHandleSize = math.min(viewportSize, math.max(25, viewportSize * viewportSize / scrollableSize))
    local scrollHandlePosA = scrollHandleSize / 2
    local scrollHandlePosB = viewportSize - scrollHandlePosA
    local scrollHandlePos = scrollHandlePosA + (scrollHandlePosB - scrollHandlePosA) * scrollPosRatio

    local scrollHandleCrossSize = 10

    local scrollColor = structs.Color {
        1,
        1,
        1,
        (self.scrollHover[direction] or self.scrollDrag[direction])
        and 0.3
        or (self.hover and 0.1 or 0),
    }

    local position = Vec2:FromTable {
        [direction] = scrollHandlePos - scrollHandleSize / 2,
        [crossDirection] = self.usedLayout.resolvedBorderBoxSize[crossDirection] - scrollHandleCrossSize - 2
    }
    local size = Vec2:FromTable {
        [direction] = scrollHandleSize,
        [crossDirection] = scrollHandleCrossSize
    }

    ctx.gpu:drawBox {
        position = position,
        size = size,
        rotation = 0,
        color = scrollColor,
        image = "",
        imageSize = Vec2:New(0, 0),
        hasCenteredOrigin = false,
        horizontalTiling = false,
        verticalTiling = false,
        isBorder = false,
        margin = { top = 0, right = 0, bottom = 0, left = 0 },
        isRounded = true,
        radii = structs.Vector4 {
            scrollHandleCrossSize / 2,
            scrollHandleCrossSize / 2,
            scrollHandleCrossSize / 2,
            scrollHandleCrossSize / 2,
        },
        hasOutline = false,
        outlineThickness = 0,
        outlineColor = structs.Color { 0, 0, 0, 0 },
    }

    ctx:pushEventListener(position, size, self._listener[direction])
end

--- Scroll bar drag handle.
---
--- @class ammgui._impl.layout.node.ScrollbarEventListener: ammgui._impl.eventListener.EventListener
ns.ScrollbarEventListener = class.create("ScrollbarEventListener", eventListener.EventListener)

--- @param node ammgui._impl.layout.node.Node
--- @param parent ammgui._impl.eventListener.EventListener
--- @param direction "x"|"y"
--- @param crossDirection "x"|"y"
--- @param cssProperty "overflowX"|"overflowY"
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.node.ScrollbarEventListener
--- @param self T
--- @return T
function ns.ScrollbarEventListener:New(node, parent, direction, crossDirection, cssProperty)
    self = eventListener.EventListener.New(self)

    --- Parent event listener.
    ---
    --- @type ammgui._impl.eventListener.EventListener
    self.parent = parent

    --- @type ammgui._impl.layout.node.Node
    self.node = node

    --- @private
    --- @type "x"|"y"
    self._direction = direction

    --- @private
    --- @type "x"|"y"
    self._crossDirection = crossDirection

    --- @private
    --- @type "overflowX"|"overflowY"
    self._cssProperty = cssProperty

    return self
end

function ns.ScrollbarEventListener:isActive()
    return self.node.css[self._cssProperty] == "scroll"
end

function ns.ScrollbarEventListener:isDraggable()
    return true
end

function ns.ScrollbarEventListener:onMouseEnter(pos, origin, modifiers)
    self.node.scrollHover[self._direction] = true
end

function ns.ScrollbarEventListener:onMouseExit(pos, origin, modifiers)
    self.node.scrollHover[self._direction] = false
end

function ns.ScrollbarEventListener:onDragStart(pos, origin, modifiers, target)
    local scrollableSize = self.node.usedLayout.actualBorderBoxSize[self._direction]
    local viewportSize = self.node.usedLayout.resolvedBorderBoxSize[self._direction]

    if viewportSize + 0.5 >= scrollableSize then
        return false
    end

    local scrollPosA = 0
    local scrollPosB = math.max(0, scrollableSize - viewportSize)
    local scrollPos = math.max(scrollPosA, math.min(scrollPosB, self.node.scroll[self._direction]))
    local scrollPosRatio = (scrollPos - scrollPosA) / (scrollPosB - scrollPosA)

    local scrollHandleSize = math.min(viewportSize, math.max(25, viewportSize * viewportSize / scrollableSize))
    local scrollHandlePosA = scrollHandleSize / 2
    local scrollHandlePosB = viewportSize - scrollHandlePosA

    self._scrollHandleOrigPos = scrollHandlePosA + (scrollHandlePosB - scrollHandlePosA) * scrollPosRatio

    self.node.scrollDrag[self._direction] = true
    return self:onDrag(pos, origin, modifiers, target)
end

function ns.ScrollbarEventListener:onDrag(pos, origin, modifiers, target)
    local delta = pos[self._direction] - origin[self._direction]

    local scrollableSize = self.node.usedLayout.actualBorderBoxSize[self._direction]
    local viewportSize = self.node.usedLayout.resolvedBorderBoxSize[self._direction]

    if viewportSize >= scrollableSize then
        return false
    end

    local scrollHandleSize = math.min(viewportSize, math.max(25, viewportSize * viewportSize / scrollableSize))
    local scrollHandlePosA = scrollHandleSize / 2
    local scrollHandlePosB = viewportSize - scrollHandlePosA

    local scrollHandlePos = self._scrollHandleOrigPos + delta

    local scrollPosRatio = (scrollHandlePos - scrollHandlePosA) / (scrollHandlePosB - scrollHandlePosA)

    local scrollPosA = 0
    local scrollPosB = math.max(0, scrollableSize - viewportSize)
    local scrollPos = math.max(scrollPosA, math.min(scrollPosB, scrollPosA + (scrollPosB - scrollPosA) * scrollPosRatio))

    self.node.scroll[self._direction] = scrollPos
    self.node.stick[self._direction] = scrollPos >= scrollPosB - 5

    return "none" -- Don't highlight drop zones.
end

function ns.ScrollbarEventListener:onDragEnd(pos, origin, modifiers, target)
    self:onDrag(pos, origin, modifiers, target)
    self._origScroll = nil
    self.node.scrollDrag[self._direction] = false
end

return ns
