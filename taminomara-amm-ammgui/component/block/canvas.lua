local class = require "ammcore.class"
local bcom = require "ammgui.component.block"
local fun = require "ammcore.fun"
local eventManager = require "ammgui.eventManager"

--- Canvas component.
---
--- !doctype module
--- @class ammgui.component.block.canvas
local ns = {}

--- Base class for canvas implementations.
---
--- Canvas inherits from an event listener. It will be registered automatically
--- before it is drawn, you don't need to call
--- `~ammgui.component.context.RenderingContext.pushEventListener` yourself.
---
--- If your canvas pushes additional event listeners, make sure that their parent
--- is set to be the canvas itself, and that their ``isActive`` method returns
--- whatever `CanvasBase.isActive` returns.
---
--- @class ammgui.component.block.canvas.CanvasBase: ammgui.eventManager.EventListener
ns.CanvasBase = class.create("CanvasBase", eventManager.EventListener)

--- @param preferredWidth number?
--- @param preferredHeight number?
---
--- !doctype classmethod
--- @generic T: ammgui.component.block.canvas.CanvasBase
--- @param self T
--- @return T
function ns.CanvasBase:New(preferredWidth, preferredHeight)
    self = eventManager.EventListener.New(self)

    --- Preferred intrinsic width.
    ---
    --- Default width for When canvas is not styled by CSS.
    self.preferredWidth = preferredWidth or 100

    --- Preferred intrinsic height.
    ---
    --- Default height for When canvas is not styled by CSS.
    self.preferredHeight = preferredHeight or self.preferredWidth / 2

    --- Preferred intrinsic aspect ratio.
    ---
    --- This value is used to automatically calculate canvas height
    --- when only its width is given. By default, aspect ratio is ``2/1``.
    ---
    --- @type number
    self.aspectRatio = self.preferredWidth / self.preferredHeight

    return self
end

function ns.CanvasBase:isActive()
    if self.parent then
        return self.parent:isActive()
    else
        return false
    end
end

--- This function is called before each render.
---
--- You can do any necessary preparations before drawing here. Most notably,
--- you can measure any strings that you intend to draw using the provided
--- text measuring service.
---
--- !doc virtual
--- @param params any data that was passed to the ``<canvas>`` element.
--- @param textMeasure ammgui.component.context.TextMeasure text measuring service.
function ns.CanvasBase:prepareLayout(params, textMeasure)
end

--- Called to draw the canvas content.
---
--- !doc abstract
--- @param params any data that was passed to the ``<canvas>`` element.
--- @param ctx ammgui.component.context.RenderingContext rendering context.
--- @param size Vector2D canvas size.
function ns.CanvasBase:draw(params, ctx, size)
    error("not implemented")
end

--- Functional implementation of a canvas.
---
--- @class ammgui.component.block.canvas.CanvasFunctional: ammgui.component.block.canvas.CanvasBase
ns.CanvasFunctional = class.create("CanvasFunctional", ns.CanvasBase)

--- @param cb fun(params: any, ctx: ammgui.component.context.RenderingContext, size: Vector2D)
--- @param preferredWidth number?
--- @param preferredHeight number?
---
--- !doctype classmethod
--- @generic T: ammgui.component.block.canvas.CanvasFunctional
--- @param self T
--- @return T
function ns.CanvasFunctional:New(cb, preferredWidth, preferredHeight)
    self = ns.CanvasBase.New(self, preferredWidth, preferredHeight)

    --- @private
    --- @type fun(params: any, ctx: ammgui.component.context.RenderingContext, size: Vector2D)
    self._cb = cb

    return self
end

function ns.CanvasFunctional:draw(params, ctx, size)
    self._cb(params, ctx, size)
end

--- Canvas component.
---
--- @class ammgui.component.block.canvas.Canvas: ammgui.component.block.Component
ns.Canvas = class.create("Canvas", bcom.Component)

ns.Canvas.elem = "canvas"

--- @param data ammgui.dom.CanvasNode
function ns.Canvas:onMount(ctx, data)
    bcom.Component.onMount(self, ctx, data)

    --- @private
    --- @type fun(...): ammgui.dom.CanvasBase
    self._factory = data._factory --- @diagnostic disable-line: invisible

    --- @private
    --- @type any[]
    self._args = data._args --- @diagnostic disable-line: invisible

    --- @private
    --- @type ammgui.component.block.canvas.CanvasBase
    self._canvas = self._factory(table.unpack(self._args))
    self._canvas.parent = self

    --- @private
    --- @type any
    self._params = data
end

--- @param data ammgui.dom.CanvasNode
function ns.Canvas:onUpdate(ctx, data)
    bcom.Component.onUpdate(self, ctx, data)

    --- @diagnostic disable-next-line: invisible
    if data._factory ~= self._factory or data._args ~= self._args then
        self._factory = data._factory --- @diagnostic disable-line: invisible
        self._args = data._args       --- @diagnostic disable-line: invisible
        self._canvas = self._factory(table.unpack(self._args))
        self._canvas.parent = self
        self.outdated = true          -- Intrinsic sizes could've change.
    end

    self.outdated = self.outdated or not fun.t.deepEq(data, self._params)

    self._params = data
end

function ns.Canvas:propagateCssChanges(ctx)
end

function ns.Canvas:prepareLayout(textMeasure)
    bcom.Component.prepareLayout(self, textMeasure)
    self._canvas:prepareLayout(self._params, textMeasure)
end

function ns.Canvas:calculateIntrinsicContentWidth()
    return self._canvas.preferredWidth, self._canvas.preferredWidth, true, self._canvas.aspectRatio
end

function ns.Canvas:draw(ctx)
    bcom.Component.draw(self, ctx)
    local visible = ctx:pushLayout(self.usedLayout.contentPosition, self.usedLayout.visibleContentSize, true)
    if visible then
        ctx:pushEventListener(structs.Vector2D { 0, 0 }, self.usedLayout.visibleContentSize, self._canvas)
        self._canvas:draw(self._params, ctx, self.usedLayout.resolvedContentSize)
    end
    ctx:popLayout()
end

return ns
