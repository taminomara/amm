local class = require "ammcore.class"
local replaced = require "ammgui._impl.layout.replaced"

--- Canvas layout.
---
--- !doctype module
--- @class ammgui._impl.layout.canvas
local ns = {}

--- Canvas layout.
---
--- @class ammgui._impl.layout.canvas.Canvas: ammgui._impl.layout.replaced.Replaced
ns.Canvas = class.create("Canvas", replaced.Replaced)

--- @param canvas ammgui.CanvasBase
--- @param css ammgui._impl.css.resolved.Resolved
--- @param nodeEventListener ammgui._impl.eventListener.EventListener
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.canvas.Canvas
--- @param self T
--- @return T
function ns.Canvas:New(canvas, css, nodeEventListener)
    self = replaced.Replaced.New(self, css, canvas.preferredWidth, canvas.preferredHeight, nodeEventListener)

    --- @type ammgui.CanvasBase
    self.canvas = canvas

    return self
end

function ns.Canvas:prepareLayout(textMeasure)
    self.canvas:prepareLayout(textMeasure)
end

function ns.Canvas:draw(ctx)
    replaced.Replaced.draw(self, ctx)

    local visible = ctx:pushLayout(
        self.usedLayout.contentPosition,
        self.usedLayout.resolvedContentSize,
        true
    )
    if visible then
        ctx:pushEventListener(
            Vec2:New(0, 0),
            self.usedLayout.resolvedContentSize,
            self.canvas
        )
        self.canvas:draw(ctx, self.usedLayout.resolvedContentSize)
    end
    ctx:popLayout()
end

return ns
