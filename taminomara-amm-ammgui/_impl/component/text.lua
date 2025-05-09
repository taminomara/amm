local class = require "ammcore.class"
local component = require "ammgui._impl.component.component"
local text = require "ammgui._impl.layout.text"
local fun = require "ammcore.fun"

--- Text fragment.
---
--- !doctype module
--- @class ammgui._impl.component.text
local ns = {}

--- Text fragment.
---
--- @class ammgui._impl.component.text.Text: ammgui._impl.component.component.Component
ns.Text = class.create("Text", component.Component)

function ns.Text:onMount(ctx, data)
    local text = table.concat(data)
    self.layoutOutdated = self._text ~= text
    self._text = text
end

function ns.Text:onUpdate(ctx, data)
    local text = table.concat(data)
    self.layoutOutdated = self._text ~= text
    self._text = text
end

function ns.Text:noteRef(ref)
    ref.current = nil -- Text fragments can't be referenced.
end

function ns.Text:makeLayout()
    return text.Text:New(self.css, self._text or "")
end

--- @return ammgui._impl.devtools.Element
function ns.Text:devtoolsRepr()
    return fun.t.update(
        component.Component.devtoolsRepr(self),
        {
            inlineContent = self._text,
        }
    )
end

return ns
