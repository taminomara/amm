local class = require "ammcore.class"
local log = require "ammcore.log"

--- Event, drag'n'drop, and focus manager.
---
--- !doctype module
--- @class ammgui.eventManager
local ns = {}

local logger = log.Logger:New()

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
    --- @type ammgui._impl.eventListener.EventListener?
    self._lastHoverEventListener = nil

    --- @private
    --- @type table<ammgui._impl.eventListener.EventListener, ammgui.Vec2>
    self._lastAffectedHoverEventListeners = {}

    --- @private
    --- @type table<ammgui._impl.eventListener.EventListener, ammgui.Vec2>
    self._lastAffectedMouseDownEventListeners = {}

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
--- @return ammgui._impl.eventListener.EventListener? topReceiver
--- @return table<ammgui._impl.eventListener.EventListener, ammgui.Vec2> affectedReceivers
--- @return ammgui.viewport.Window? window
function ns.EventManager:_findMouseTarget(mainWindow, mainContext, pos)
    local firstReceiver, receivers = mainContext:getEventListener(pos)
    if firstReceiver then
        return firstReceiver, receivers, nil
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

    local topEventListener, affectedEventListeners, window = self:_findMouseTarget(mainWindow, mainContext, pos)

    self:_sendMouseExit(pos, modifiers, affectedEventListeners)

    if topEventListener then
        -- Send MouseEnter for receivers that didn't see it yet.
        self:_sendMouseEnterOrMove(pos, modifiers, topEventListener, affectedEventListeners, false)

        local currentEventListener = topEventListener
        local propagate = true
        while currentEventListener do
            local receiverPos = affectedEventListeners[currentEventListener]
            if receiverPos and currentEventListener:isActive() then
                propagate = currentEventListener:onMouseDown(pos - receiverPos, modifiers, propagate)
            end
            currentEventListener = currentEventListener.parent
        end

        local draggedEventListener = self:_findDraggable(topEventListener, affectedEventListeners)
        if draggedEventListener then
            self._dragging = false
            self._dragOriginWindow = window
            self._draggedEventListener = draggedEventListener
            self._draggedEventListenerPos = affectedEventListeners[draggedEventListener]
            self._draggedEventListenerOrigin = pos - self._draggedEventListenerPos
            self._dragTarget = nil
        end
    end

    self._lastHoverEventListener = topEventListener
    self._lastAffectedHoverEventListeners = affectedEventListeners
    self._lastAffectedMouseDownEventListeners = affectedEventListeners
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseUp(mainWindow, mainContext, pos, modifiers)
    local pos = Vec2:FromV2(pos)

    local topEventListener, affectedEventListeners, window = self:_findMouseTarget(mainWindow, mainContext, pos)

    if self._dragging then
        -- Find drag target, but only in the same window.
        local dragTarget, cookie = nil, nil
        if self._dragOriginWindow == window then
            dragTarget, cookie = self:_findDragTarget(topEventListener, affectedEventListeners)
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
        self:_sendMouseExit(pos, modifiers, affectedEventListeners)
        if topEventListener and self._dragOriginWindow == window then
            self:_sendMouseEnterOrMove(pos, modifiers, topEventListener, affectedEventListeners, false)
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

        -- If we're over another window, it will now see the mouse.
        if topEventListener and self._dragOriginWindow ~= window then
            self:_sendMouseEnterOrMove(pos, modifiers, topEventListener, affectedEventListeners, false)
        end
    else
        self:_sendMouseExit(pos, modifiers, affectedEventListeners)
        if topEventListener then
            self:_sendMouseEnterOrMove(pos, modifiers, topEventListener, affectedEventListeners, false)
        end
    end

    if topEventListener then
        do
            local currentEventListener = topEventListener
            local propagate = true
            while currentEventListener do
                local receiverPos = affectedEventListeners[currentEventListener]
                if receiverPos and currentEventListener:isActive() then
                    propagate = currentEventListener:onMouseUp(pos - receiverPos, modifiers, propagate)
                end
                currentEventListener = currentEventListener.parent
            end
        end

        if not self._dragging then
            local currentEventListener = topEventListener
            local propagate = true
            while currentEventListener do
                local receiverPos = affectedEventListeners[currentEventListener]
                if receiverPos and self._lastAffectedMouseDownEventListeners[currentEventListener] and currentEventListener:isActive() then
                    propagate = currentEventListener:onClick(pos - receiverPos, modifiers, propagate)
                end
                currentEventListener = currentEventListener.parent
            end
        end
    end

    self._dragging = false
    self._dragOriginWindow = nil
    self._draggedEventListener = nil
    self._draggedEventListenerPos = nil
    self._draggedEventListenerOrigin = nil
    self._dragTarget = nil

    self._lastHoverEventListener = topEventListener
    self._lastAffectedHoverEventListeners = affectedEventListeners
    self._lastAffectedMouseDownEventListeners = affectedEventListeners
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

    local topEventListener, affectedEventListeners, window = self:_findMouseTarget(mainWindow, mainContext, pos)

    self:_sendMouseExit(pos, modifiers, affectedEventListeners)

    -- When dragging, only the original window sees the cursor.
    if self._dragging and self._dragOriginWindow ~= window then
        topEventListener = nil
        affectedEventListeners = {}
    end

    if topEventListener then
        self:_sendMouseEnterOrMove(pos, modifiers, topEventListener, affectedEventListeners, true)
    end

    self._lastHoverEventListener = topEventListener
    self._lastAffectedHoverEventListeners = affectedEventListeners

    if self._draggedEventListener then
        local dragTarget, cookie = self:_findDragTarget(topEventListener, affectedEventListeners)

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

    self:_sendMouseExit(pos, modifiers, nil)

    self._lastHoverEventListener = nil
    self._lastAffectedHoverEventListeners = {}
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseWheel(mainWindow, mainContext, pos, delta, modifiers)
    local pos = Vec2:FromV2(pos)

    local topEventListener, affectedEventListeners = self:_findMouseTarget(mainWindow, mainContext, pos)

    self:_sendMouseExit(pos, modifiers, affectedEventListeners)
    if topEventListener then
        -- Send MouseEnter for receivers that didn't see it yet.
        self:_sendMouseEnterOrMove(pos, modifiers, topEventListener, affectedEventListeners, false)

        local currentEventListener = topEventListener
        local propagate = true
        while currentEventListener do
            local receiverPos = affectedEventListeners[currentEventListener]
            if receiverPos and currentEventListener:isActive() then
                propagate = currentEventListener:onMouseWheel(pos - receiverPos, delta, modifiers, propagate)
            end
            currentEventListener = currentEventListener.parent
        end
    end

    self._lastHoverEventListener = topEventListener
    self._lastAffectedHoverEventListeners = affectedEventListeners
end

--- @param pos ammgui.Vec2
--- @param modifiers integer
--- @param affectedEventListeners table<ammgui._impl.eventListener.EventListener, ammgui.Vec2> | nil
function ns.EventManager:_sendMouseExit(pos, modifiers, affectedEventListeners)
    local lastEventListener = self._lastHoverEventListener
    while lastEventListener do
        local receiverPos = self._lastAffectedHoverEventListeners[lastEventListener]
        if receiverPos and (not affectedEventListeners or not affectedEventListeners[lastEventListener]) and lastEventListener:isActive() then
            lastEventListener:onMouseExit(pos - receiverPos, modifiers)
        end
        lastEventListener = lastEventListener.parent
    end
end

--- @param pos ammgui.Vec2
--- @param modifiers integer
--- @param topEventListener ammgui._impl.eventListener.EventListener
--- @param affectedEventListeners table<ammgui._impl.eventListener.EventListener, ammgui.Vec2>
--- @param sendMove boolean
function ns.EventManager:_sendMouseEnterOrMove(pos, modifiers, topEventListener, affectedEventListeners, sendMove)
    do
        local chain = {}
        local currentEventListener = topEventListener
        while currentEventListener do
            local receiverPos = affectedEventListeners[currentEventListener]
            if receiverPos and currentEventListener:isActive() then
                if not self._lastAffectedHoverEventListeners[currentEventListener] then
                    table.insert(chain, currentEventListener)
                end
            end
            currentEventListener = currentEventListener.parent
        end
        for _, eventListener in ipairs(chain) do
            eventListener:onMouseEnter(pos - affectedEventListeners[eventListener], modifiers)
        end
    end
    if sendMove then
        local currentEventListener = topEventListener
        local propagate = true
        while currentEventListener do
            local receiverPos = affectedEventListeners[currentEventListener]
            if receiverPos and currentEventListener:isActive() then
                if self._lastAffectedHoverEventListeners[currentEventListener] then
                    propagate = currentEventListener:onMouseMove(pos - receiverPos, modifiers, propagate)
                end
            end
            currentEventListener = currentEventListener.parent
        end
    end
end

--- @param topEventListener ammgui._impl.eventListener.EventListener?
--- @param affectedEventListeners table<ammgui._impl.eventListener.EventListener, ammgui.Vec2>
--- @return ammgui._impl.eventListener.EventListener? dragTarget
--- @return any? cookie
function ns.EventManager:_findDragTarget(topEventListener, affectedEventListeners)
    do
        local currentEventListener = topEventListener
        while currentEventListener do
            if affectedEventListeners[currentEventListener] and currentEventListener:isActive() then
                local cookie = currentEventListener:isDragTarget()
                if cookie then
                    return currentEventListener, cookie
                end
            end
            currentEventListener = currentEventListener.parent
        end
    end
    return nil, nil
end

--- @param topEventListener ammgui._impl.eventListener.EventListener?
--- @param affectedEventListeners table<ammgui._impl.eventListener.EventListener, ammgui.Vec2>
--- @return ammgui._impl.eventListener.EventListener? draggable
function ns.EventManager:_findDraggable(topEventListener, affectedEventListeners)
    do
        local currentEventListener = topEventListener
        while currentEventListener do
            if affectedEventListeners[currentEventListener] and currentEventListener:isActive() and currentEventListener:isDraggable() then
                return currentEventListener
            end
            currentEventListener = currentEventListener.parent
        end
    end
    return nil
end

return ns
