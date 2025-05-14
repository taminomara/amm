local class = require "ammcore.class"
local blockBase = require "ammgui._impl.layout.blockBase"

--- Base for replaced components, i.e. images and canvases.
---
--- !doctype module
--- @class ammgui._impl.layout.replaced
local ns = {}

--- Base for replaced components, i.e. images and canvases.
---
--- Replaced components don't have children, and can't have layout on their own.
--- Instead, they are just opaque boxes with preferred dimensions and aspect ratio.
---
--- @class ammgui._impl.layout.replaced.Replaced: ammgui._impl.layout.blockBase.BlockBase
ns.Replaced = class.create("Replaced", blockBase.BlockBase)

--- @param css ammgui._impl.css.resolved.Resolved
--- @param preferredWidth number?
--- @param preferredHeight number?
--- @param nodeEventListener ammgui._impl.eventListener.EventListener
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.replaced.Replaced
--- @param self T
--- @return T
function ns.Replaced:New(css, preferredWidth, preferredHeight, nodeEventListener)
    self = blockBase.BlockBase.New(self, css)

    --- Preferred intrinsic width of this component.
    ---
    --- @type number
    self.preferredWidth = nil

    --- Preferred intrinsic width of this component.
    ---
    --- @type number
    self.preferredHeight = nil

    if not preferredWidth and not preferredHeight then
        self.preferredWidth, self.preferredHeight = 300, 150
    elseif not preferredWidth then
        self.preferredWidth, self.preferredHeight = preferredHeight * 2, self.preferredHeight
    elseif not preferredHeight then
        self.preferredWidth, self.preferredHeight = self.preferredWidth, preferredWidth / 2
    else
        self.preferredWidth, self.preferredHeight = preferredWidth, preferredHeight
    end

    --- @private
    --- @type ammgui._impl.eventListener.EventListener
    self._nodeEventListener = nodeEventListener

    return self
end

function ns.Replaced:calculateIntrinsicContentWidth()
    return
        self.preferredWidth,
        self.preferredWidth,
        true,
        self.preferredWidth / self.preferredHeight
end

function ns.Replaced:calculateContentLayout(availableWidth, availableHeight)
    error("replaced elements can't have content layout")
end

function ns.Replaced:draw(ctx)
    blockBase.BlockBase.draw(self, ctx)
    ctx:pushEventListener(
        Vec2:New(0, 0),
        self.usedLayout.resolvedBorderBoxSize,
        self._nodeEventListener
    )
    ctx:noteDebugTarget(
        Vec2:New(0, 0),
        self.usedLayout.resolvedBorderBoxSize,
        self,
        self._nodeEventListener.id
    )
end

return ns
