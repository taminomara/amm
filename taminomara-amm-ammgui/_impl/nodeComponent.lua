local class = require "ammcore.class"
local component = require "ammgui._impl.component"
local id = require "ammgui._impl.id"
local textMeasure = require "ammgui._impl.textMeasure"
local rule = require "ammgui.css.rule"
local fun = require "ammcore.fun"

--- A node component, implements an HTML tag.
---
--- !doctype module
--- @class ammgui._impl.nodeComponent
local ns = {}

--- A node component, implements an HTML tag.
---
--- @class ammgui._impl.nodeComponent.NodeComponent: ammgui._impl.component.Component
ns.NodeComponent = class.create("NodeComponent", component.Component)

--- Parent HTML tag.
---
--- @type ammgui._impl.nodeComponent.NodeComponent?
ns.NodeComponent.parent = nil

--- Child HTML tags.
---
--- @type ammgui._impl.nodeComponent.NodeComponent[]?
ns.NodeComponent.children = nil

--- Child components.
---
--- @type ammgui._impl.component.Component[]?
ns.NodeComponent.childComponents = nil

--- @param key any?
---
--- !doctype classmethod
--- @generic T: ammgui._impl.nodeComponent.NodeComponent
--- @param self T
--- @return T
function ns.NodeComponent:New(key)
    self = component.Component.New(self, key)

    --- Unique ID of this component.
    ---
    --- @type ammgui._impl.id.ComponentId
    self.id = id.newComponentId()

    return self
end

function ns.NodeComponent:onMount(ctx, data)
    self.childComponents, self.children = self.syncAll(ctx, {}, {}, data, self)
end

function ns.NodeComponent:onUpdate(ctx, data)
    local childComponents, children, outdated, outdatedCss = self.syncAll(
        ctx, self.childComponents, self.children, data, self
    )

    self.childComponents = childComponents
    self.children = children
end

function ns.NodeComponent:onUnmount(ctx)
    error("todo")
end

function ns.NodeComponent:collect(components)
    table.insert(components, self)
end

function ns.NodeComponent:noteRef(ref)
    error("todo")
end

--- Implementation of a node component.
---
--- The reason to split node component and its implementation into a class
--- is so that we can move this logic to C++ without affecting
--- user-facing interfaces.
---
--- @class ammgui._impl.nodeComponent.NodeComponentImpl: ammcore.class.Base
ns.NodeComponentImpl = class.create("NodeComponentImpl")

--- @param tag string HTML tag name of the associated node.
--- @param eventListenerId ammgui._impl.id.EventListenerId
---
--- !doctype classmethod
--- @generic T: ammgui._impl.nodeComponent.NodeComponentImpl
--- @param self T
--- @return T
function ns.NodeComponentImpl:New(tag, eventListenerId)
    self = class.Base.New(self)

    --- @private
    --- @type string
    self._tag = tag

    --- @private
    --- @type ammgui._impl.id.EventListenerId
    self._eventListenerId = eventListenerId

    --- @private
    --- @type ammgui._impl.nodeComponent.NodeComponentImpl[]
    self._children = {}

    --- @private
    --- @type boolean
    self._cssOutdated = true

    --- @private
    --- @type boolean
    self._selfCssOutdated = false

    --- @private
    --- @type boolean
    self._layoutOutdated = true

    --- @private
    --- @type table<string, true>
    self._classes = {}

    --- @private
    --- @type table<string, true>
    self._pseudoclasses = {}

    --- @private
    --- @type ammgui.css.rule.CompiledRule?
    self._inline = nil

    --- @private
    --- @type ammgui.css.rule.Rule?
    self._inlineRaw = nil

    --- @private
    --- @type ammgui.css.rule.CompiledRule?
    self._inlineDynamic = nil

    --- @private
    --- @type ammgui.css.rule.Rule?
    self._inlineDynamicRaw = nil

    --- @private
    --- @type ammgui.css.rule.Resolved
    self._css = rule.Resolved:New({}, {}, nil, {}, {})

    return self
end

--- Set new HTML tag.
---
--- @param tag string
function ns.NodeComponentImpl:setTag(tag)
    self._tag = tag
    self._cssOutdated = true
    self._selfCssOutdated = true
end

--- Set inline styles defined for this component.
---
--- @param inline ammgui.css.rule.Rule
function ns.NodeComponentImpl:setInlineCss(inline)
    if #inline > 0 then
        error("inline CSS rules can't have selectors in them")
    end

    if not fun.t.deepEq(self._inlineRaw, inline) then
        self._inlineRaw = inline
        self._inline = rule.compile(inline, 0, 0)
        self._cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Set inline dynamic styles defined for this component.
---
--- Dynamic styles are set via refs. They take precedence over normal styles.
---
--- @param inline ammgui.css.rule.Rule
function ns.NodeComponentImpl:setInlineDynamicCss(inline)
    if #inline > 0 then
        error("inline CSS rules can't have selectors in them")
    end

    if not fun.t.deepEq(self._inlineRaw, inline) then
        self._inlineRaw = inline
        self._inline = rule.compile(inline, 0, 0)
        self._cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Override current set of CSS classes by a new set.
---
--- @param classes string | false | (string | false)[]
function ns.NodeComponentImpl:setClasses(classes)
    local newClasses = {}
    if type(classes) == "string" then
        for name in classes:gmatch("%S+") do
            newClasses[name] = true
        end
    elseif classes then
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
        self._cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Add a CSS class to the set of classes of this component.
---
--- @param className string
function ns.NodeComponentImpl:setClass(className)
    if not self._classes[className] then
        self._classes[className] = true
        self._cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Remove a CSS class form the set of classes of this component.
---
--- @param className string
function ns.NodeComponentImpl:unsetClass(className)
    if self._classes[className] then
        self._classes[className] = nil
        self._cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Check if a CSS class is set for this component.
---
--- @param className string
--- @return boolean
function ns.NodeComponentImpl:hasClass(className)
    return self._classes[className] or false
end

--- Add a CSS pseudoclass to the set of classes of this component.
---
--- @param pseudoName string
function ns.NodeComponentImpl:setPseudoclass(pseudoName)
    if not self._pseudoclasses[pseudoName] then
        self._pseudoclasses[pseudoName] = true
        self._cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Remove a CSS pseudoclass form the set of classes of this component.
---
--- @param pseudoName string
function ns.NodeComponentImpl:unsetPseudoclass(pseudoName)
    if self._pseudoclasses[pseudoName] then
        self._pseudoclasses[pseudoName] = nil
        self._cssOutdated = true
        self._selfCssOutdated = true
    end
end

--- Check if a CSS class is set for this component.
---
--- @param className string
--- @return boolean
function ns.NodeComponentImpl:hasPseudoclass(className)
    return self._pseudoclasses[className] or false
end

--- Set new array of children.
---
--- This function should be called after the children were updated
--- and their `outdated` flags were set.
---
--- @param children ammgui._impl.nodeComponent.NodeComponentImpl[]
function ns.NodeComponentImpl:setChildren(children)
    self._cssOutdated =
        self._cssOutdated
        or fun.a.any(children, fun.get("_cssOutdated"))
    self._layoutOutdated =
        self._layoutOutdated
        or fun.a.any(children, fun.get("_layoutOutdated"))
        or not fun.a.eq(children, self._children)
    self._children = children
end

--- @param ctx ammgui._impl.cssContext.CssContext
function ns.NodeComponentImpl:_syncCss(ctx)
    local _ <close>, outdated, shouldPropagate, newCss = ctx:descendNode(
        self.css,
        self._tag,
        self._classes,
        self._pseudoclasses,
        self._inline,
        self._inlineDynamic,
        self._cssOutdated,
        self._selfCssOutdated
    )

    self.css = newCss
    self._layoutOutdated = self._layoutOutdated or outdated
    if shouldPropagate then
        for _, child in ipairs(self._children) do
            child:_syncCss(ctx)
        end
    end
    self._selfCssOutdated = false
    self._cssOutdated = false
end

--- @param tms ammgui._impl.textMeasure.TextMeasure
function ns.NodeComponentImpl:_prepareLayout(tms)
    if self._layoutOutdated then
        -- TODO!
    end

    for _, child in ipairs(self._children) do
        child:_prepareLayout(tms)
    end
end

--- Update CSS and layout and render an updated screen.
---
--- @param ctx ammgui._impl.cssContext.CssContext
--- @param gpu FINComputerGPUT2
function ns.NodeComponentImpl:refresh(ctx, gpu)
    self:_syncCss(ctx)

    if self._layoutOutdated then
        local tms = textMeasure.TextMeasure:New()
        self:_prepareLayout(tms)
        tms:run(gpu)
    end
end

return ns
