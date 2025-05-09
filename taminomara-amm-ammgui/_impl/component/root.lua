local class = require "ammcore.class"
local node = require "ammgui._impl.component.node"

--- Root component.
---
--- !doctype module
--- @class ammgui._impl.component.root
local ns = {}

--- Root component.
---
--- @class ammgui._impl.component.root.Root: ammgui._impl.component.node.Node
ns.Root = class.create("Root", node.Node)

--- @param ctx ammgui._impl.context.sync.Context
--- @param data ammgui.dom.AnyNode
function ns.Root:onMount(ctx, data)
    self:setPseudoclass("root")
    node.Node.onMount(self, ctx, self:_makeNode(data))
end

--- @param ctx ammgui._impl.context.sync.Context
--- @param data ammgui.dom.AnyNode
function ns.Root:onUpdate(ctx, data)
    node.Node.onUpdate(self, ctx, self:_makeNode(data))
end

--- @param data ammgui.dom.AnyNode
--- @return ammgui.dom.Node
function ns.Root:_makeNode(data)
    return {
        _isNode = true,
        _component = self,
        _tag = "html",
        {
            _isNode = true,
            _component = node.Node,
            _tag = "body",
            data
        },
    }
end

return ns
