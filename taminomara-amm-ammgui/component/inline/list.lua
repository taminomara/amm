local class = require "ammcore.class"
local icom = require "ammgui.component.inline"

--- List component.
---
--- !doctype module
--- @class ammgui.component.inline.list
local ns = {}

--- List component.
---
--- @class ammgui.component.inline.list.List: ammgui.component.inline.ComponentProvider
ns.List = class.create("List", icom.ComponentProvider)

--- @param data ammgui.dom.IListNode
function ns.List:onMount(data)
    --- @private
    --- @type ammgui.component.inline.ComponentProvider[]
    self._providers = icom.Component.syncProviders({}, data.nodes)
end

--- @param data ammgui.dom.IListNode
function ns.List:onUpdate(data)
    self._providers = icom.Component.syncProviders(self._providers, data.nodes)
end

function ns.List:onUnmount()
    for _, provider in ipairs(self._providers) do
        provider:onUnmount()
    end
end

function ns.List:collect(components)
    for _, provider in ipairs(self._providers) do
        provider:collect(components)
    end
end

return ns
