local class = require "ammcore.class"
local log = require "ammcore.log"

--- Components that implement inline DOM nodes.
---
--- !doctype module
--- @class ammgui.component.inline
local ns = {}

local logger = log.Logger:New()

--- An inline component of a text paragraph.
---
--- @class ammgui.component.inline.Component: ammcore.class.Base
ns.Component = class.create("Component")

--- @generic T: ammgui.component.inline.Component
--- @param self T
--- @return T
function ns.Component:New(key)
    self = class.Base.New(self)

    --- Key for synchronizing arrays of nodes.
    ---
    --- @type integer | string | nil
    self.key = key

    --- Indicates that this component's state has changed,
    --- and its needs a layout recalculation.
    ---
    --- New components are always created as `outdated`.
    ---
    --- @protected
    --- @type boolean
    self.outdated = true

    --- @private
    --- @type ammgui.component.inline.Element[]
    self._elementsCache = nil

    return self
end

--- Called when component is initialized.
---
--- !doc abstract
--- @param data ammgui.dom.inline.Node user-provided component data.
function ns.Component:onMount(data)
    error("not implemented")
end

--- Called when component is updated.
---
--- If new data causes changes in layout, `onUpdate` handler should set `outdated`
--- to `true` to make sure that its layout is properly recalculated.
---
--- !doc abstract
--- @param data ammgui.dom.inline.Node user-provided component data.
function ns.Component:onUpdate(data)
    error("not implemented")
end

--- Split this node into an array of render-able elements.
---
--- @return ammgui.component.inline.Element[]
function ns.Component:getElements()
    error("not implemented")
end

--- Get or recalculate cached result of `getElements`.
---
--- Calling this function will reset `outdated` status.
---
--- @return ammgui.component.inline.Element[]
function ns.Component:getCachedElements()
    if self.outdated or not self._elementsCache then
        self._elementsCache = self:getElements()
        self.outdated = false
    end
    return self._elementsCache
end

--- Sync one DOM node with its component.
---
--- @param component ammgui.component.inline.Component? component that was updated.
--- @param node ammgui.dom.inline.Node | string
--- @return ammgui.component.inline.Component component
function ns.Component.syncOne(component, node)
    if type(node) == "string" then
        node = { node, _isInlineNode = true, _component = ns.String }
    end

    ---@diagnostic disable-next-line: invisible
    local nodeComponent = node._component

    if component and nodeComponent == component.__class then
        component:onUpdate(node)
    else
        component = nodeComponent:New(node.key)
        component:onMount(node)
    end
    return component
end

--- Sync array of DOM nodes with their components.
---
--- This function mutates array of nodes in-place.
---
--- @param components ammgui.component.inline.Component[]
--- @param nodes string | ammgui.dom.inline.Node | (string | ammgui.dom.inline.Node)[]
--- @return ammgui.component.inline.Component[] components
--- @return boolean outdated
function ns.Component.syncAll(components, nodes)
    local outdated = false

    ---@diagnostic disable-next-line: invisible
    if type(nodes) == "string" or nodes._isInlineNode then nodes = { nodes } end
    --- @cast nodes (string | ammgui.dom.inline.Node | ammgui.component.inline.Component)[]

    local componentByKey = {}
    for i, component in ipairs(components) do
        local key = component.key or i
        if componentByKey[key] then
            logger:warning(
                "multiple components with the same key %q: %s, %s",
                key, componentByKey[key], component
            )
        else
            componentByKey[key] = component
        end
    end
    for i, node in ipairs(nodes) do
        ---@diagnostic disable-next-line: invisible
        if type(node) == "string" or node._isInlineNode then
            --- @cast node string | ammgui.dom.inline.Node
            local key = node.key or i
            local component = ns.Component.syncOne(componentByKey[key], node)
            nodes[i] = component
            outdated = outdated or component.outdated
            componentByKey[key] = nil
        else
            logger:warning("not a dom node: %s", log.p(node))
        end
    end

    return nodes, outdated
end

--- A single non-breaking element of a text.
---
--- @class ammgui.component.inline.Element: ammcore.class.Base
ns.Element = class.create("Element")

--- Called to prepare for layout estimation.
---
--- This fuction primarily exists to measure string widths in batch,
--- as repeated calls to `gpu:measureText` are quite expensive.
---
--- @param gpu FINComputerGPUT2
--- @param textMeasure ammgui.component.inline.TextMeasuringService
function ns.Element:prepareLayout(gpu, textMeasure)
    -- nothing to do nere.
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
--- @param gpu FINComputerGPUT2
function ns.Element:render(gpu)
    error("not implemented")
end

--- A component for measuring text widths in batch.
---
--- @class ammgui.component.inline.TextMeasuringService: ammcore.class.Base
ns.TextMeasuringService = class.create("TextMeasuringService")

--- @generic T: ammgui.component.inline.TextMeasuringService
--- @param self T
--- @return T
function ns.TextMeasuringService:New()
    self = class.Base.New(self)

    --- @private
    --- @type ammgui.component.inline.Word[]
    self._words = {}

    return self
end

--- Request measure for a word.
---
--- @param word ammgui.component.inline.Word
function ns.TextMeasuringService:addRequest(word)
    if not word._cachedSize or not word._cachedBaseline then
        table.insert(self._words, word)
    end
end

--- Measure all words and save results.
---
--- @param gpu FINComputerGPUT2
function ns.TextMeasuringService:run(gpu)
    if #self._words == 0 then
        return
    end

    local words = {}
    local sizes = {}
    local monospaceFlags = {}

    for _, word in ipairs(self._words) do
        table.insert(words, word.word)
        table.insert(sizes, word.data.size or 12)
        table.insert(monospaceFlags, word.data.monospace or false)
    end

    -- local measured = gpu:measureTextBatch(words, sizes, monospaceFlags)
    -- local baselines = gpu:getFontBaselineBatch(sizes, monospaceFlags)

    for i = 1, #words do
        self._words[i]._cachedSize = { x = 25, y = 10 } --measured[i]
        self._words[i]._cachedBaseline = 8 --baselines[i]
    end
end

--- Implements a string component.
---
--- @class ammgui.component.inline.String: ammgui.component.inline.Component
ns.String = class.create("String", ns.Component)

--- @param data ammgui.dom.inline.StringParams
function ns.String:onMount(data)
    self.data = data
    self.text = table.concat(self.data):gsub("[\a\r\t\v\b]", "")
end

--- @param data ammgui.dom.inline.StringParams
function ns.String:onUpdate(data)
    local text = table.concat(self.data):gsub("[\a\r\t\v\b]", "")
    self.outdated = self.outdated or (
        data.size ~= self.data.size
        or data.monospace ~= self.data.monospace
        or data.nobr ~= self.data.nobr
        or data.color ~= self.data.color
        or text ~= self.text
    )
    self.text = text
    self.data = data
end

function ns.String:getElements()
    local result = {}

    if self.data.nobr then
        local spaceBefore, word, spaceAfter = self.text:gsub("%s+", " "):match("^(%s*)(.-)(%s*)$")
        if spaceBefore:len() > 0 then
            table.insert(result, ns.Word:New(" ", self.data))
        end
        if word:len() > 0 then
            table.insert(result, ns.Word:New(word, self.data))
        end
        if spaceAfter:len() > 0 then
            table.insert(result, ns.Word:New(" ", self.data))
        end
    else
        for space, word in self.text:gmatch("(%s*)([^%s-]*%-*)") do
            if space:len() > 0 then
                table.insert(result, ns.Word:New(" ", self.data))
            end
            if word:len() > 0 then
                table.insert(result, ns.Word:New(word, self.data))
            end
        end
    end

    return result
end

--- A single word or whitespace.
---
--- @class ammgui.component.inline.Word: ammgui.component.inline.Element
ns.Word = class.create("Word", ns.Element)

--- @param word string
--- @param data ammgui.dom.inline.StringParams
---
--- @generic T: ammgui.component.inline.Word
--- @param self T
--- @return T
function ns.Word:New(word, data)
    self = ns.Element.New(self)

    --- Well, it's a word. Or a single space.
    ---
    --- @type string
    self.word = word

    --- Parameters for rendering this word.
    ---
    --- @type ammgui.dom.inline.StringParams
    self.data = data

    --- @package
    --- @type Vector2D?
    self._cachedSize = nil

    --- @package
    --- @type integer?
    self._cachedBaseline = nil

    return self
end

function ns.Word:prepareLayout(gpu, textMeasure)
    textMeasure:addRequest(self)
end

function ns.Word:getWidth()
    assert(self._cachedSize)
    return self._cachedSize.x
end

function ns.Word:getHeight()
    assert(self._cachedSize)
    assert(self._cachedBaseline)
    return self._cachedSize.y + self._cachedBaseline, -self._cachedBaseline
end

function ns.Word:canSkip()
    return self.word == " "
end

function ns.Word:render(gpu)
    if not self:canSkip() then
        gpu:drawText(
         { x = 0, y = 0 },
            self.word,
            self.data.size or 12,
            self.data.color or structs.Color { r = 1, g = 1, b = 1, a = 1 },
            self.data.monospace or false
        )
    end
end

return ns
