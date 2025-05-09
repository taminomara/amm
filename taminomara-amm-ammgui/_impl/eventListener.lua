local class = require "ammcore.class"
local id    = require "ammgui._impl.id"

--- Event listener interface.
---
--- !doctype module
--- @class ammgui._impl.eventListener
local ns = {}

--- Base interface for an event receiver.
---
--- @class ammgui._impl.eventListener.EventListener: ammcore.class.Base
ns.EventListener = class.create("EventListener")

--- !doctype classmethod
--- @generic T: ammgui._impl.eventListener.EventListener
--- @param self T
--- @return T
function ns.EventListener:New()
    self = class.Base.New(self)

    --- A unique event listener id.
    ---
    --- !doctype const
    --- @type ammgui._impl.id.EventListenerId
    self.id = id.newEventListenerId()

    return self
end

--- Parent event receiver.
---
--- @type ammgui._impl.eventListener.EventListener?
ns.EventListener.parent = nil

--- Indicates that this event listener should receive new events.
---
--- @return boolean
function ns.EventListener:isActive()
    return true
end

--- Triggered when mouse enters the receiver's area.
---
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
function ns.EventListener:onMouseEnter(pos, modifiers)
end

--- Triggered when mouse moves over the receiver's area.
---
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onMouseMove(pos, modifiers, propagate)
    return propagate
end

--- Triggered when mouse leaves the receiver's area.
---
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
function ns.EventListener:onMouseExit(pos, modifiers)
end

--- Triggered when mouse button is pressed over the receiver's area.
---
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onMouseDown(pos, modifiers, propagate)
    return propagate
end

--- Triggered when mouse button is released over the receiver's area.
---
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
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
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param propagate boolean
--- @return boolean propagate
function ns.EventListener:onClick(pos, modifiers, propagate)
    return propagate
end

--- Triggered when mouse wheel is rotated over the receiver's area.
---
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
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
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param origin ammgui.Vec2 point where the target was initially grabbed, relative to the area's top-left corner.
--- @param modifiers integer see ``GPU T2`` for more info.
--- @param target any?
--- @return boolean|"normal"|"ok"|"warn"|"err"|"none"?
function ns.EventListener:onDragStart(pos, origin, modifiers, target)
end

--- Triggered when this event receiver is being dragged.
---
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param origin ammgui.Vec2 point where the target was initially grabbed, relative to the area's top-left corner.
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
--- @param pos ammgui.Vec2 mouse position relative to the area's top-left corner.
--- @param origin ammgui.Vec2 point where the target was initially grabbed, relative to the area's top-left corner.
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

return ns
