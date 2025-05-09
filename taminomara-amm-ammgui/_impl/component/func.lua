---@diagnostic disable: invisible

local class = require "ammcore.class"
local fun = require "ammcore.fun"
local provider = require "ammgui._impl.component.provider"
local api = require "ammgui.api"
local list = require "ammgui._impl.component.list"

--- Functional component.
---
--- !doctype module
--- @class ammgui._impl.component.func
local ns = {}

--- Functional component.
---
--- @class ammgui._impl.component.func.Functional: ammgui._impl.component.provider.Provider
ns.Functional = class.create("Functional", provider.Provider)

--- @param data ammgui.dom.FunctionalNode
function ns.Functional:onMount(ctx, data)
    ns.Functional.onUpdate(self, ctx, data)
end

--- @param data ammgui.dom.FunctionalNode
function ns.Functional:onUpdate(ctx, data)
    local outdated = false

    if not self._hooks or self._id ~= data._id then
        self._hooks = api.Context:New(ctx)
    end

    if
        not self._root
        or self._hooks._stateChanged
        or (not data._memo and ctx:isOutdated())
        or not fun.t.eq(self._params, data._params)
    then
        self._id = data._id
        self._params = data._params
        self._func = data._func

        self._hooks:_beforeSync()
        self._root = self._func(
            self._hooks,
            fun.a.extend(fun.t.copy(self._params), data._children)
        )
        self._hooks:_afterSync(self._func)

        outdated = true
    end

    ctx:pushComponent(outdated, data._children)
    self._provider = self.syncOne(ctx, self._provider, self._root)
    ctx:popComponent()

    self._hooks:_runEffects() -- TODO: re-render if state changed during effects run?
end

function ns.Functional:onUnmount(ctx)
    self._provider:onUnmount(ctx)
    self._hooks:_cleanUpEffects()
end

function ns.Functional:collect(components)
    self._provider:collect(components)
end

function ns.Functional:noteRef(ref)
    self._provider:noteRef(ref)
end

--- Children of a functional component.
---
--- @class ammgui_impl.component.func.Children: ammgui._impl.component.list.List
ns.Children = class.create("Children", list.List)

function ns.Children:onMount(ctx, data)
    ctx:pushChildren(data)
    list.List.onMount(self, ctx, data)
    ctx:popChildren()
end

function ns.Children:onUpdate(ctx, data)
    ctx:pushChildren(data)
    list.List.onUpdate(self, ctx, data)
    ctx:popChildren()
end

return ns
