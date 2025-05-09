local class = require "ammcore.class"
local component = require "ammgui._impl.component.provider"

--- List of components.
---
--- !doctype module
--- @class ammgui._impl.component.list
local ns = {}

--- List of components.
---
--- @class ammgui._impl.component.list.List: ammgui._impl.component.provider.Provider
ns.List = class.create("List", component.Provider)

function ns.List:onMount(ctx, data)
    self._providers = self.syncProviders(ctx, {}, data)
end

function ns.List:onUpdate(ctx, data)
    self._providers = self.syncProviders(ctx, self._providers, data)
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
