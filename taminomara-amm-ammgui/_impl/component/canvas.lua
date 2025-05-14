---@diagnostic disable: invisible

local class = require "ammcore.class"
local component = require "ammgui._impl.component.component"
local canvas = require "ammgui._impl.layout.canvas"

--- Canvas component.
---
--- !doctype module
--- @class ammgui._impl.component.canvas
local ns = {}

--- Canvas component.
---
--- @class ammgui._impl.component.canvas.Canvas: ammgui._impl.component.component.Component
ns.Canvas = class.create("Canvas", component.Component)

--- @type ammgui._impl.layout.canvas.Canvas
ns.Canvas.layout = nil

--- @param data ammgui.dom.CanvasNode
function ns.Canvas:onMount(ctx, data)
    component.Component.onMount(self, ctx, data)

    self:_newCanvas(data)

    self._canvas:onMount(data)
end

--- @param data ammgui.dom.CanvasNode
function ns.Canvas:onUpdate(ctx, data)
    component.Component.onUpdate(self, ctx, data)

    if data._factory ~= self._factory or data._args ~= self._args then
        self:_newCanvas(data)
    end

    self._canvas:onUpdate(data)

    self.layoutOutdated = self.layoutOutdated
        or self._canvas.preferredWidth ~= self.layout.preferredWidth
        or self._canvas.preferredHeight ~= self.layout.preferredHeight
end

function ns.Canvas:makeLayout()
    return canvas.Canvas:New(self._canvas, self.css, self)
end

function ns.Canvas:updateLayout()
    component.Component.updateLayout(self)
    self.layout.canvas = self._canvas
end

function ns.Canvas:_newCanvas(data)
    if self._canvas then
        self._canvas._isActive = false
    end

    self._factory = data._factory
    self._args = data._args
    self._canvas = self._factory(table.unpack(self._args))
    self._canvas.parent = self
end

return ns
