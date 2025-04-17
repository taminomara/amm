local class = require "ammcore.class"
local bcom = require "ammgui.component.block"

--- List component.
---
--- !doctype module
--- @class ammgui.component.block.list
local ns = {}

--- List component.
---
--- @class ammgui.component.block.list.List: ammgui.component.block.ComponentProvider
ns.List = class.create("List", bcom.ComponentProvider)

--- @param data ammgui.dom.ListNode
function ns.List:onMount(ctx, data)
    --- @private
    --- @type ammgui.component.block.ComponentProvider[]
    self._providers = bcom.Component.syncProviders(ctx, {}, data.nodes)
end

--- @param data ammgui.dom.ListNode
function ns.List:onUpdate(ctx, data)
    self._providers = bcom.Component.syncProviders(ctx, self._providers, data.nodes)
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
