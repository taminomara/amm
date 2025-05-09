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
---
--- !doctype classmethod
--- @generic T: ammgui._impl.layout.replaced.Replaced
--- @param self T
--- @return T
function ns.Replaced:New(css, preferredWidth, preferredHeight)
    self = blockBase.BlockBase.New(self, css)

    --- @protected
    --- @type number
    self._preferredWidth = nil

    --- @protected
    --- @type number
    self._preferredHeight = nil

    if not preferredWidth and not preferredHeight then
        self._preferredWidth, self._preferredHeight = 300, 150
    elseif not preferredWidth then
        self._preferredWidth, self._preferredHeight = preferredHeight * 2, self._preferredHeight
    elseif not preferredHeight then
        self._preferredWidth, self._preferredHeight = self._preferredWidth, preferredWidth / 2
    else
        self._preferredWidth, self._preferredHeight = preferredWidth, preferredHeight
    end

    return self
end

function ns.Replaced:calculateIntrinsicContentWidth()
    return
        self._preferredWidth,
        self._preferredWidth,
        true,
        self._preferredWidth / self._preferredHeight
end

function ns.Replaced:calculateContentLayout(availableWidth, availableHeight)
    error("replaced elements can't have content layout")
end

return ns
