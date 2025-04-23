local div = require "ammgui.component.block.div"
local class = require "ammcore.class"
local context = require "ammgui.component.context"
local log     = require "ammcore.log"
local eventManager = require "ammgui.eventManager"

--- Scroll box component.
---
--- !doctype module
--- @class ammgui.component.block.scrollbox
local ns = {}

--- Scroll bar drag handle.
---
--- @class ammgui.component.block.scrollbox.ScrollbarEventListener: ammgui.eventManager.EventListener
local ScrollbarEventListener = class.create("ScrollbarEventListener", eventManager.EventListener)

--- @param parent ammgui.component.block.scrollbox.ScrollBox
--- @param direction "x"|"y"
--- @param crossDirection "x"|"y"
---
--- !doctype classmethod
--- @generic T: ammgui.component.block.scrollbox.ScrollbarEventListener
--- @param self T
--- @return T
function ScrollbarEventListener:New(parent, direction, crossDirection)
    self = eventManager.EventListener.New(self)

    --- Parent scrollbox component.
    ---
    --- @type ammgui.component.block.scrollbox.ScrollBox
    self.parent = parent

    --- @private
    --- @type "x"|"y"
    self._direction = direction

    --- @private
    --- @type "x"|"y"
    self._crossDirection = crossDirection

    return self
end

function ScrollbarEventListener:isActive()
    return self.parent:isActive()
end

function ScrollbarEventListener:isDraggable()
    return true
end

function ScrollbarEventListener:onMouseEnter(pos, origin, modifiers)
    self.parent.scrollHover[self._direction] = true
end

function ScrollbarEventListener:onMouseExit(pos, origin, modifiers)
    self.parent.scrollHover[self._direction] = false
end

function ScrollbarEventListener:onDragStart(pos, origin, modifiers, target)
    local scrollableSize = self.parent.usedLayout.actualBorderBoxSize[self._direction]
    local viewportSize = self.parent.usedLayout.resolvedBorderBoxSize[self._direction]

    if viewportSize + 0.5 >= scrollableSize then
        return false
    end

    local scrollPosA = 0
    local scrollPosB = math.max(0, scrollableSize - viewportSize)
    local scrollPos = math.max(scrollPosA, math.min(scrollPosB, self.parent.scroll[self._direction]))
    local scrollPosRatio = (scrollPos - scrollPosA) / (scrollPosB - scrollPosA)

    local scrollHandleSize = math.min(viewportSize, math.max(25, viewportSize * viewportSize / scrollableSize))
    local scrollHandlePosA = scrollHandleSize / 2
    local scrollHandlePosB = viewportSize - scrollHandlePosA

    self._scrollHandleOrigPos = scrollHandlePosA + (scrollHandlePosB - scrollHandlePosA) * scrollPosRatio

    self.parent.scrollDrag[self._direction] = true
    return self:onDrag(pos, origin, modifiers, target)
end

function ScrollbarEventListener:onDrag(pos, origin, modifiers, target)
    local delta = pos[self._direction] - origin[self._direction]

    local scrollableSize = self.parent.usedLayout.actualBorderBoxSize[self._direction]
    local viewportSize = self.parent.usedLayout.resolvedBorderBoxSize[self._direction]

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

    self.parent.scroll[self._direction] = scrollPos
    self.parent.stick[self._direction] = scrollPos >= scrollPosB - 5

    return "none" -- Don't highlight drop zones.
end

function ScrollbarEventListener:onDragEnd(pos, origin, modifiers, target)
    self:onDrag(pos, origin, modifiers, target)
    self._origScroll = nil
    self.parent.scrollDrag[self._direction] = false
end

--- Scroll box component.
---
--- @class ammgui.component.block.scrollbox.ScrollBox: ammgui.component.block.div.Div
ns.ScrollBox = class.create("ScrollBox", div.Div)

ns.ScrollBox.elem = "scroll"

--- @param data ammgui.dom.DivNode
function ns.ScrollBox:onMount(ctx, data)
    div.Div.onMount(self, ctx, data)

    --- @type Vector2D
    self.scroll = structs.Vector2D { 0, 0 }

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
        x = ScrollbarEventListener:New(self, "x", "y"),
        y = ScrollbarEventListener:New(self, "y", "x"),
    }
end

--- @param pos Vector2D
--- @param delta number
--- @param modifiers integer
--- @param propagate boolean
--- @return boolean
function ns.ScrollBox:onMouseWheel(pos, delta, modifiers, propagate)
    propagate = div.Div.onMouseWheel(self, pos, delta, modifiers, propagate)
    if propagate then
        local direction = modifiers & 8 > 0 and "x" or "y" -- Shift pressed?

        local scrollableSize = self.usedLayout.actualBorderBoxSize[direction]
        local viewportSize = self.usedLayout.resolvedBorderBoxSize[direction]

        if viewportSize + 0.5 >= scrollableSize then
            return propagate
        end

        local scrollPosA = 0
        local scrollPosB = math.max(0, scrollableSize - viewportSize)
        local scrollPos = math.max(scrollPosA, math.min(scrollPosB, self.scroll[direction] - delta * self._mouseWheelFactor))

        -- Only propagate event if we scrolled less than 1px.
        propagate = math.abs(scrollPos - self.scroll[direction]) < 1
        self.scroll[direction] = scrollPos
        self.stick[direction] = scrollPos >= scrollPosB - 5
    end
    return propagate
end

function ns.ScrollBox:draw(ctx)
    self:_clampScroll("x")
    self:_clampScroll("y")

    local contentPosition = self.usedLayout.contentPosition - structs.Vector2D {
        math.floor(self.scroll.x), math.floor(self.scroll.y),
    }

    div.Div.draw(self, ctx, contentPosition)

    self:_drawScrollBox(ctx, "x", "y")
    self:_drawScrollBox(ctx, "y", "x")
end

function ns.ScrollBox:_clampScroll(direction)
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

--- @param ctx ammgui.component.context.RenderingContext
function ns.ScrollBox:_drawScrollBox(ctx, direction, crossDirection)
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

    local color = self.css.color
    local scrollColor = structs.Color {
        color.r,
        color.g,
        color.b,
        (self.scrollHover[direction] or self.scrollDrag[direction])
        and 0.4
        or (self:hasPseudoclass("hover") and 0.1 or 0),
    }

    local position = structs.Vector2D {
        [direction] = scrollHandlePos - scrollHandleSize / 2,
        [crossDirection] = self.usedLayout.resolvedBorderBoxSize[crossDirection] - scrollHandleCrossSize - 2,
    }
    local size = structs.Vector2D {
        [direction] = scrollHandleSize,
        [crossDirection] = scrollHandleCrossSize,
    }

    ctx.gpu:drawBox {
        position = position,
        size = size,
        rotation = 0,
        color = scrollColor,
        image = "",
        imageSize = structs.Vector2D { x = 0, y = 0 },
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

return ns
