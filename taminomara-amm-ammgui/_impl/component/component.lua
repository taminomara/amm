local class = require "ammcore.class"
local id = require "ammgui._impl.id"
local rule = require "ammgui.css.rule"
local fun = require "ammcore.fun"
local provider = require "ammgui._impl.component.provider"
local resolved = require "ammgui._impl.css.resolved"
local api = require "ammgui.api"
local log = require "ammcore.log"
local defer = require "ammcore.defer"

--- Base class for all components.
---
--- !doctype module
--- @class ammgui._impl.component.component
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

--- Base class for all components, implements facilities for event handling
--- and CSS propagation.
---
--- @class ammgui._impl.component.component.Component: ammgui._impl.component.provider.Provider, ammgui._impl.eventListener.EventListener
ns.Component = class.create("Component", provider.Provider)

--- Parent component.
---
--- @type ammgui._impl.component.component.Component?
ns.Component.parent = nil

--- @param key any?
---
--- !doctype classmethod
--- @generic T: ammgui._impl.component.component.Component
--- @param self T
--- @return T
function ns.Component:New(key)
    self = provider.Provider.New(self, key)

    --- Unique ID for this component.
    ---
    --- @type ammgui._impl.id.EventListenerId
    self.id = id.newEventListenerId()

    --- Currently used layout algorithm.
    ---
    --- The exact implementation depends on which component this is (a node or a text),
    --- and which ``display`` was specified in CSS rules.
    ---
    --- This attribute should not be modified directly. Instead, components should
    --- override `makeLayout`.
    ---
    --- @type ammgui._impl.layout.Layout?
    self.layout = nil

    --- Indicates that css rules of this component or its children could've changed
    --- due to new classes, inline styles, or freshly mounted new components.
    ---
    --- @type boolean
    self.cssOutdated = true

    --- Indicates that calculated layout of this component or its children
    --- could've changed due to updated CSS, or freshly mounted new components.
    ---
    --- @type boolean
    self.layoutOutdated = true

    --- @private
    --- @type boolean
    self._selfCssOutdated = false

    --- @protected
    --- @type string?
    self._tag = nil

    --- @private
    --- @type table<string, true>
    self._classes = {}

    --- @private
    --- @type table<string, true>
    self._pseudoclasses = {}

    --- @private
    --- @type ammgui._impl.css.resolved.CompiledRule?
    self._inline = nil

    --- @private
    --- @type ammgui.css.rule.Rule?
    self._inlineRaw = nil

    --- @private
    --- @type ammgui._impl.css.resolved.CompiledRule?
    self._inlineDynamic = nil

    --- @private
    --- @type ammgui.css.rule.Rule?
    self._inlineDynamicRaw = nil

    --- @private
    --- @type ammgui._impl.css.resolved.Resolved
    self._css = resolved.Resolved:New({}, {}, nil, {}, {})

    --- @private
    --- @type boolean
    self._isActive = true

    return self
end

--- @param data ammgui.dom.Node
function ns.Component:sync(ctx, data)
    error("not implemented")
end

--- @param data ammgui.dom.Node
function ns.Component:commit(ctx, data)
    self:onUpdate(ctx, data)
end

--- Called when component is updated.
---
--- !doc virtual
--- @param ctx ammgui._impl.context.sync.Context
--- @param data ammgui.dom.Node
function ns.Component:onUpdate(ctx, data)
    ---@diagnostic disable-next-line: invisible
    self:setTag(data._tag)
    self:setClasses(data.class or {})
    self:setInlineCss(data.style or {})

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
--- @param ctx ammgui._impl.context.sync.Context
function ns.Component:onUnmount(ctx)
    self._isActive = false
end

function ns.Component:collect(components)
    table.insert(components, self)
end

--- Process a reference.
---
--- @param ref ammgui.Ref<ammgui.NodeApi?>
function ns.Component:noteRef(ref)
    ref.current = api.NodeApi:New(self)
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

--- Set new HTML tag.
---
--- @param tag string
function ns.Component:setTag(tag)
    if tag ~= self._tag then
        self.cssOutdated = true
        self._selfCssOutdated = true
        self._tag = tag
    end
end

--- Set inline styles defined for this component.
---
--- @param inline ammgui.css.rule.Rule
function ns.Component:setInlineCss(inline)
    if #inline > 0 then
        error(string.format("rule at %s: inline CSS rules can't have selectors in them", inline.loc), 0)
    end

    if not fun.t.deepEq(self._inlineRaw, inline) then
        self._inlineRaw = inline
        self._inline = resolved.compile(inline, 0, 0)
        self.cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Set inline dynamic styles defined for this component.
---
--- Dynamic styles are set via refs. They take precedence over normal styles.
---
--- @param inline ammgui.css.rule.Rule
function ns.Component:setInlineDynamicCss(inline)
    if #inline > 0 then
        error("inline CSS rules can't have selectors in them", 0)
    end

    if not fun.t.deepEq(self._inlineDynamicRaw, inline) then
        self._inlineDynamicRaw = inline
        self._inlineDynamic = resolved.compile(inline, 0, 0)
        self.cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Override current set of CSS classes by a new set.
---
--- @param classes string | false | (string | false)[]
function ns.Component:setClasses(classes)
    local newClasses = {}

    local function parseClasses(classes)
        if type(classes) == "string" then
            for name in classes:gmatch("%S+") do
                newClasses[name] = true
            end
        elseif classes then
            for _, class in ipairs(classes) do
                if class then
                    parseClasses(class)
                end
            end
        end
    end

    parseClasses(classes)

    if not fun.t.eq(self._classes, newClasses) then
        self._classes = newClasses
        self.cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Add a CSS class to the set of classes of this component.
---
--- @param className string
function ns.Component:setClass(className)
    if not self._classes[className] then
        self._classes[className] = true
        self.cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Remove a CSS class form the set of classes of this component.
---
--- @param className string
function ns.Component:unsetClass(className)
    if self._classes[className] then
        self._classes[className] = nil
        self.cssOutdated = true
        self._selfCssOutdated = true
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
    if not self._pseudoclasses[pseudoName] then
        self._pseudoclasses[pseudoName] = true
        self.cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Remove a CSS pseudoclass form the set of classes of this component.
---
--- @param pseudoName string
function ns.Component:unsetPseudoclass(pseudoName)
    if self._pseudoclasses[pseudoName] then
        self._pseudoclasses[pseudoName] = nil
        self.cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Check if a CSS class is set for this component.
---
--- @param className string
--- @return boolean
function ns.Component:hasPseudoclass(className)
    return self._pseudoclasses[className] or false
end

--- This function handles CSS updates.
---
--- Depending on the state of `cssOutdated` flag, it will reset `css`
--- and set `layoutOutdated` if any changes affecting component's layout were detected.
--- It will then call `propagateCssChanges` if necessary.
---
--- @param ctx ammgui._impl.context.css.Context
function ns.Component:syncCss(ctx)
    local outdated, shouldPropagate, newCss = ctx:enterNode(
        self.css,
        self._tag,
        self._classes,
        self._pseudoclasses,
        self._inline,
        self._inlineDynamic,
        self.cssOutdated,
        self._selfCssOutdated
    )

    self.css = newCss
    self.layoutOutdated = self.layoutOutdated or outdated
    self._selfCssOutdated = false
    self.cssOutdated = false

    if shouldPropagate then
        self:propagateCssChanges(ctx)
    end

    ctx:exitNode()
end

--- Called when CSS settings change.
---
--- This function should propagate CSS changes to component's children
--- by calling `updateCss` on them. If a child became outdated, it should
--- mark `self` as outdated as well.
---
--- !doc virtual
--- @param ctx ammgui._impl.context.css.Context
function ns.Component:propagateCssChanges(ctx)
    -- nothing to do here.
end

--- Create a new instance of a layout.
---
--- !doc abstract
--- @return ammgui._impl.layout.Layout
function ns.Component:makeLayout()
    error("not implemented")
end

--- Update a layout by setting new CSS rules.
---
--- This function is called every tick if layout settings did not change,
--- but CSS settings did.
---
--- !doc virtual
function ns.Component:updateLayout()
    self.layout:updateCss(self.css)
end

--- This function updates layout implementations after CSS update.
---
--- Depending on whether `layoutOutdated` is `true`, it will call `makeLayout`
--- or `updateLayout`.
---
--- Descendants of this class should override this method to update layout trees
--- of their children before updating layout of themselves.
---
--- !doc virtual
function ns.Component:updateLayoutTree()
    if self.layoutOutdated or not self.layout then
        self.layout = self:makeLayout()
    else
        self:updateLayout()
    end
    self.layoutOutdated = false
end

--- @return ammgui._impl.devtools.Element
function ns.Component:devtoolsRepr()
    local classes = {}
    for class, _ in pairs(self._classes) do
        table.insert(classes, class)
    end
    table.sort(classes)

    local pseudoclasses = {}
    for pseudoclass, _ in pairs(self._pseudoclasses) do
        table.insert(pseudoclasses, ":" .. pseudoclass)
    end
    table.sort(pseudoclasses)

    local baseLayout, usedLayout
    if not self.layout:isInline() then
        local blockLayout = self.layout:asBlock()
        baseLayout = blockLayout.baseLayout
        usedLayout = blockLayout.usedLayout
    end

    return {
        id = self.id,
        name = self._tag,
        inlineContent = nil,
        classes = classes,
        pseudoclasses = pseudoclasses,
        css = self.css,
        children = {},
        baseLayout = baseLayout,
        usedLayout = usedLayout,
    }
end

return ns
