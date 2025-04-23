local class = require "ammcore.class"
local base = require "ammgui.component.base"

--- List component.
---
--- !doctype module
--- @class ammgui.component.block.list
local ns = {}

--- List component.
---
--- @class ammgui.component.block.list.List: ammgui.component.base.ComponentProvider
ns.List = class.create("List", base.ComponentProvider)

--- @param data ammgui.dom.ListNode
function ns.List:onMount(ctx, data)
    --- @private
    --- @type ammgui.component.base.ComponentProvider[]
    self._providers = base.Component.syncProviders(ctx, {}, data)
end

--- @param data ammgui.dom.ListNode
function ns.List:onUpdate(ctx, data)
    self._providers = base.Component.syncProviders(ctx, self._providers, data)
end

function ns.List:onUnmount(ctx)
    for _, provider in ipairs(self._providers) do
        provider:onUnmount(ctx)
    end
end

function ns.List:collect(components)
    for _, provider in ipairs(self._providers) do
        provider:collect(components)
    end
end

function ns.List:noteRef(ref)
    if #self._providers > 0 then
        self._providers[1]:noteRef(ref)
    end
end

return ns
