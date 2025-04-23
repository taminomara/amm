local class = require "ammcore.class"
local log = require "ammcore.log"

--- Event, drag'n'drop, and focus manager.
---
--- !doctype module
--- @class ammgui.eventManager
local ns = {}

local logger = log.Logger:New()

--- Base interface for an event receiver.
---
--- @class ammgui.eventManager.EventListener: ammcore.class.Base
ns.EventListener = class.create("EventListener")

--- Parent event receiver.
---
--- @type ammgui.eventManager.EventListener?
ns.EventListener.parent = nil

--- Indicates that this event listener should receive new events.
---
--- @return boolean
function ns.EventListener:isActive()
    return true
end

--- Triggered when mouse enters the receiver's area.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
function ns.EventListener:onMouseEnter(pos, modifiers)
end

--- Triggered when mouse moves over the receiver's area.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onMouseMove(pos, modifiers, propagate)
    return propagate
end

--- Triggered when mouse leaves the receiver's area.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
function ns.EventListener:onMouseExit(pos, modifiers)
end

--- Triggered when mouse button is pressed over the receiver's area.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onMouseDown(pos, modifiers, propagate)
    return propagate
end

--- Triggered when mouse button is released over the receiver's area.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onMouseUp(pos, modifiers, propagate)
    return propagate
end

--- Triggered when the left mouse button is clicked over the receiver's area.
---
--- For this event to be triggered, both `onMouseDown` and `onMouseUp` must happen
--- over the same target.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onClick(pos, modifiers, propagate)
    return propagate
end

--- Triggered when mouse wheel is rotated over the receiver's area.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param delta number
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onMouseWheel(pos, delta, modifiers, propagate)
    return propagate
end

--- Should return `true` if this event receiver can be dragged.
---
--- @return boolean
function ns.EventListener:isDraggable()
    return false
end

--- Should return non-`false` if this event receiver can serve
--- as a drag-and-drop target.
---
--- Whichever value is returned will be passed to `onDragEnd` handle.
---
--- @return any?
function ns.EventListener:isDragTarget()
    return nil
end

--- Triggered when this event receiver is being dragged.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param origin Vector2D point where the target was initially grabbed, relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param target any?
--- @return boolean|"normal"|"ok"|"warn"|"err"|"none"?
function ns.EventListener:onDragStart(pos, origin, modifiers, target)
end

--- Triggered when this event receiver is being dragged.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param origin Vector2D point where the target was initially grabbed, relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param target any?
--- @return boolean|"normal"|"ok"|"warn"|"err"|"none"?
function ns.EventListener:onDrag(pos, origin, modifiers, target)
end

--- Triggered when this event receiver is dropped.
---
--- If the event receiver was dropped over a drag target, the result
--- of the corresponding `isDragTarget` call will be passed in as ``target``.
---
--- @param pos Vector2D mouse position relative to the area's top-left corner.
--- @param origin Vector2D point where the target was initially grabbed, relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param target any?
function ns.EventListener:onDragEnd(pos, origin, modifiers, target)
end

--- Triggered on drag targets when a dragged object enters the target's area.
---
--- @param state "normal"|"ok"|"warn"|"err"|"none"? status of the drag target.
function ns.EventListener:onDragEnter(state)
end

--- Triggered on drag targets when a dragged object leaves the target's area.
function ns.EventListener:onDragExit()
end

--- Weak proxy for an event listener.
---
--- @class ammgui.eventManager.WeakEventListener: ammgui.eventManager.EventListener
ns.WeakEventListener = class.create("WeakEventListener", ns.EventListener)

--- @param inner ammgui.eventManager.EventListener
---
--- !doctype classmethod
--- @generic T: ammgui.eventManager.WeakEventListener
--- @param self T
--- @return T
function ns.WeakEventListener:New(inner)
    self = ns.EventListener.New(self)

    --- @private
    --- @type { inner: ammgui.eventManager.EventListener? }
    self._cache = setmetatable({ inner = inner }, { __mode = "v" })

    return self
end

--- @return ammgui.eventManager.EventListener?
function ns.WeakEventListener:_getEventListener()
    local inner = self._cache.inner
    if not inner then
        logger:trace("Ignored event on a dead listener")
    end
    return inner
end

function ns.WeakEventListener:isActive()
    local inner = self:_getEventListener()
    if inner then
        return inner:isActive()
    else
        return false
    end
end

function ns.WeakEventListener:onMouseEnter(pos, modifiers)
    local inner = self:_getEventListener()
    if inner then
        return inner:onMouseEnter(pos, modifiers)
    end
end

function ns.WeakEventListener:onMouseMove(pos, modifiers, propagate)
    local inner = self:_getEventListener()
    if inner then
        return inner:onMouseMove(pos, modifiers, propagate)
    else
        return propagate
    end
end

function ns.WeakEventListener:onMouseExit(pos, modifiers)
    local inner = self:_getEventListener()
    if inner then
        return inner:onMouseExit(pos, modifiers)
    end
end

function ns.WeakEventListener:onMouseDown(pos, modifiers, propagate)
    local inner = self:_getEventListener()
    if inner then
        return inner:onMouseDown(pos, modifiers, propagate)
    else
        return propagate
    end
end

function ns.WeakEventListener:onMouseUp(pos, modifiers, propagate)
    local inner = self:_getEventListener()
    if inner then
        return inner:onMouseUp(pos, modifiers, propagate)
    else
        return propagate
    end
end

function ns.WeakEventListener:onClick(pos, modifiers, propagate)
    local inner = self:_getEventListener()
    if inner then
        return inner:onClick(pos, modifiers, propagate)
    else
        return propagate
    end
end

function ns.WeakEventListener:onMouseWheel(pos, delta, modifiers, propagate)
    local inner = self:_getEventListener()
    if inner then
        return inner:onMouseWheel(pos, delta, modifiers, propagate)
    else
        return propagate
    end
end

function ns.WeakEventListener:isDraggable()
    local inner = self:_getEventListener()
    if inner then
        return inner:isDraggable()
    else
        return false
    end
end

function ns.WeakEventListener:isDragTarget()
    local inner = self:_getEventListener()
    if inner then
        return inner:isDragTarget()
    else
        return nil
    end
end

function ns.WeakEventListener:onDragStart(pos, origin, modifiers, target)
    local inner = self:_getEventListener()
    if inner then
        return inner:onDragStart(pos, origin, modifiers, target)
    else
        return nil
    end
end

function ns.WeakEventListener:onDrag(pos, origin, modifiers, target)
    local inner = self:_getEventListener()
    if inner then
        return inner:onDrag(pos, origin, modifiers, target)
    else
        return nil
    end
end

function ns.WeakEventListener:onDragEnd(pos, origin, modifiers, target)
    local inner = self:_getEventListener()
    if inner then
        return inner:onDragEnd(pos, origin, modifiers, target)
    else
        return nil
    end
end

function ns.WeakEventListener:onDragEnter(state)
    local inner = self:_getEventListener()
    if inner then
        return inner:onDragEnter(state)
    else
        return nil
    end
end

function ns.WeakEventListener:onDragExit()
    local inner = self:_getEventListener()
    if inner then
        return inner:onDragExit()
    else
        return nil
    end
end

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
    --- @type ammgui.eventManager.EventListener?
    self._lastHoverEventListener = nil

    --- @private
    --- @type table<ammgui.eventManager.EventListener, Vector2D>
    self._lastAffectedHoverEventListeners = {}

    --- @private
    --- @type table<ammgui.eventManager.EventListener, Vector2D>
    self._lastAffectedMouseDownEventListeners = {}

    --- @private
    --- @type boolean
    self._dragging = false

    --- @private
    --- @type ammgui.viewport.Window?
    self._dragOriginWindow = nil

    --- @private
    --- @type ammgui.eventManager.EventListener?
    self._draggedEventListener = nil

    --- @private
    --- @type Vector2D?
    self._draggedEventListenerPos = nil

    --- @private
    --- @type Vector2D?
    self._draggedEventListenerOrigin = nil

    --- @private
    --- @type ammgui.eventManager.EventListener?
    self._dragTarget = nil

    return self
end

--- @param mainWindow ammgui.viewport.Viewport
--- @param mainContext ammgui.component.context.RenderingContext
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
--- @param mainContext ammgui.component.context.RenderingContext
--- @param pos Vector2D
--- @return ammgui.eventManager.EventListener? topReceiver
--- @return table<ammgui.eventManager.EventListener, Vector2D> affectedReceivers
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
    self:_sendMouseExit(pos, modifiers, nil)

    self._lastHoverEventListener = nil
    self._lastAffectedHoverEventListeners = {}
end

--- @param pos Vector2D
--- @param modifiers integer
function ns.EventManager:OnMouseWheel(mainWindow, mainContext, pos, delta, modifiers)
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

--- @param pos Vector2D
--- @param modifiers integer
--- @param affectedEventListeners table<ammgui.eventManager.EventListener, Vector2D> | nil
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

--- @param pos Vector2D
--- @param modifiers integer
--- @param topEventListener ammgui.eventManager.EventListener
--- @param affectedEventListeners table<ammgui.eventManager.EventListener, Vector2D>
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

--- @param topEventListener ammgui.eventManager.EventListener?
--- @param affectedEventListeners table<ammgui.eventManager.EventListener, Vector2D>
--- @return ammgui.eventManager.EventListener? dragTarget
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

--- @param topEventListener ammgui.eventManager.EventListener?
--- @param affectedEventListeners table<ammgui.eventManager.EventListener, Vector2D>
--- @return ammgui.eventManager.EventListener? draggable
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
