local class = require "ammcore.class"
local array = require "ammcore._util.array"
local rule = require "ammgui.css.rule"
local log  = require "ammcore.log"

--- Base class for inline and block components.
---
--- !doctype module
--- @class ammgui.component.base
local ns = {}

--- Base class for inline and block components.
---
--- @class ammgui.component.base.Component: ammcore.class.Base
ns.Component = class.create("Component")

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

    --- @type ammgui.css.rule.Rule
    --- @private
    self._inlineRaw = {}

    --- @type ammgui.css.rule.CompiledRule
    --- @private
    self._inline = {}

    --- @private
    --- @type boolean
    self._cssSettingsChanged = true

    --- @private
    --- @type table<string, true>
    self._classes = {}

    --- @private
    --- @type table<string, true>
    self._pseudo = {}

    --- @private
    --- @type table
    self._id = {}

    return self
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
function ns.Component:setInlineCss(inline)
    if #inline > 0 then
        error("inline CSS rules can't have selectors in them")
    end

    if not array.deepEq(self._inlineRaw, inline) then
        self._inlineRaw = inline
        self._inline = rule.compile(inline, 0, 0)
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Override current set of CSS classes by a new set.
---
--- @param classes string | (string | false)[]
function ns.Component:setClasses(classes)
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

    if not array.eq(self._classes, newClasses) then
        self._classes = newClasses
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Add a CSS class to the set of classes of this component.
---
--- @param className string
function ns.Component:setClass(className)
    if not self._classes[className] then
        self._classes[className] = true
        self._cssSettingsChanged = true
        self.outdatedCss = true
    end
end

--- Remove a CSS class form the set of classes of this component.
---
--- @param className string
function ns.Component:unsetClass(className)
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

--- Helper to draw container's background and margins.
---
--- @param context ammgui.component.context.RenderingContext
--- @param position Vector2D
--- @param size Vector2D
--- @param backgroundColor Color
--- @param outlineWidth number
--- @param outlineTint Color
--- @param outlineRadius number
--- @param hasOutlineLeft boolean?
--- @param hasOutlineRight boolean?
function ns.Component:drawContainer(
    context,
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

    context.gpu:pushClipRect(position, size)

    local dp = structs.Vector2D { 0, 0 }
    local ds = structs.Vector2D { 0, 0 }

    if not hasOutlineLeft then
        dp = dp - structs.Vector2D { 2 * outlineWidth, 0 }
        ds = ds + structs.Vector2D { 2 * outlineWidth, 0 }
    end
    if not hasOutlineRight then
        ds = ds + structs.Vector2D { 2 * outlineWidth, 0 }
    end

    context.gpu:drawBox {
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
            hasOutlineLeft and outlineRadius or 0
        },
        hasOutline = true,
        outlineThickness = outlineWidth,
        outlineColor = outlineTint,
    }

    context.gpu:popClip()
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
        id = self._id,
        name = self.elem or "",
        classes = classes,
        pseudoclasses = pseudoclasses,
        cssRules = {},
        children = self:reprChildren(),
    }
end

--- @return ammgui.devtools.Element[]
function ns.Component:reprChildren()
    return {}
end

return ns
