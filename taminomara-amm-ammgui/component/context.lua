local class = require "ammcore.class"
local defer = require "ammcore.defer"
local rule = require "ammgui.css.rule"
local fun = require "ammcore.fun"
local log = require "ammcore.log"

--- Rendering context.
---
--- !doctype module
--- @class ammgui.component.context
local ns = {}

local logger = log.Logger:New()

--- Synchronization context, keeps track of outdated blocks.
---
--- @class ammgui.component.context.SyncContext: ammcore.class.Base
ns.SyncContext = class.create("SyncContext")

--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui.component.context.SyncContext
--- @param self T
--- @return T
function ns.SyncContext:New(earlyRefreshEvent)
    self = class.Base.New(self)

    --- @private
    --- @type ammcore.promise.Event
    self._earlyRefreshEvent = earlyRefreshEvent

    --- @private
    --- @type { outdated: boolean, children: ammgui.dom.Node[] }[]
    self._outdatedStack = {}

    --- @protected
    --- @type table<ammgui.dom.Node, boolean>
    self._children = {}

    return self
end

--- Check if functional components at this level are out of date.
---
--- @return boolean
function ns.SyncContext:isOutdated()
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
function ns.SyncContext:pushComponent(outdated, children)
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

function ns.SyncContext:popComponent()
    if #self._outdatedStack > 0 then
        local data = table.remove(self._outdatedStack)
        for _, child in ipairs(data.children) do
            self._children[child] = nil
        end
    end
end

--- @param children ammgui.dom.Node?
function ns.SyncContext:pushChildren(children)
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

function ns.SyncContext:popChildren()
    local data = table.remove(self._outdatedStack)
    assert(not data.children, "not a children node")
end

function ns.SyncContext:requestEarlyRefresh()
    self._earlyRefreshEvent:set()
end

--- Rendering context.
---
--- All clipping should be added through this context so that mouse event handlers
--- can calculate whether an interactive element is in a clipped zone or not.
---
--- @class ammgui.component.context.RenderingContext: ammcore.class.Base
ns.RenderingContext = class.create("Context")

--- @param gpu FINComputerGPUT2
--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui.component.context.RenderingContext
--- @param self T
--- @return T
function ns.RenderingContext:New(gpu, earlyRefreshEvent)
    self = class.Base.New(self)

    --- GPU used for rendering.
    ---
    --- !doc const
    --- @type FINComputerGPUT2
    self.gpu = gpu

    --- @private
    --- @type ammcore.promise.Event
    self._earlyRefreshEvent = earlyRefreshEvent

    self:reset(gpu:getScreenSize())

    return self
end

--- Reset rendering context before next redraw.
---
--- @param size Vector2D
--- @param devtoolsHighlightedId table?
--- @param devtoolsHighlightedParams [boolean, boolean, boolean, boolean]?
function ns.RenderingContext:reset(
    size,
    devtoolsHighlightedId,
    devtoolsHighlightedParams
)
    --- @private
    --- @type Vector2D
    self._size = size

    --- @private
    --- @type Vector2D
    self._posA = structs.Vector2D { 0, 0 }

    --- @private
    --- @type Vector2D
    self._posB = size

    --- @private
    --- @type Vector2D
    self._clipPosA = self._posA

    --- @private
    --- @type Vector2D
    self._clipPosB = self._posB

    --- A single large screen panel is ``300x300``, resulting in ``6x6`` event grid.
    ---
    --- @private
    --- @type integer
    self._eventGridResolution = 50

    --- @private
    --- @type integer
    self._eventGridSizeX = math.floor(size.x / self._eventGridResolution) + 1

    --- @private
    --- @type integer
    self._eventGridSizeY = math.floor(size.y / self._eventGridResolution) + 1

    --- @private
    --- @type { posA: Vector2D, posB: Vector2D, clipPosA: Vector2D, clipPosB: Vector2D, clip: boolean }[]
    self._layoutStack = {}

    --- @private
    --- @type table<integer, { posA: Vector2D, posB: Vector2D, eventReceiver: ammgui.eventManager.EventListener }[]>
    self._eventGrid = {}

    --- @private
    --- @type table?
    self._devtoolsHighlightedId = devtoolsHighlightedId

    --- @private
    --- @type [boolean, boolean, boolean, boolean]?
    self._devtoolsHighlightedParams = devtoolsHighlightedParams

    --- @private
    --- @type [ammgui.component.base.SupportsDebugOverlay, Vector2D, Vector2D][]
    self._devtoolsHighlightedTargets = {}
end

function ns.RenderingContext:requestEarlyRefresh()
    self._earlyRefreshEvent:set()
end

--- @param coords Vector2D
--- @return integer
function ns.RenderingContext:_coordsToEventGrid(coords)
    local x = math.floor(coords.x / self._eventGridResolution)
    local y = math.floor(coords.y / self._eventGridResolution)
    return math.floor(y + self._eventGridSizeX + x)
end

--- Get topmost event receiver by mouse coordinates.
---
--- @param pos Vector2D
--- @return ammgui.eventManager.EventListener? topReceiver
--- @return table<ammgui.eventManager.EventListener, Vector2D> affectedReceivers
function ns.RenderingContext:getEventListener(pos)
    if not (0 <= pos.x and pos.x < self._size.x) then return nil, {} end
    if not (0 <= pos.y and pos.y < self._size.y) then return nil, {} end
    local cell = self._eventGrid[self:_coordsToEventGrid(pos)]
    if not cell then return nil, {} end

    local receivers = {}
    local firstReceiver = nil
    for _, eventCoords in ipairs(cell) do
        if
            eventCoords.posA.x <= pos.x and pos.x < eventCoords.posB.x
            and eventCoords.posA.y <= pos.y and pos.y < eventCoords.posB.y
        then
            receivers[eventCoords.eventReceiver] = eventCoords.posA
            firstReceiver = eventCoords.eventReceiver
        end
    end
    return firstReceiver, receivers
end

--- Add an event receiver to the depth buffer.
---
--- Depth buffer is cleared before every redraw.
---
--- @param position Vector2D
--- @param size Vector2D
--- @param eventReceiver ammgui.eventManager.EventListener
function ns.RenderingContext:pushEventListener(position, size, eventReceiver)
    local posA = self._posA + position
    local posB = posA + size
    local x1, x2 = math.max(posA.x, self._clipPosA.x), math.min(posB.x, self._clipPosB.x)
    local y1, y2 = math.max(posA.y, self._clipPosA.y), math.min(posB.y, self._clipPosB.y)
    if x1 < x2 and y1 < y2 then
        local x1g = math.floor(x1 / self._eventGridResolution)
        local x2g = math.floor((x2 - 1) / self._eventGridResolution)
        local y1g = math.floor(y1 / self._eventGridResolution)
        local y2g = math.floor((y2 - 1) / self._eventGridResolution)
        local eventCoords = {
            posA = structs.Vector2D { x1, y1 },
            posB = structs.Vector2D { x2, y2 },
            eventReceiver = eventReceiver,
        }

        for x = x1g, x2g do
            for y = y1g, y2g do
                local i = y + self._eventGridSizeX + x
                self._eventGrid[i] = self._eventGrid[i] or {}
                table.insert(self._eventGrid[i], eventCoords)
            end
        end
    end
end

--- @param position Vector2D
--- @param size Vector2D
--- @param clip boolean
--- @return boolean visible `true` if new layout is visible on the screen.
function ns.RenderingContext:pushLayout(position, size, clip)
    table.insert(self._layoutStack, {
        posA = self._posA,
        posB = self._posB,
        clipPosA = self._clipPosA,
        clipPosB = self._clipPosB,
        clip = clip,
    })
    self._posA = self._posA + position
    self._posB = self._posA + size

    if clip then
        self._clipPosA = structs.Vector2D {
            math.max(self._clipPosA.x, self._posA.x),
            math.max(self._clipPosA.y, self._posA.y),
        }
        self._clipPosB = structs.Vector2D {
            math.min(self._clipPosB.x, self._posB.x),
            math.min(self._clipPosB.y, self._posB.y),
        }

        self.gpu:pushClipRect(position, size)
    end

    self.gpu:pushLayout(position, size, 1)

    return
        self._posA.x < self._clipPosB.x
        and self._posA.y < self._clipPosB.y
        and self._posB.x >= self._clipPosA.x
        and self._posB.y >= self._clipPosA.y
end

function ns.RenderingContext:popLayout()
    local prevLayout = table.remove(self._layoutStack)
    if not prevLayout then
        error("'popLayout' called before 'pushLayout'")
    end

    self._posA = prevLayout.posA
    self._posB = prevLayout.posB
    self._clipPosA = prevLayout.clipPosA
    self._clipPosB = prevLayout.clipPosB

    self.gpu:popGeometry()
    if prevLayout.clip then
        self.gpu:popClip()
    end
end

--- @param target ammgui.component.base.SupportsDebugOverlay
--- @param id table
function ns.RenderingContext:noteDebugTarget(target, id)
    if self._devtoolsHighlightedId and self._devtoolsHighlightedId == id then
        table.insert(self._devtoolsHighlightedTargets, {
            target, self._posA, self._posB
        })
    end
end

function ns.RenderingContext:finalize()
    for _, target in ipairs(self._devtoolsHighlightedTargets) do
        self.gpu:pushLayout(
            target[2],
            target[3] - target[2],
            1
        )
        target[1]:drawDebugOverlay(
            self,
            table.unpack(self._devtoolsHighlightedParams)
        )
        self.gpu:popGeometry()
    end
end

return ns
