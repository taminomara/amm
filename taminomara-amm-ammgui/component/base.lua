local class = require "ammcore.class"
local fun = require "ammcore.fun"
local rule = require "ammgui.css.rule"
local log = require "ammcore.log"
local defer = require "ammcore.defer"
local eventManager = require "ammgui.eventManager"
local api          = require "ammgui.component.api"

--- Base class node implementations.
---
--- !doctype module
--- @class ammgui.component.base
local ns = {}

local logger = log.Logger:New()

local function runEventHandler(handler, ...)
    local result = nil
    if handler then
        local ok, err = defer.xpcall(function(...) result = handler(...) end, ...)
        if not ok then
            logger:error("Error in event handler: %s\n%s", err.message, err.trace)
        end
    end
    return result
end

--- Base for objects that can display their debug overlay.
---
--- @class ammgui.component.base.SupportsDebugOverlay
local SupportsDebugOverlay = {}

--- Draw debug overlay on top of an already rendered picture.
---
--- @param ctx ammgui.component.context.RenderingContext
--- @param drawContent boolean
--- @param drawPadding boolean
--- @param drawOutline boolean
--- @param drawMargin boolean
function SupportsDebugOverlay:drawDebugOverlay(ctx, drawContent, drawPadding, drawOutline, drawMargin)
end

--- An interface that abstracts over a single component and a list of components.
---
--- Things like lists and functional components implement `ComponentProvider`.
--- They perform their synchronization logic and yield `Component` implementations.
---
--- `Component`, on the other hand, is a thing that we actually see on the screen.
--- For convenience, each `Component` implements `ComponentProvider`, yielding itself
--- as the only implementation.
---
--- @class ammgui.component.base.ComponentProvider: ammcore.class.Base
ns.ComponentProvider = class.create("ComponentProvider")

--- @param key integer | string | nil
---
--- !doctype classmethod
--- @generic T: ammgui.component.base.ComponentProvider
--- @param self T
--- @return T
function ns.ComponentProvider:New(key)
    self = class.Base.New(self)

    --- Key for synchronizing arrays of nodes.
    ---
    --- @type integer | string | nil
    self.key = key

    return self
end

--- Called when component is initialized.
---
--- !doc abstract
--- @param ctx ammgui.component.context.SyncContext
--- @param data ammgui.dom.Node user-provided component data.
function ns.ComponentProvider:onMount(ctx, data)
    error("not implemented")
end

--- Called when component is updated.
---
--- !doc abstract
--- @param ctx ammgui.component.context.SyncContext
--- @param data ammgui.dom.Node user-provided component data.
function ns.ComponentProvider:onUpdate(ctx, data)
    error("not implemented")
end

--- Called when component is destroyed.
---
--- !doc abstract
--- @param ctx ammgui.component.context.SyncContext
function ns.ComponentProvider:onUnmount(ctx)
    error("not implemented")
end

--- Called to collect actual component implementations.
---
--- Should add actual component implementations to the given array.
---
--- @param components ammgui.component.base.Component[]
function ns.ComponentProvider:collect(components)
    error("not implemented")
end

--- Process a reference.
---
--- @param ref ammgui.component.block.func.Ref<ammgui.component.api.ComponentApi?>
function ns.ComponentProvider:noteRef(ref)
    error("not implemented")
end

--- Base class for all components.
---
--- Generally, there three kinds of components:
---
--- - normal nodes: things like ``<div>`` or ``<span>``;
---
--- - text fragments: wrapped raw strings. Their ``display`` is always ``inline``.
---
--- - text box: an implicit component that's created every time we encounter ``inline``
---   or ``inline-block`` components inside of a ``block`` component.
---
---   Text box breaks its contents into text elements, flows them into lines,
---   and renders them in a box.
---
--- The layout algorithm starts at the root component, which is always treated
--- as ``display: block``.
---
--- When we're inside of a block component (that is, anything other than
--- ``display: inline`` or ``display: inline-block``), we iterate over children
--- and group all consecutive ``inline`` and ``inline-block`` components into text boxes.
---
--- This way, block components only have other block components as children.
---
--- After we've ensured that all children are blocks, we lay them out according
--- to the component's ``display`` (i.e. ``block``, ``flex``, etc.)
---
--- When we're inside of a text box, we split the children into inline elements.
--- Each inline element represents a single non-breakable unit of text.
--- Text fragments are split into words, ``inline-block`` and ``block`` components
--- are wrapped into special elements, and ``inline`` components are recursively
--- broken down.
---
--- After splitting children into elements, we perform a line flow algorithm.
---
--- @class ammgui.component.base.Component: ammgui.eventManager.EventListener, ammgui.component.base.ComponentProvider, ammgui.component.base.SupportsDebugOverlay
ns.Component = class.create("Component", eventManager.EventListener)

--- Name of a DOM node that corresponds to this component.
---
--- @type string
ns.Component.elem = nil

--- @param key integer | string | nil
---
--- !doctype classmethod
--- @generic T: ammgui.component.base.Component
--- @param self T
--- @return T
function ns.Component:New(key)
    self = class.Base.New(self)

    --- Unique ID for this component.
    ---
    --- @type table
    self.id = {}

    --- Key for synchronizing arrays of nodes.
    ---
    --- @type integer | string | nil
    self.key = key

    --- Indicates that a state of this component or its child has changed,
    --- and it needs a layout recalculation.
    ---
    --- New components are always created as `outdated`.
    ---
    --- @type boolean
    self.outdated = true

    --- Indicates that CSS properties of this component or its child has changed,
    --- and it needs a CSS recalculation.
    ---
    --- During CSS recalculation this component might actually become `outdated`,
    --- if changes in CSS properties affecting its layout were detected.
    ---
    --- @type boolean
    self.outdatedCss = true

    --- Resolved CSS rules.
    ---
    --- @type ammgui.css.rule.Resolved
    self.css = nil

    --- @private
    --- @type boolean
    self._isActive = false

    --- @private
    --- @type ammgui.css.rule.Rule
    self._inlineRaw = {}

    --- @private
    --- @type ammgui.css.rule.CompiledRule
    self._inline = { compiledSelectors = {}, isLayoutSafe = true }

    --- @private
    --- @type boolean
    self._shouldHonorInlineCss = true

    --- @private
    --- @type boolean
    self._cssSettingsChanged = true

    --- @private
    --- @type table<string, true>
    self._classes = {}

    --- @private
    --- @type boolean
    self._shouldHonorInlineClasses = true

    --- @private
    --- @type table<string, true>
    self._pseudo = {}

    return self
end

--- Called when component is initialized.
---
--- !doc virtual
--- @param ctx ammgui.component.context.SyncContext
--- @param data ammgui.dom.Node user-provided component data.
function ns.Component:onMount(ctx, data)
    self._isActive = true
    ns.Component.onUpdate(self, ctx, data)
end

--- Called when component is updated.
---
--- If new data causes changes in layout, `onUpdate` handler should set `outdated`
--- to `true` to make sure that its layout is properly recalculated.
---
--- Changes to inline CSS styles and set of component's classes and pseudoclasses
--- should be handled through appropriate functions. If CSS settings change,
--- `outdated` will be set automatically during the CSS synchronization pass.
---
--- !doc virtual
--- @param ctx ammgui.component.context.SyncContext
--- @param data ammgui.dom.Node user-provided component data.
function ns.Component:onUpdate(ctx, data)
    self:setInlineCss(data.style or {})
    self:setClasses(data.class or {})

    self._onMouseEnterHandler = data.onMouseEnter
    self._onMouseMoveHandler = data.onMouseMove
    self._onMouseExitHandler = data.onMouseExit
    self._onMouseDownHandler = data.onMouseDown
    self._onMouseUpHandler = data.onMouseUp
    self._onClickHandler = data.onClick
    self._onMouseWheelHandler = data.onMouseWheel
    self._dragTarget = data.dragTarget
    if data.isDraggable == nil then
        self._isDraggable =
            data.onDragStart ~= nil
            or data.onDrag ~= nil
            or data.onDragEnd ~= nil
    else
        self._isDraggable = data.isDraggable
    end
    self._onDragStartHandler = data.onDragStart
    self._onDragHandler = data.onDrag
    self._onDragEndHandler = data.onDragEnd
end

--- Called when component is destroyed.
---
--- !doc virtual
function ns.Component:onUnmount(ctx)
    self._isActive = false
end

function ns.Component:collect(components)
    table.insert(components, self)
end

function ns.Component:noteRef(ref)
    ref.current = api.ComponentApi:New(self)
end

--- This function handles CSS updates.
---
--- Depending on the state of `outdatedCss` flag, it will reset `css`
--- and set `outdated` if any changes affecting component's layout were detected.
--- If will then call `propagateCssChanges` if necessary.
---
--- @param context ammgui.css.component.CssContext
function ns.Component:updateCss(context)
    local _ <close>, outdated, shouldPropagate, newCss = context:descendNode(
        self.css,
        self.elem,
        self._classes,
        self._pseudo,
        self._inline,
        self.outdatedCss,
        self._cssSettingsChanged
    )

    self.css = newCss
    self.outdated = self.outdated or outdated
    if shouldPropagate then
        self:propagateCssChanges(context)
    end
    self._cssSettingsChanged = false
    self.outdatedCss = false
end

--- Called when CSS settings change.
---
--- This function should propagate CSS changes to component's children
--- by calling `updateCss` on them. If a child became outdated, it should
--- mark `self` as outdated as well.
---
--- !doc abstract
--- @param context ammgui.css.component.CssContext current CSS context.
function ns.Component:propagateCssChanges(context)
    error("not implemented")
end

--- Set inline styles defined for this component.
---
--- @param inline ammgui.css.rule.Rule
--- @param force boolean?
function ns.Component:setInlineCss(inline, force)
    if #inline > 0 then
        error("inline CSS rules can't have selectors in them")
    end

    if not force and not self._shouldHonorInlineCss then
        return
    elseif force then
        self._shouldHonorInlineCss = false
    end

    if not fun.t.deepEq(self._inlineRaw, inline) then
        self._inlineRaw = inline
        self._inline = rule.compile(inline, 0, 0)
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Override current set of CSS classes by a new set.
---
--- @param classes string | (string | false)[]
--- @param force boolean?
function ns.Component:setClasses(classes, force)
    if not force and not self._shouldHonorInlineClasses then
        return
    elseif force then
        self._shouldHonorInlineClasses = false
    end

    local newClasses = {}
    if type(classes) == "string" then
        for name in classes:gmatch("%S+") do
            newClasses[name] = true
        end
    else
        for _, class in ipairs(classes) do
            if class then
                for name in class:gmatch("%S+") do
                    newClasses[name] = true
                end
            end
        end
    end

    if not fun.t.eq(self._classes, newClasses) then
        self._classes = newClasses
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Add a CSS class to the set of classes of this component.
---
--- @param className string
--- @param force boolean?
function ns.Component:setClass(className, force)
    if not force and not self._shouldHonorInlineClasses then
        return
    elseif force then
        self._shouldHonorInlineClasses = false
    end

    if not self._classes[className] then
        self._classes[className] = true
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Remove a CSS class form the set of classes of this component.
---
--- @param className string
--- @param force boolean?
function ns.Component:unsetClass(className, force)
    if not force and not self._shouldHonorInlineClasses then
        return
    elseif force then
        self._shouldHonorInlineClasses = false
    end

    if self._classes[className] then
        self._classes[className] = nil
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Check if a CSS class is set for this component.
---
--- @param className string
--- @return boolean
function ns.Component:hasClass(className)
    return self._classes[className] or false
end

--- Add a CSS pseudoclass to the set of classes of this component.
---
--- @param pseudoName string
function ns.Component:setPseudoclass(pseudoName)
    if not self._pseudo[pseudoName] then
        self._pseudo[pseudoName] = true
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Remove a CSS pseudoclass form the set of classes of this component.
---
--- @param pseudoName string
function ns.Component:unsetPseudoclass(pseudoName)
    if self._pseudo[pseudoName] then
        self._pseudo[pseudoName] = nil
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Check if a CSS class is set for this component.
---
--- @param className string
--- @return boolean
function ns.Component:hasPseudoclass(className)
    return self._pseudo[className] or false
end

--- Helper for drawing container's background and margins.
---
--- @param ctx ammgui.component.context.RenderingContext
--- @param position Vector2D
--- @param size Vector2D
--- @param backgroundColor Color
--- @param outlineWidth number
--- @param outlineTint Color
--- @param outlineRadius number
--- @param hasOutlineLeft boolean?
--- @param hasOutlineRight boolean?
function ns.Component.drawContainer(
    ctx,
    position,
    size,
    backgroundColor,
    outlineWidth,
    outlineTint,
    outlineRadius,
    hasOutlineLeft,
    hasOutlineRight
)
    if
        backgroundColor.a == 0
        and (outlineTint.a == 0 or outlineWidth == 0)
    then
        return
    end

    if hasOutlineLeft == nil then
        hasOutlineLeft = true
    end
    if hasOutlineRight == nil then
        hasOutlineRight = true
    end

    ctx.gpu:pushClipRect(position, size)

    local dp = structs.Vector2D { 0, 0 }
    local ds = structs.Vector2D { 0, 0 }

    if not hasOutlineLeft then
        dp = dp - structs.Vector2D { 2 * outlineWidth, 0 }
        ds = ds + structs.Vector2D { 2 * outlineWidth, 0 }
    end
    if not hasOutlineRight then
        ds = ds + structs.Vector2D { 2 * outlineWidth, 0 }
    end

    ctx.gpu:drawBox {
        position = position + dp,
        size = size + ds,
        rotation = 0,
        color = backgroundColor,
        image = "",
        imageSize = structs.Vector2D { x = 0, y = 0 },
        hasCenteredOrigin = false,
        horizontalTiling = false,
        verticalTiling = false,
        isBorder = false,
        margin = { top = 0, right = 0, bottom = 0, left = 0 },
        isRounded = true,
        radii = structs.Vector4 {
            hasOutlineLeft and outlineRadius or 0,
            hasOutlineRight and outlineRadius or 0,
            hasOutlineRight and outlineRadius or 0,
            hasOutlineLeft and outlineRadius or 0,
        },
        hasOutline = true,
        outlineThickness = outlineWidth,
        outlineColor = outlineTint,
    }

    ctx.gpu:popClip()
end

--- Helper for drawing debug overlay.
---
--- @param ctx ammgui.component.context.RenderingContext
--- @param pos Vector2D
--- @param size Vector2D
--- @param holePos Vector2D
--- @param holeSize Vector2D
--- @param color Color
function ns.Component.drawRectangleWithHole(ctx, pos, size, holePos, holeSize, color)
    ctx.gpu:drawRect(
        pos,
        structs.Vector2D { size.x, holePos.y - pos.y },
        color,
        "",
        0
    )
    ctx.gpu:drawRect(
        structs.Vector2D { pos.x, holePos.y + holeSize.y },
        structs.Vector2D { size.x, size.y - holeSize.y - (holePos.y - pos.y) },
        color,
        "",
        0
    )
    ctx.gpu:drawRect(
        structs.Vector2D { pos.x, holePos.y },
        structs.Vector2D { holePos.x - pos.x, holeSize.y },
        color,
        "",
        0
    )
    ctx.gpu:drawRect(
        structs.Vector2D { holePos.x + holeSize.x, holePos.y },
        structs.Vector2D { size.x - holeSize.x - (holePos.x - pos.x), holeSize.y },
        color,
        "",
        0
    )
end

--- @return ammgui.devtools.Element
function ns.Component:repr()
    local classes = {}
    for class, _ in pairs(self._classes) do
        table.insert(classes, class)
    end
    table.sort(classes)

    local pseudoclasses = {}
    for pseudoclass, _ in pairs(self._pseudo) do
        table.insert(pseudoclasses, ":" .. pseudoclass)
    end
    table.sort(pseudoclasses)

    return {
        id = self.id,
        name = self.elem or "",
        classes = classes,
        pseudoclasses = pseudoclasses,
        css = self.css,
        children = self:reprChildren(),
    }
end

--- @return ammgui.devtools.Element[]
function ns.Component:reprChildren()
    return {}
end

function ns.Component:drawDebugOverlay(ctx, drawContent, drawPadding, drawOutline, drawMargin)
end

function ns.Component:isActive()
    return self._isActive
end

function ns.Component:onMouseEnter(pos, modifiers)
    self:setPseudoclass("hover")
    if self._onMouseEnterHandler then
        runEventHandler(self._onMouseEnterHandler, pos, modifiers) --[[ @as boolean ]]
    end
end

function ns.Component:onMouseMove(pos, modifiers, propagate)
    if propagate and self._onMouseMoveHandler then
        propagate = runEventHandler(self._onMouseMoveHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseExit(pos, modifiers)
    self:unsetPseudoclass("hover")
    if self._onMouseExitHandler then
        runEventHandler(self._onMouseExitHandler, pos, modifiers) --[[ @as boolean ]]
    end
end

function ns.Component:onMouseDown(pos, modifiers, propagate)
    if propagate and self._onMouseDownHandler then
        propagate = runEventHandler(self._onMouseDownHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseUp(pos, modifiers, propagate)
    if propagate and self._onMouseUpHandler then
        propagate = runEventHandler(self._onMouseUpHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onClick(pos, modifiers, propagate)
    if propagate and self._onClickHandler then
        propagate = runEventHandler(self._onClickHandler, pos, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:onMouseWheel(pos, delta, modifiers, propagate)
    if propagate and self._onMouseWheelHandler then
        propagate = runEventHandler(self._onMouseWheelHandler, pos, delta, modifiers) --[[ @as boolean ]]
        if propagate == nil then propagate = true end
    end
    return propagate
end

function ns.Component:isDraggable()
    return self._isDraggable
end

function ns.Component:isDragTarget()
    return self._dragTarget
end

function ns.Component:onDragStart(pos, origin, modifiers, target)
    self:setPseudoclass("drag")
    if self._onDragStartHandler then
        return self._onDragStartHandler(pos, origin, modifiers, target)
    end
end

function ns.Component:onDrag(pos, origin, modifiers, target)
    if self._onDragHandler then
        return self._onDragHandler(pos, origin, modifiers, target)
    end
end

function ns.Component:onDragEnd(pos, origin, modifiers, target)
    self:unsetPseudoclass("drag")
    if self._onDragEndHandler then
        self._onDragEndHandler(pos, origin, modifiers, target)
    end
end

function ns.Component:onDragEnter(status)
    if status ~= "none" then
        self:setPseudoclass("drop")
        for _, pseudo in ipairs { "ok", "warn", "err" } do
            if pseudo == status then
                self:setPseudoclass("drop-" .. pseudo)
            else
                self:unsetPseudoclass("drop-" .. pseudo)
            end
        end
    end
end

function ns.Component:onDragExit()
    self:unsetPseudoclass("drop")
    self:unsetPseudoclass("drop-ok")
    self:unsetPseudoclass("drop-warn")
    self:unsetPseudoclass("drop-err")
end

--- @type ammgui.component.inline.text?
local text = nil

return ns
