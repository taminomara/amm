local class = require "ammcore.class"
local icom = require "ammgui.component.inline"
local fun = require "ammcore.fun"

--- Implements wrapper to turn ``block`` components into ``inline-block`` components.
---
--- !doctype module
--- @class ammgui.component.inline.block
local ns = {}

--- Implements a string component.
---
--- @class ammgui.component.inline.block.Block: ammgui.component.inline.Component
ns.Block = class.create("Block", icom.Component)

ns.Block.elem = ""

--- @param data ammgui.dom.Node
function ns.Block:onMount(ctx, data)
    icom.Component.onMount(self, ctx, data)

    --- @private
    --- @type ammgui.component.base.ComponentProvider[]
    self._providers = nil

    --- @private
    --- @type ammgui.component.base.Component[]
    self._children = nil

    self._providers, self._children = icom.Component.syncAll(ctx, {}, {}, data, self)
end

--- @param data ammgui.dom.Node
function ns.Block:onUpdate(ctx, data)
    icom.Component.onUpdate(self, ctx, data)

    local providers, children, outdated, outdatedCss = icom.Component.syncAll(
        ctx, self._providers, self._children, data, self)

    self._providers = providers
    self._children = children
    self.outdated = self.outdated or outdated
    self.outdatedCss = self.outdatedCss or outdatedCss
end

function ns.Block:propagateCssChanges(ctx)
    for _, child in ipairs(self._children) do
        child:updateCss(ctx)
        self.outdated = self.outdated or child.outdated
    end
    icom.Component:propagateCssChanges(ctx)
end

function ns.Block:calculateElements()
    local result = {}

    for _, child in ipairs(self._children) do
        if class.isChildOf(child, icom.Component) then
            --- @cast child ammgui.component.inline.Component
            fun.a.extend(result, child:getElements())
        else
            --- @cast child ammgui.component.block.Component
            table.insert(result, ns.BlockElement:New(child, self.css, self))
        end
    end

    return result
end

function ns.Block:reprChildren()
    return fun.a.map(self._children, function(x) return x:repr() end)
end

--- A single word or whitespace.
---
--- @class ammgui.component.inline.block.BlockElement: ammgui.component.inline.Element
ns.BlockElement = class.create("BlockElement", icom.Element)

--- @param block ammgui.component.block.Component
--- @param css ammgui.css.rule.Resolved
--- @param parent ammgui.component.inline.Component
---
--- !doctype classmethod
--- @generic T: ammgui.component.inline.block.BlockElement
--- @param self T
--- @return T
function ns.BlockElement:New(block, css, parent)
    self = icom.Element.New(self, css, parent)

    --- Wrapped block component.
    ---
    --- @type ammgui.component.block.Component
    self.block = block

    return self
end

function ns.BlockElement:prepareLayout(textMeasure)
    self.block:prepareLayout(textMeasure)
end

return ns
