local class = require "ammcore.class"
local component = require "ammgui._impl.component.component"
local fun = require "ammcore.fun"
local block = require "ammgui._impl.layout.block"
local flex = require "ammgui._impl.layout.flex"

--- A node component, implements an HTML tag.
---
--- !doctype module
--- @class ammgui._impl.component.node
local ns = {}

--- A node component, implements an HTML tag.
---
--- @class ammgui._impl.component.node.Node: ammgui._impl.component.component.Component
ns.Node = class.create("Node", component.Component)

--- @type ammgui._impl.layout.node.Node
ns.Node.layout = nil

--- @param key any?
---
--- !doctype classmethod
--- @generic T: ammgui._impl.component.node.Node
--- @param self T
--- @return T
function ns.Node:New(key)
    self = component.Component.New(self, key)

    --- @type ammgui._impl.component.component.Component[]?
    self._children = {}

    --- @type ammgui._impl.component.provider.Provider[]
    self._childComponents = {}

    return self
end

--- @param data ammgui.dom.ContainerNode
function ns.Node:onMount(ctx, data)
    component.Component.onMount(self, ctx, data)

    self._childComponents, self._children = self.syncAll(ctx, {}, data, self)
end

--- @param data ammgui.dom.ContainerNode
function ns.Node:onUpdate(ctx, data)
    component.Component.onUpdate(self, ctx, data)

    local childComponents, children = self.syncAll(ctx, self._childComponents, data, self)

    self.cssOutdated =
        self.cssOutdated
        or fun.a.any(children, fun.get("cssOutdated"))
    self.layoutOutdated =
        self.layoutOutdated
        or fun.a.any(children, fun.get("layoutOutdated"))
        or not fun.a.eq(children, self._children)

    self._childComponents = childComponents
    self._children = children
end

function ns.Node:onMouseEnter(pos, modifiers)
    self.layout:onMouseEnter(pos, modifiers) -- For scroll bars.
    return component.Component.onMouseEnter(self, pos, modifiers)
end

function ns.Node:onMouseExit(pos, modifiers)
    self.layout:onMouseExit(pos, modifiers) -- For scroll bars.
    return component.Component.onMouseExit(self, pos, modifiers)
end

function ns.Node:onMouseWheel(pos, delta, modifiers, propagate)
    propagate = component.Component.onMouseWheel(self, pos, delta, modifiers, propagate)
    if propagate then -- For scroll bars.
        propagate = self.layout:onMouseWheel(pos, delta, modifiers, propagate)
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Node:propagateCssChanges(ctx)
    for _, child in ipairs(self._children) do
        child:syncCss(ctx)
        self.layoutOutdated = self.layoutOutdated or child.layoutOutdated
    end
end

function ns.Node:makeLayout()
    local children = fun.a.map(self._children, function(child)
        if child.css.display ~= "none" then
            return child.layout
        end
    end)

    if self.css.display == "flex" then
        return flex.Flex:New(self.css, children, self, self.layout)
    else -- "block", "inline", "inline-block"
        return block.Block:New(self.css, children, self, self.layout)
    end
end

function ns.Node:updateLayoutTree()
    for _, child in ipairs(self._children) do
        child:updateLayoutTree()
    end

    component.Component.updateLayoutTree(self)
end

function ns.Node:devtoolsRepr()
    return fun.t.update(
        component.Component.devtoolsRepr(self),
        {
            children = fun.a.map(self._children, fun.call_meth("devtoolsRepr")),
        }
    )
end

return ns
