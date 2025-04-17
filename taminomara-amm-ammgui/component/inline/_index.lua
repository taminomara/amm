local class = require "ammcore.class"
local log = require "ammcore.log"
local base = require "ammgui.component.base"
local array = require "ammcore._util.array"

--- Components that implement inline DOM nodes.
---
--- !doctype module
--- @class ammgui.component.inline
local ns = {}

local logger = log.Logger:New()

--- An interface that abstracts over a single component and a list of components.
---
--- @class ammgui.component.inline.ComponentProvider: ammcore.class.Base
ns.ComponentProvider = class.create("ComponentProvider")

--- @param key integer | string | nil
---
--- !doctype classmethod
--- @generic T: ammgui.component.inline.ComponentProvider
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
--- @param data ammgui.dom.inline.Node user-provided component data.
function ns.ComponentProvider:onMount(data)
    error("not implemented")
end

--- Called when component is updated.
---
--- !doc abstract
--- @param data ammgui.dom.inline.Node user-provided component data.
function ns.ComponentProvider:onUpdate(data)
    error("not implemented")
end

--- Called when component is destroyed.
---
--- !doc abstract
function ns.ComponentProvider:onUnmount()
    error("not implemented")
end

--- Called to collect actual component implementations.
---
--- Should add actual component implementations to the given array.
---
--- @param components ammgui.component.inline.Component[]
function ns.ComponentProvider:collect(components)
    error("not implemented")
end

--- An inline component of a text paragraph.
---
--- @class ammgui.component.inline.Component: ammgui.component.base.Component, ammgui.component.inline.ComponentProvider
ns.Component = class.create("Component", base.Component)

--- Name of a DOM node that corresponds to this component.
---
--- @type string
ns.Component.elem = nil

--- Called when component is initialized.
---
--- !doc virtual
--- @param data ammgui.dom.inline.Node user-provided component data.
function ns.Component:onMount(data)
    self:setInlineCss(data.style or {})
    self:setClasses(data.class or {})
end

--- Called when component is updated.
---
--- If new data causes changes in layout, `onUpdate` handler should set `outdated`
--- to `true` to make sure that its layout is properly recalculated.
---
--- !doc virtual
--- @param data ammgui.dom.inline.Node user-provided component data.
function ns.Component:onUpdate(data)
    self:setInlineCss(data.style or {})
    self:setClasses(data.class or {})
end

--- Called when component is destroyed.
---
--- !doc virtual
function ns.Component:onUnmount()
    -- nothing to do here.
end

--- A single component just adds itself to the list (see `ComponentProvider.collect`).
---
--- @param components ammgui.component.inline.Component[]
function ns.Component:collect(components)
    table.insert(components, self)
end

--- Split this node into an array of render-able elements.
---
--- @return ammgui.component.inline.Element[]
function ns.Component:calculateElements()
    error("not implemented")
end

--- Get or recalculate cached result of `calculateElements`.
---
--- Calling this function will reset `outdated` status.
---
--- @return ammgui.component.inline.Element[]
function ns.Component:getElements()
    if not self._elementsCache then
        self._elementsCache = self:calculateElements()
    end
    self.outdated = false
    return self._elementsCache
end

function ns.Component:propagateCssChanges(context)
    if self._elementsCache then
        for _, element in ipairs(self._elementsCache) do
            element.css = self.css
            if self.outdated then
                element._cachedSize = nil ---@diagnostic disable-line: invisible
                element._cachedAdjustedHeightA = nil ---@diagnostic disable-line: invisible
                element._cachedAdjustedHeightB = nil ---@diagnostic disable-line: invisible
                element:onCssUpdate()
            end
        end
    end
end

--- @type ammgui.component.inline.span?
local span = nil

--- Sync one DOM node with its component.
---
--- @param provider ammgui.component.inline.ComponentProvider? component that was updated.
--- @param node ammgui.dom.inline.Node | string
--- @return ammgui.component.inline.ComponentProvider component
function ns.Component.syncOne(provider, node)
    if type(node) == "string" then
        span = span or require("ammgui.component.inline.span") -- Prevent circular import.
        node = { node, _isInlineNode = true, _component = span.Span }
    end

    ---@diagnostic disable-next-line: invisible
    local nodeComponent = node._component
    if provider and nodeComponent == provider.__class then
        provider:onUpdate(node)
    else
        if provider then
            provider:onUnmount()
        end
        provider = nodeComponent:New(node.key)
        provider:onMount(node)
    end
    return provider
end

--- Sync array of DOM nodes with their providers.
---
--- @param providers ammgui.component.inline.ComponentProvider[]
--- @param nodes (ammgui.dom.inline.Node | string)[]
--- @return ammgui.component.inline.ComponentProvider[] providers
function ns.Component.syncProviders(providers, nodes)
    local providerByKey = {}
    for i, provider in ipairs(providers) do
        local key = provider.key or i
        if providerByKey[key] then
            logger:warning(
                "multiple components with the same key %s: %s, %s",
                log.pp(key), providerByKey[key], provider
            )
        else
            providerByKey[key] = provider
        end
    end

    local newProviders = {}

    local function syncOne(key, node)
        table.insert(newProviders, ns.Component.syncOne(providerByKey[key], node))
        providerByKey[key] = nil
    end

    local pendingString = nil
    local pendingStringKey = 0

    for _, node in ipairs(nodes) do
        if type(node) == "string" then
            if pendingString then
                pendingString = pendingString .. node
            else
                pendingString = node
                pendingStringKey = #newProviders + 1
            end
        ---@diagnostic disable-next-line: invisible
        elseif node._isInlineNode then
            --- @cast node ammgui.dom.inline.Node | string
            if pendingString then
                syncOne(pendingStringKey, pendingString)
                pendingString = nil
            end
            syncOne(node.key or #newProviders + 1, node)
        else
            error(string.format("not a dom node: %s", log.pp(node)))
        end
    end
    if pendingString then
        syncOne(pendingStringKey, pendingString)
    end

    return newProviders
end

--- Sync array of DOM nodes with their components.
---
--- @param providers ammgui.component.inline.ComponentProvider[]
--- @param components ammgui.component.inline.Component[]
--- @param nodes (ammgui.dom.inline.Node | string)[]
--- @return ammgui.component.inline.ComponentProvider[] providers
--- @return ammgui.component.inline.Component[] components
--- @return boolean outdated
--- @return boolean outdatedCss
function ns.Component.syncAll(providers, components, nodes)
    local newProviders = ns.Component.syncProviders(providers, nodes)

    local newComponents = {}
    for _, provider in ipairs(newProviders) do
        provider:collect(newComponents)
    end

    local outdated, outdatedCss = false, false
    for _, component in ipairs(newComponents) do
        outdated = outdated or component.outdated
        outdatedCss = outdatedCss or component.outdatedCss
    end

    -- Mark as outdated if number or order of components changed.
    outdated = outdated or not array.eq(components, newComponents)

    return newProviders, newComponents, outdated, outdatedCss
end

--- A single non-breaking element of a text.
---
--- @class ammgui.component.inline.Element: ammcore.class.Base
ns.Element = class.create("Element")

--- @param css ammgui.css.rule.Resolved
---
--- !doctype classmethod
--- @generic T: ammgui.component.inline.Element
--- @param self T
--- @return T
function ns.Element:New(css)
    self = class.Base.New(self)

    --- Css data for this word.
    ---
    --- @type ammgui.css.rule.Resolved
    self.css = css

    --- @protected
    --- @type integer?
    self._cachedSize = nil

    --- @protected
    --- @type number?
    self._cachedAdjustedHeightA = nil

    --- @protected
    --- @type number?
    self._cachedAdjustedHeightB = nil

    return self
end

--- Return element's size in pixels.
---
--- @return integer size element's text size.
function ns.Element:getSize()
    if not self._cachedSize then
        local size = table.unpack(self.css.fontSize) * 400 / 726
        self._cachedSize = math.max(math.floor(size + 0.5), 1)
    end

    return self._cachedSize
end

--- Get height of this element adjusted for line height.
---
--- @return number aboveBaseLine height that this element extends above the base line.
--- @return number belowBaseLine height that this element extends below the base line.
function ns.Element:getAdjustedHeight()
    if not self._cachedAdjustedHeightA or not self._cachedAdjustedHeightB then
        local heightA, heightB = self:getHeight()
        local lineHeight, unit = table.unpack(self.css.lineHeight)
        if unit == "" then
            self._cachedAdjustedHeightA = math.floor(heightA * lineHeight + 0.5)
            self._cachedAdjustedHeightB = math.floor(heightB * lineHeight + 0.5)
        else
            local totalHeight = heightA + heightB
            lineHeight = math.max(1, math.floor(lineHeight + 0.5))
            self._cachedAdjustedHeightA = math.max(1, math.floor(heightA * lineHeight / totalHeight + 0.5))
            self._cachedAdjustedHeightB = lineHeight - heightA
        end
    end

    return self._cachedAdjustedHeightA, self._cachedAdjustedHeightB
end

--- Called when element receives new CSS values.
---
--- Implementations should reset any cached parameters and re-calculate text sizes
--- and similar.
---
--- !doc abstract
--- @return number width
function ns.Element:onCssUpdate()
    error("not implemented")
end

--- Called to prepare for layout estimation.
---
--- This function primarily exists to measure string widths in batch,
--- as repeated calls to `gpu:measureText` are quite expensive.
---
--- !doc abstract
--- @param textMeasure ammgui.component.context.TextMeasure
function ns.Element:prepareLayout(textMeasure)
    error("not implemented")
end

--- Get width of this element.
---
--- !doc abstract
--- @return number width
function ns.Element:getWidth()
    error("not implemented")
end

--- Get height of this element.
---
--- !doc abstract
--- @return number aboveBaseLine height that this element extends above the base line.
--- @return number belowBaseLine height that this element extends below the base line.
function ns.Element:getHeight()
    error("not implemented")
end

--- Indicates that this element acts like a white space, and can be skipped
--- when wrapping text.
---
--- !doc virtual
--- @return boolean canSkip can be removed from the text when wrapping it.
function ns.Element:canSkip()
    return false
end

--- Render this element.
---
--- !doc abstract
--- @param context ammgui.component.context.RenderingContext
function ns.Element:render(context)
    error("not implemented")
end

return ns
