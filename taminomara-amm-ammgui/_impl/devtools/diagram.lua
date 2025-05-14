local dom = require "ammgui.dom"
local class = require "ammcore.class"
local eventListener = require "ammgui._impl.eventListener"
local api = require "ammgui.api"

--- !doctype module
--- @class ammgui._impl.devtools.diagram
local ns = {}

--- @class ammgui._impl.devtools._LayoutDiagramEventListener: ammgui._impl.eventListener.EventListener
local LayoutDiagramEventListener = class.create("LayoutDiagramEventListener", eventListener.EventListener)

--- @param kind "content"|"padding"|"outline"|"margin"
--- @param parent ammgui._impl.devtools.LayoutDiagram
---
--- !doctype classmethod
--- @generic T: ammgui._impl.devtools._LayoutDiagramEventListener
--- @param self T
--- @return T
function LayoutDiagramEventListener:New(kind, parent)
    self = eventListener.EventListener.New(self)

    --- @type fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)?
    self.setHighlightedId = nil

    --- @type ammgui._impl.id.EventListenerId?
    self.highlightedId = nil

    --- @type "content"|"padding"|"outline"|"margin"
    self.kind = kind

    --- @type ammgui._impl.devtools.LayoutDiagram
    self.parent = parent

    return self
end

function LayoutDiagramEventListener:isActive()
    return self.parent:isActive()
end

function LayoutDiagramEventListener:onMouseEnter(pos, modifiers)
    if self.highlightedId and self.setHighlightedId then
        self.setHighlightedId(
            self.highlightedId,
            self.kind == "content",
            self.kind == "padding",
            self.kind == "outline",
            self.kind == "margin"
        )
        self.parent.hoverKind = self.kind
    end
end

function LayoutDiagramEventListener:onMouseExit(pos, modifiers)
    if self.setHighlightedId then
        self.setHighlightedId(nil)
        self.parent.hoverKind = nil
    end
end

--- @class ammgui._impl.devtools.LayoutDiagramParams: ammgui.dom.NodeParams
--- @field contentSize ammgui.Vec2
--- @field marginBottom number
--- @field marginLeft number
--- @field marginRight number
--- @field marginTop number
--- @field outline number
--- @field paddingBottom number
--- @field paddingLeft number
--- @field paddingRight number
--- @field paddingTop number
--- @field highlightedId ammgui._impl.id.EventListenerId
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)

--- @class ammgui._impl.devtools.LayoutDiagram: ammgui.CanvasBase
local LayoutDiagram = class.create("LayoutDiagram", api.CanvasBase)

function LayoutDiagram:New()
    self = api.CanvasBase.New(self)

    self._marginListener = LayoutDiagramEventListener:New("margin", self)
    self._outlineListener = LayoutDiagramEventListener:New("outline", self)
    self._paddingListener = LayoutDiagramEventListener:New("padding", self)
    self._contentListener = LayoutDiagramEventListener:New("content", self)

    --- @type "content"|"padding"|"outline"|"margin"|nil
    self.hoverKind = nil

    return self
end

--- @param data ammgui._impl.devtools.LayoutDiagramParams
function LayoutDiagram:onMount(data)
    LayoutDiagram.onUpdate(self, data)
end

--- @param data ammgui._impl.devtools.LayoutDiagramParams
function LayoutDiagram:onUpdate(data)
    self._contentListener.highlightedId = data.highlightedId
    self._contentListener.setHighlightedId = data.setHighlightedId
    self._paddingListener.highlightedId = data.highlightedId
    self._paddingListener.setHighlightedId = data.setHighlightedId
    self._outlineListener.highlightedId = data.highlightedId
    self._outlineListener.setHighlightedId = data.setHighlightedId
    self._marginListener.highlightedId = data.highlightedId
    self._marginListener.setHighlightedId = data.setHighlightedId

    local near = function(a, b)
        if a and b then
            local d = a - b
            return -1e-5 < d and d < 1e-5
        else
            return false
        end
    end
    local makeText = function(size)
        if -1e-5 < size and size < 1e-5 then
            return ""
        else
            return string.format("%0.2f", size)
        end
    end

    if not near(self._outline, data.outline) then
        self._outline = data.outline
        self._outlineText = makeText(data.outline)
        self._outlineTextSize = nil
    end
    if not near(self._paddingTop, data.paddingTop) then
        self._paddingTop = data.paddingTop
        self._paddingTopText = makeText(data.paddingTop)
        self._paddingTopTextSize = nil
    end
    if not near(self._paddingBottom, data.paddingBottom) then
        self._paddingBottom = data.paddingBottom
        self._paddingBottomText = makeText(data.paddingBottom)
        self._paddingBottomTextSize = nil
    end
    if not near(self._paddingLeft, data.paddingLeft) then
        self._paddingLeft = data.paddingLeft
        self._paddingLeftText = makeText(data.paddingLeft)
        self._paddingLeftTextSize = nil
    end
    if not near(self._paddingRight, data.paddingRight) then
        self._paddingRight = data.paddingRight
        self._paddingRightText = makeText(data.paddingRight)
        self._paddingRightTextSize = nil
    end
    if not near(self._marginTop, data.marginTop) then
        self._marginTop = data.marginTop
        self._marginTopText = makeText(data.marginTop)
        self._marginTopTextSize = nil
    end
    if not near(self._marginBottom, data.marginBottom) then
        self._marginBottom = data.marginBottom
        self._marginBottomText = makeText(data.marginBottom)
        self._marginBottomTextSize = nil
    end
    if not near(self._marginLeft, data.marginLeft) then
        self._marginLeft = data.marginLeft
        self._marginLeftText = makeText(data.marginLeft)
        self._marginLeftTextSize = nil
    end
    if not near(self._marginRight, data.marginRight) then
        self._marginRight = data.marginRight
        self._marginRightText = makeText(data.marginRight)
        self._marginRightTextSize = nil
    end
    if not near(self._contentSizeX, data.contentSize.x) or not near(self._contentSizeY, data.contentSize.y) then
        self._contentSizeX = data.contentSize.x
        self._contentSizeY = data.contentSize.y
        self._contentSizeText = string.format("%0.2f×%0.2f", data.contentSize.x, data.contentSize.y)
        self._contentSizeTextSize = nil
    end
end

function LayoutDiagram:prepareLayout(textMeasure)
    local setSize = function(name) return function(s) self[name] = s end end

    if not self._outlineTextSize then
        textMeasure:addRequest(self._outlineText, 10, false, setSize("_outlineTextSize"))
    end
    if not self._paddingTopTextSize then
        textMeasure:addRequest(self._paddingTopText, 10, false, setSize("_paddingTopTextSize"))
    end
    if not self._paddingBottomTextSize then
        textMeasure:addRequest(self._paddingBottomText, 10, false, setSize("_paddingBottomTextSize"))
    end
    if not self._paddingLeftTextSize then
        textMeasure:addRequest(self._paddingLeftText, 10, false, setSize("_paddingLeftTextSize"))
    end
    if not self._paddingRightTextSize then
        textMeasure:addRequest(self._paddingRightText, 10, false, setSize("_paddingRightTextSize"))
    end
    if not self._marginTopTextSize then
        textMeasure:addRequest(self._marginTopText, 10, false, setSize("_marginTopTextSize"))
    end
    if not self._marginBottomTextSize then
        textMeasure:addRequest(self._marginBottomText, 10, false, setSize("_marginBottomTextSize"))
    end
    if not self._marginLeftTextSize then
        textMeasure:addRequest(self._marginLeftText, 10, false, setSize("_marginLeftTextSize"))
    end
    if not self._marginRightTextSize then
        textMeasure:addRequest(self._marginRightText, 10, false, setSize("_marginRightTextSize"))
    end
    if not self._contentSizeTextSize then
        textMeasure:addRequest(self._contentSizeText, 10, false, setSize("_contentSizeTextSize"))
    end
end

function LayoutDiagram:draw(ctx, size)
    local contentSize = Vec2:New(
        math.max(100, self._contentSizeTextSize.x + 10),
        self._contentSizeTextSize.y + 8
    )
    local paddingSize = Vec2:New(
        contentSize.x + 2 * math.max(self._paddingLeftTextSize.x, self._paddingRightTextSize.x, 25) + 20,
        contentSize.y * 3
    )
    local outlineSize = Vec2:New(
        paddingSize.x + 2 * math.max(self._outlineTextSize.x, 25) + 20,
        contentSize.y * 5
    )
    local marginSize = Vec2:New(
        outlineSize.x + 2 * math.max(self._marginLeftTextSize.x, self._marginRightTextSize.x, 25) + 20,
        contentSize.y * 7
    )

    local marginColor =
        (not self.hoverKind or self.hoverKind == "margin")
        and structs.Color { 0x44 / 0xff, 0x27 / 0xff, 0x24 / 0xff, 1 }
        or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
    local marginOutlineColor = structs.Color { 0xEC / 0xff, 0x8F / 0xff, 0x82 / 0xff, 1 }
    self:_drawBox(ctx, marginSize, marginColor, marginOutlineColor, size)
    ctx:pushEventListener((size - marginSize) * 0.5, marginSize, self._marginListener)

    local outlineColor =
        (not self.hoverKind or self.hoverKind == "outline")
        and structs.Color { 0x4B / 0xff, 0x2D / 0xff, 0x08 / 0xff, 1 }
        or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
    local outlineOutlineColor = structs.Color { 0xC9 / 0xff, 0x85 / 0xff, 0x31 / 0xff, 1 }
    self:_drawBox(ctx, outlineSize, outlineColor, outlineOutlineColor, size)
    ctx:pushEventListener((size - outlineSize) * 0.5, outlineSize, self._outlineListener)

    local paddingColor =
        (not self.hoverKind or self.hoverKind == "padding")
        and structs.Color { 0x3B / 0xff, 0x39 / 0xff, 0x4A / 0xff, 1 }
        or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
    local paddingOutlineColor = structs.Color { 0xA4 / 0xff, 0xA0 / 0xff, 0xC6 / 0xff, 1 }
    self:_drawBox(ctx, paddingSize, paddingColor, paddingOutlineColor, size)
    ctx:pushEventListener((size - paddingSize) * 0.5, paddingSize, self._paddingListener)

    local contentColor =
        (not self.hoverKind or self.hoverKind == "content")
        and structs.Color { 0x17 / 0xff, 0x3D / 0xff, 0x4D / 0xff, 1 }
        or structs.Color { 0x10 / 0xff, 0x10 / 0xff, 0x10 / 0xff, 1 }
    local contentOutlineColor = structs.Color { 0x54 / 0xff, 0xA9 / 0xff, 0xCE / 0xff, 1 }
    self:_drawBox(ctx, contentSize, contentColor, contentOutlineColor, size)
    ctx:pushEventListener((size - contentSize) * 0.5, contentSize, self._contentListener)

    ctx.gpu:drawText(
        (size - marginSize) * 0.5 + Vec2:New(5, 4), "Margin", 10, marginOutlineColor, false
    )
    ctx.gpu:drawText(
        (size - outlineSize) * 0.5 + Vec2:New(5, 4), "Outline", 10, outlineOutlineColor, false
    )
    ctx.gpu:drawText(
        (size - paddingSize) * 0.5 + Vec2:New(5, 4), "Padding", 10, paddingOutlineColor, false
    )

    ctx.gpu:drawText(
        (size - self._contentSizeTextSize) * 0.5, self._contentSizeText, 10, contentOutlineColor, false
    )

    self:_drawText(ctx, paddingSize, Vec2:New(0, -1), self._paddingTopText, self._paddingTopTextSize,
        paddingOutlineColor, size)
    self:_drawText(ctx, paddingSize, Vec2:New(0, 1), self._paddingBottomText, self._paddingBottomTextSize,
        paddingOutlineColor, size)
    self:_drawText(ctx, paddingSize, Vec2:New(-1, 0), self._paddingLeftText, self._paddingLeftTextSize,
        paddingOutlineColor, size)
    self:_drawText(ctx, paddingSize, Vec2:New(1, 0), self._paddingRightText, self._paddingRightTextSize,
        paddingOutlineColor, size)

    self:_drawText(ctx, outlineSize, Vec2:New(0, -1), self._outlineText, self._outlineTextSize, outlineOutlineColor,
        size)
    self:_drawText(ctx, outlineSize, Vec2:New(0, 1), self._outlineText, self._outlineTextSize, outlineOutlineColor,
        size)
    self:_drawText(ctx, outlineSize, Vec2:New(-1, 0), self._outlineText, self._outlineTextSize, outlineOutlineColor,
        size)
    self:_drawText(ctx, outlineSize, Vec2:New(1, 0), self._outlineText, self._outlineTextSize, outlineOutlineColor,
        size)

    self:_drawText(ctx, marginSize, Vec2:New(0, -1), self._marginTopText, self._marginTopTextSize, marginOutlineColor,
        size)
    self:_drawText(ctx, marginSize, Vec2:New(0, 1), self._marginBottomText, self._marginBottomTextSize,
        marginOutlineColor, size)
    self:_drawText(ctx, marginSize, Vec2:New(-1, 0), self._marginLeftText, self._marginLeftTextSize,
        marginOutlineColor, size)
    self:_drawText(ctx, marginSize, Vec2:New(1, 0), self._marginRightText, self._marginRightTextSize,
        marginOutlineColor, size)
end

function LayoutDiagram:_drawBox(ctx, size, color, outlineColor, canvasSize)
    ctx.gpu:drawBox {
        position = canvasSize * 0.5,
        size = size,
        rotation = 0,
        color = color,
        image = "",
        imageSize = Vec2:New(0, 0),
        hasCenteredOrigin = true,
        horizontalTiling = false,
        verticalTiling = false,
        isBorder = false,
        margin = { top = 0, right = 0, bottom = 0, left = 0 },
        isRounded = true,
        radii = structs.Vector4 { 0, 0, 0, 0 },
        hasOutline = true,
        outlineThickness = 1,
        outlineColor = outlineColor - structs.Color { 0, 0, 0, 0.9 },
    }
end

function LayoutDiagram:_drawText(ctx, size, direction, text, textSize, color, canvasSize)
    local pos = (canvasSize + Vec2:New(
        (size.x - 10) * direction.x - textSize.x * (direction.x + 1),
        (size.y - 8) * direction.y - textSize.y * (direction.y + 1)
    )) / 2

    ctx.gpu:drawText(pos, text, 10, color, false)
end

--- @type fun(params: ammgui._impl.devtools.LayoutDiagramParams): ammgui.dom.CanvasNode
ns.layoutDiagram = dom.Canvas(LayoutDiagram.New, LayoutDiagram)

return ns
