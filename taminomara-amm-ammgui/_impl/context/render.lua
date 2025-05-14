local class = require "ammcore.class"

--- Rendering context.
---
--- !doctype module
--- @class ammgui._impl.context.render
local ns = {}

--- @class ammgui._impl.context.render.SupportsDebugOverlay
--- @field drawDebugOverlay fun(self, ctx: ammgui._impl.context.render.Context, drawContent: boolean, drawPadding: boolean, drawOutline: boolean, drawMargin: boolean)

--- Rendering context.
---
--- All clipping should be added through this context so that mouse event handlers
--- can calculate whether an interactive element is in a clipped zone or not.
---
--- @class ammgui._impl.context.render.Context: ammcore.class.Base
ns.Context = class.create("Context")

--- @param gpu FINComputerGPUT2
--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui._impl.context.render.Context
--- @param self T
--- @return T
function ns.Context:New(gpu, earlyRefreshEvent)
    self = class.Base.New(self)

    --- GPU used for rendering.
    ---
    --- !doc const
    --- @type FINComputerGPUT2
    self.gpu = gpu

    --- @private
    --- @type ammcore.promise.Event
    self._earlyRefreshEvent = earlyRefreshEvent

    return self
end

--- Reset rendering context before next redraw.
---
--- @param size ammgui.Vec2
--- @param devtoolsHighlightedId ammgui._impl.id.EventListenerId?
--- @param devtoolsHighlightedParams [boolean, boolean, boolean, boolean]?
function ns.Context:reset(
    size,
    devtoolsHighlightedId,
    devtoolsHighlightedParams
)
    --- @private
    --- @type ammgui.Vec2
    self._size = size

    --- @private
    --- @type ammgui.Vec2
    self._posA = Vec2:New( 0, 0 )

    --- @private
    --- @type ammgui.Vec2
    self._posB = size

    --- @private
    --- @type ammgui.Vec2
    self._clipPosA = self._posA

    --- @private
    --- @type ammgui.Vec2
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
    --- @type { posA: ammgui.Vec2, posB: ammgui.Vec2, clipPosA: ammgui.Vec2, clipPosB: ammgui.Vec2, clip: boolean }[]
    self._layoutStack = {}

    --- @private
    --- @type table<ammgui._impl.id.EventListenerId, ammgui._impl.eventListener.EventListener>
    self._eventListeners = setmetatable({}, { __mode = "kv" })

    --- @private
    --- @type table<integer, { posA: ammgui.Vec2, posB: ammgui.Vec2, eventListenerId: ammgui._impl.id.EventListenerId }[]>
    self._eventGrid = {}

    --- @private
    --- @type table?
    self._devtoolsHighlightedId = devtoolsHighlightedId

    --- @private
    --- @type [boolean, boolean, boolean, boolean]?
    self._devtoolsHighlightedParams = devtoolsHighlightedParams

    --- @private
    --- @type [ammgui._impl.context.render.SupportsDebugOverlay, ammgui.Vec2, ammgui.Vec2][]
    self._devtoolsHighlightedTargets = {}
end

function ns.Context:requestEarlyRefresh()
    self._earlyRefreshEvent:set()
end

--- @param coords ammgui.Vec2
--- @return integer
function ns.Context:_coordsToEventGrid(coords)
    local x = math.floor(coords.x / self._eventGridResolution)
    local y = math.floor(coords.y / self._eventGridResolution)
    return math.floor(y + self._eventGridSizeX + x)
end

--- Get topmost event listener by mouse coordinates.
---
--- @param pos ammgui.Vec2
--- @return ammgui.eventManager.ResolvedListeners chain
function ns.Context:getEventListener(pos)
    if not (0 <= pos.x and pos.x < self._size.x) then return {} end
    if not (0 <= pos.y and pos.y < self._size.y) then return {} end
    local cell = self._eventGrid[self:_coordsToEventGrid(pos)]
    if not cell then return {} end

    local listenerPositions = {}
    local firstListener = nil
    for _, eventCoords in ipairs(cell) do
        if
            eventCoords.posA.x <= pos.x and pos.x < eventCoords.posB.x
            and eventCoords.posA.y <= pos.y and pos.y < eventCoords.posB.y
        then
            local eventListener = self._eventListeners[eventCoords.eventListenerId]
            if eventListener then
                listenerPositions[eventListener] = eventCoords.posA
                firstListener = eventListener
            end
        end
    end

    --- @type ammgui.eventManager.ResolvedListeners
    local chain = {}

    while firstListener do
        if listenerPositions[firstListener] then
            table.insert(chain, firstListener)
            chain[firstListener.id] = listenerPositions[firstListener]
        end
        firstListener = firstListener.parent
    end

    return chain
end

--- Add an event listener to the depth buffer.
---
--- Depth buffer is cleared before every redraw.
---
--- @param position ammgui.Vec2
--- @param size ammgui.Vec2
--- @param eventListener ammgui._impl.eventListener.EventListener
function ns.Context:pushEventListener(position, size, eventListener)
    self._eventListeners[eventListener.id] = eventListener

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
            posA = Vec2:New( x1, y1 ),
            posB = Vec2:New( x2, y2 ),
            eventListenerId = eventListener.id,
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

--- @param position ammgui.Vec2
--- @param size ammgui.Vec2
--- @param clip boolean
--- @return boolean visible `true` if new layout is visible on the screen.
function ns.Context:pushLayout(position, size, clip)
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
        self._clipPosA = Vec2:New(
            math.max(self._clipPosA.x, self._posA.x),
            math.max(self._clipPosA.y, self._posA.y)
        )
        self._clipPosB = Vec2:New(
            math.min(self._clipPosB.x, self._posB.x),
            math.min(self._clipPosB.y, self._posB.y)
        )

        self.gpu:pushClipRect(position, size)
    end

    self.gpu:pushLayout(position, size, 1)

    return
        self._posA.x < self._clipPosB.x
        and self._posA.y < self._clipPosB.y
        and self._posB.x >= self._clipPosA.x
        and self._posB.y >= self._clipPosA.y
end

function ns.Context:popLayout()
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

--- @param pos ammgui.Vec2
--- @param size ammgui.Vec2
--- @param target ammgui._impl.context.render.SupportsDebugOverlay
--- @param id ammgui._impl.id.EventListenerId
function ns.Context:noteDebugTarget(pos, size, target, id)
    if self._devtoolsHighlightedId and self._devtoolsHighlightedId == id then
        table.insert(self._devtoolsHighlightedTargets, {
            target, self._posA + pos, self._posA + pos + size,
        })
    end
end

function ns.Context:finalize()
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
