local class = require "ammcore.class"
local log = require "ammcore.log"

--- Event, drag'n'drop, and focus manager.
---
--- !doctype module
--- @class ammgui.eventManager
local ns = {}

local logger = log.Logger:New()

--- @class ammgui.eventManager.ResolvedListeners
--- @field [integer] ammgui._impl.eventListener.EventListener
--- @field [ammgui._impl.id.EventListenerId] ammgui.Vec2

--- Event, drag'n'drop, and focus manager.
---
--- @class ammgui.eventManager.EventManager: ammcore.class.Base
ns.EventManager = class.create("EventManager")

--- !doctype classmethod
--- @generic T: ammgui.eventManager.EventManager
--- @param self T
--- @return T
function ns.EventManager:New()
    self = class.Base.New(self)

    --- @private
    --- @type ammgui.eventManager.ResolvedListeners
    self._lastHoveredEventListeners = {}

    --- @private
    --- @type ammgui.eventManager.ResolvedListeners
    self._lastMouseDownEventListeners = {}

    --- @private
    --- @type boolean
    self._dragging = false

    --- @private
    --- @type ammgui.viewport.Window?
    self._dragOriginWindow = nil

    --- @private
    --- @type ammgui._impl.eventListener.EventListener?
    self._draggedEventListener = nil

    --- @private
    --- @type ammgui.Vec2?
    self._draggedEventListenerPos = nil

    --- @private
    --- @type ammgui.Vec2?
    self._draggedEventListenerOrigin = nil

    --- @private
    --- @type ammgui._impl.eventListener.EventListener?
    self._dragTarget = nil

    return self
end

--- @param mainWindow ammgui.viewport.Viewport
--- @param mainContext ammgui._impl.context.render.Context
--- @param eventName string
--- @param ... any
function ns.EventManager:onEvent(mainWindow, mainContext, eventName, _, ...)
    if self[eventName] then
        self[eventName](self, mainWindow, mainContext, ...)
    else
        logger:trace("Unknown event %s", log.pp(eventName))
    end
end

--- @param mainWindow ammgui.viewport.Viewport
--- @param mainContext ammgui._impl.context.render.Context
--- @param pos ammgui.Vec2
--- @return ammgui.eventManager.ResolvedListeners affectedReceivers
--- @return ammgui.viewport.Window? window
function ns.EventManager:_findMouseTarget(mainWindow, mainContext, pos)
    local affectedReceivers = mainContext:getEventListener(pos)
    if #affectedReceivers > 0 then
        return affectedReceivers, nil
    else
        return mainWindow:getEventListener(pos)
    end
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseDown(mainWindow, mainContext, pos, modifiers)
    -- When another button clicked while dragging, abort drag and do nothing more.
    if self._dragging then
        self:OnMouseUp(mainWindow, mainContext, pos, modifiers)
        return
    end

    local pos = Vec2:FromV2(pos)

    local chain, window = self:_findMouseTarget(mainWindow, mainContext, pos)

    self:_sendMouseExit(pos, modifiers, chain)
    self:_sendMouseEnterOrMove(pos, modifiers, chain, false)

    do
        local propagate = true
        for _, eventListener in ipairs(chain) do
            if eventListener:isActive() then
                propagate = eventListener:onMouseDown(pos - chain[eventListener.id], modifiers, propagate)
            end
        end
    end

    local draggedEventListener = self:_findDraggable(chain)
    if draggedEventListener then
        self._dragging = false
        self._dragOriginWindow = window
        self._draggedEventListener = draggedEventListener
        self._draggedEventListenerPos = chain[draggedEventListener.id]
        self._draggedEventListenerOrigin = pos - self._draggedEventListenerPos
        self._dragTarget = nil
    end

    self._lastHoveredEventListeners = chain
    self._lastMouseDownEventListeners = chain
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseUp(mainWindow, mainContext, pos, modifiers)
    local pos = Vec2:FromV2(pos)

    local chain, window = self:_findMouseTarget(mainWindow, mainContext, pos)

    if self._dragging then
        -- Find drag target, but only in the same window.
        local dragTarget, cookie = nil, nil
        if self._dragOriginWindow == window then
            dragTarget, cookie = self:_findDragTarget(chain)
        end

        -- Drag target changed, need to exit previous one.
        if self._dragTarget and dragTarget ~= self._dragTarget then
            if self._dragTarget:isActive() then
                self._dragTarget:onDragExit()
            end
            self._dragTarget = nil
        end

        -- Now exit and enter elements. If we're over another window, it will not see
        -- the mouse until drag is released, though.
        self:_sendMouseExit(pos, modifiers, chain)
        if self._dragOriginWindow == window then
            self:_sendMouseEnterOrMove(pos, modifiers, chain, false)
        end

        -- Drag target changed, need to enter new one.
        if dragTarget and dragTarget ~= self._dragTarget and dragTarget:isActive() then
            dragTarget:onDragEnter()
        end

        -- Exit target before drag release.
        if dragTarget and dragTarget:isActive() then
            dragTarget:onDragExit()
        end

        -- Drag release.
        if self._draggedEventListener:isActive() then
            self._draggedEventListener:onDragEnd(
                pos - self._draggedEventListenerPos,
                self._draggedEventListenerOrigin,
                modifiers,
                cookie
            )
        end
    else
        self:_sendMouseExit(pos, modifiers, chain)
        self:_sendMouseEnterOrMove(pos, modifiers, chain, false)
    end

    do
        local propagate = true
        for _, eventListener in ipairs(chain) do
            if eventListener:isActive() then
                propagate = eventListener:onMouseUp(pos - chain[eventListener.id], modifiers, propagate)
            end
        end
    end

    if not self._dragging then
        local propagate = true
        for _, eventListener in ipairs(chain) do
            if eventListener:isActive() then
                propagate = eventListener:onClick(pos - chain[eventListener.id], modifiers, propagate)
            end
        end
    end

    self._dragging = false
    self._dragOriginWindow = nil
    self._draggedEventListener = nil
    self._draggedEventListenerPos = nil
    self._draggedEventListenerOrigin = nil
    self._dragTarget = nil

    self._lastHoveredEventListeners = chain
    self._lastMouseDownEventListeners = chain
end

--- @param name string
--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseEnter(name, sender, pos, modifiers)
    self:OnMouseMove(name, sender, pos, modifiers)
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseMove(mainWindow, mainContext, pos, modifiers)
    local pos = Vec2:FromV2(pos)

    local chain, window = self:_findMouseTarget(mainWindow, mainContext, pos)

    self:_sendMouseExit(pos, modifiers, chain)

    -- When dragging, only the original window sees the cursor.
    if self._dragging and self._dragOriginWindow ~= window then
        chain = {}
    end

    self:_sendMouseEnterOrMove(pos, modifiers, chain, true)

    self._lastHoveredEventListeners = chain

    if self._draggedEventListener then
        local dragTarget, cookie = self:_findDragTarget(chain)

        if self._dragTarget and self._dragTarget ~= dragTarget then
            if self._dragTarget:isActive() then
                self._dragTarget:onDragExit()
            end
            self._dragTarget = nil
        end

        local dragResult = nil
        if self._draggedEventListener:isActive() then
            if self._dragging then
                dragResult = self._draggedEventListener:onDrag(
                    pos - self._draggedEventListenerPos,
                    self._draggedEventListenerOrigin,
                    modifiers,
                    cookie
                )
            else
                dragResult = self._draggedEventListener:onDragStart(
                    pos - self._draggedEventListenerPos,
                    self._draggedEventListenerOrigin,
                    modifiers,
                    cookie
                )
            end
        end
        self._dragging = true

        if dragResult == false then
            if self._dragTarget and self._dragTarget:isActive() then
                self._dragTarget:onDragExit()
            end
            self._dragging = false
            self._dragOriginWindow = nil
            self._draggedEventListener = nil
            self._draggedEventListenerPos = nil
            self._draggedEventListenerOrigin = nil
            self._dragTarget = nil
        else
            if type(dragResult) ~= "string" then
                dragResult = "normal"
            end
            if dragTarget and self._dragTarget ~= dragTarget and dragTarget:isActive() then
                dragTarget:onDragEnter(dragResult)
            end
            self._dragTarget = dragTarget
        end
    end
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseLeave(mainWindow, mainContext, pos, modifiers)
    local pos = Vec2:FromV2(pos)

    self:_sendMouseExit(pos, modifiers, {})

    self._lastHoveredEventListeners = {}
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseWheel(mainWindow, mainContext, pos, delta, modifiers)
    local pos = Vec2:FromV2(pos)

    local chain = self:_findMouseTarget(mainWindow, mainContext, pos)

    self:_sendMouseExit(pos, modifiers, chain)
    self:_sendMouseEnterOrMove(pos, modifiers, chain, false)

    local propagate = true
    for _, eventListener in ipairs(chain) do
        if eventListener:isActive() then
            propagate = eventListener:onMouseWheel(pos - chain[eventListener.id], delta, modifiers, propagate)
        end
    end

    self._lastHoveredEventListeners = chain
end

--- @param pos ammgui.Vec2
--- @param modifiers integer
--- @param chain ammgui.eventManager.ResolvedListeners
function ns.EventManager:_sendMouseExit(pos, modifiers, chain)
    for _, eventListener in ipairs(self._lastHoveredEventListeners) do
        if not chain[eventListener.id] then
            eventListener:onMouseExit(
                pos - self._lastHoveredEventListeners[eventListener.id], modifiers
            )
        end
    end
end

--- @param pos ammgui.Vec2
--- @param modifiers integer
--- @param chain ammgui.eventManager.ResolvedListeners
--- @param sendMove boolean
function ns.EventManager:_sendMouseEnterOrMove(pos, modifiers, chain, sendMove)
    for i = #chain, 1, -1 do
        local eventListener = chain[i]
        if eventListener:isActive() and not self._lastHoveredEventListeners[eventListener.id] then
            eventListener:onMouseEnter(pos - chain[eventListener.id], modifiers)
        end
    end
    if sendMove then
        local propagate = true
        for _, eventListener in ipairs(chain) do
            if eventListener:isActive() and self._lastHoveredEventListeners[eventListener.id] then
                propagate = eventListener:onMouseMove(pos - chain[eventListener.id], modifiers, propagate)
            end
        end
    end
end

--- @param chain ammgui.eventManager.ResolvedListeners
--- @return ammgui._impl.eventListener.EventListener? dragTarget
--- @return any? cookie
function ns.EventManager:_findDragTarget(chain)
    for _, eventListener in ipairs(chain) do
        if eventListener:isActive() then
            local cookie = eventListener:isDragTarget()
            if cookie then
                return eventListener, cookie
            end
        end
    end
    return nil, nil
end

--- @param chain ammgui.eventManager.ResolvedListeners
--- @return ammgui._impl.eventListener.EventListener? draggable
function ns.EventManager:_findDraggable(chain)
    for _, eventListener in ipairs(chain) do
        if eventListener:isActive() and eventListener:isDraggable() then
            return eventListener
        end
    end
    return nil
end

return ns
