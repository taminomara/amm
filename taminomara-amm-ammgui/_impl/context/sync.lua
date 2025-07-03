local class = require "ammcore.class"

--- Synchronization context, keeps track of outdated functional components
--- and their children.
---
--- !doctype module
--- @class ammgui._impl.context.sync
local ns = {}

--- Synchronization context, keeps track of outdated functional components
--- and their children.
---
--- When a functional component is outdated, we want to re-render it, and then update
--- all non-memo functional components within it. However, if a functional component
--- uses children that were passed from outside, and those children are not outdated,
--- we don't want to re-render them.
---
--- To deal with all of this, we keep a stack of all functional components we've
--- encountered so far, and their ``outdated`` status. When we encounter a new
--- functional component, we see if the top-most component in our stack
--- is outdated, and decide if we need to push the new component onto the stack
--- and re-render it. When we encounter a child node, we look up ``outdated`` state
--- of the component that created it, and push it onto the stack, thus replacing
--- the current ``outdated`` flag.
---
--- @class ammgui._impl.context.sync.Context: ammcore.class.Base
ns.Context = class.create("Context")

--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui._impl.context.sync.Context
--- @param self T
--- @return T
function ns.Context:New(earlyRefreshEvent)
    self = class.Base.New(self)

    --- @private
    --- @type ammcore.promise.Event
    self._earlyRefreshEvent = earlyRefreshEvent

    --- @private
    --- @type { outdated: boolean, children: ammgui.dom.Node[] }[]
    self._outdatedStack = {}

    --- @private
    --- @type table<ammgui.dom.Node, boolean>
    self._children = {}

    --- @private
    --- @type table<ammgui._impl.component.provider.Provider, any>
    self._rendered = {}

    return self
end

--- Check if functional components at this level are out of date.
---
--- @return boolean
function ns.Context:isOutdated()
    if #self._outdatedStack > 0 then
        -- We force-re-render functional components when their parent is outdated.
        return self._outdatedStack[#self._outdatedStack].outdated
    else
        -- If there is no parent, it means we're evaluating window's root.
        -- We never force-re-render roots. It's up to the functional component's
        -- implementation to detect if its parameters changed.
        return false
    end
end

--- @param outdated boolean
--- @param children ammgui.dom.ListNode?
function ns.Context:pushComponent(outdated, children)
    local isParentOutdated = self:isOutdated()
    local childrenAddedByThisComponent = {}
    if children then
        for _, child in ipairs(children) do
            if self._children[child] then
                -- We've seen this children node before. This happens when some component
                -- passes its children to another component. We don't need to do anything,
                -- as this child node is already registered.
            else
                -- We haven't seen this children node before. This means that this children
                -- node was created by currently active functional component.
                -- We use its `outdated` flag; we only force-refresh children when
                -- the functional component that created them is itself outdated.
                self._children[child] = isParentOutdated
                table.insert(childrenAddedByThisComponent, child)
            end
        end
    end
    table.insert(self._outdatedStack, { outdated = outdated, children = childrenAddedByThisComponent })
end

function ns.Context:popComponent()
    if #self._outdatedStack > 0 then
        local data = table.remove(self._outdatedStack)
        for _, child in ipairs(data.children) do
            self._children[child] = nil
        end
    end
end

--- @param children ammgui.dom.BaseNode?
function ns.Context:pushChildren(children)
    local outdated = self._children[children]
    if outdated == nil then
        error("unknown children node")
    else
        -- We override current `outdated` flag by the `outdated` flag of the functional
        -- component that created these children. This way, we only refresh children
        -- when the component that'd created them is outdated. We don't care if
        -- the container that received these children is outdated, we know that
        -- it didn't (or at least shouldn't have) mess with the children.
        table.insert(self._outdatedStack, { outdated = outdated })
    end
end

function ns.Context:popChildren()
    local data = table.remove(self._outdatedStack)
    assert(not data.children, "not a children node")
end

--- @return ammcore.promise.Event
function ns.Context:getEarlyRefreshEvent()
    return self._earlyRefreshEvent
end

--- Set results of rendering a component.
---
--- These results will be available during commit phase via the `getRendered` method.
---
--- @param component ammgui._impl.component.provider.Provider
--- @param rendered any
function ns.Context:setRendered(component, rendered)
    assert(not self._rendered[component], "already rendered")
    self._rendered[component] = rendered
end

--- @param component ammgui._impl.component.provider.Provider
--- @return any
function ns.Context:getRendered(component)
    return assert(self._rendered[component], "not rendered")
end

return ns
