local class = require "ammcore.class"
local log = require "ammcore.log"
local inlineComponent = require "ammgui.component.inline"

--- Components that implement block DOM nodes.
---
--- !doctype module
--- @class ammgui.component.block
local ns = {}

local logger = log.Logger:New()

--- Base for all block components.
---
--- @class ammgui.component.block.Component: ammcore.class.Base
ns.Component = class.create("Component")

--- @generic T: ammgui.component.block.Component
--- @param self T
--- @return T
function ns.Component:New(key)
    self = class.Base.New(self)

    --- Key for synchronizing arrays of nodes.
    ---
    --- @type integer | string | nil
    self.key = key

    --- Indicates that this component's state has changed,
    --- and it needs a layout recalculation.
    ---
    --- New components are always created as `outdated`.
    ---
    --- @type boolean
    self.outdated = true

    --- Resolved CSS rules.
    ---
    --- @type ammgui.css.rule.Resolved
    self.css = nil

    --- Set of CSS classes on this component.
    ---
    --- @private
    --- @type table<string, true>
    self._classes = {}

    --- Set of CSS pseudoclasses on this component.
    ---
    --- @private
    --- @type table<string, true>
    self._pseudo = {}

    return self
end

--- Called when component is initialized.
---
--- !doc abstract
--- @param data ammgui.dom.block.Node user-provided component data.
function ns.Component:onMount(data)
    error("not implemented")
end

--- Called when component is updated.
---
--- If new data causes changes in layout, `onUpdate` handler should set `outdated`
--- to `true` to make sure that its layout is properly recalculated.
---
--- !doc abstract
--- @param data ammgui.dom.block.Node user-provided component data.
function ns.Component:onUpdate(data)
    error("not implemented")
end

--- Called to prepare for layout estimation.
---
--- This fuction primarily exists to measure string widths in batch,
--- as repeated calls to `gpu:measureText` are quite expensive.
---
--- @param gpu FINComputerGPUT2
--- @param textMeasure ammgui.component.inline.TextMeasuringService
function ns.Component:prepareLayout(gpu, textMeasure)
    error("not implemented")
end

--- Called to estimate component's intrinsic dimensions.
---
--- This function is called when container needs to estimate component's dimensions
--- in order to pack all of its contents.
---
--- It should return dimensioins calculated for two cases:
---
--- - ``max-content``: maximum width that the content can take, i.e. width
---   of the container if nothing wraps;
--- - ``min-content``: minimum width that the content can take, i.e. width
---   of the container if every wrapping opportunity is taken.
---
--- !doc abstract
--- @param gpu FINComputerGPUT2
--- @return Vector2D minContentSize component size in min-content mode.
--- @return Vector2D maxContentSize component size in max-content mode.
function ns.Component:calculateIntrinsicLayout(gpu)
    error("not implemented")
end

--- Called to finalize component's layout.
---
--- !doc abstract
--- @param gpu FINComputerGPUT2
--- @param frameSize Vector2D available frame size for the widget to fit into.
--- @return Vector2D actial widget size.
function ns.Component:calculateLayout(gpu, frameSize)
    error("not implemented")
end

--- Called to draw the component on screen.
---
--- Width and height are guaranteed to be same as were used with
--- the latest `calculateLayout` call.
---
--- !doc abstract
--- @param gpu FINComputerGPUT2
function ns.Component:draw(gpu)
    error("not implemented")
end

--- Sync one DOM node with its component.
---
--- @param component ammgui.component.block.Component? component that was updated.
--- @param node ammgui.dom.block.Node
--- @return ammgui.component.block.Component component
function ns.Component.syncOne(component, node)
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
--- @param components ammgui.component.block.Component[]
--- @param nodes ammgui.dom.block.Node | ammgui.dom.block.Node[]
--- @return ammgui.component.block.Component[] components
--- @return boolean outdated
function ns.Component.syncAll(components, nodes)
    local outdated = false

    ---@diagnostic disable-next-line: invisible
    if nodes._isBlockNode then nodes = { nodes } end
    --- @cast nodes (ammgui.dom.block.Node | ammgui.component.block.Component)[]

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
        if node._isBlockNode then
            --- @cast node ammgui.dom.block.Node
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

--- Component that holds text.
---
--- @class ammgui.component.block.TextContainer: ammgui.component.block.Component
ns.TextContainer = class.create("TextContainer", ns.Component)

--- @param data ammgui.dom.block.PParams
function ns.TextContainer:onMount(data)
    --- @private
    --- @type ammgui.component.inline.Component[]
    self._text = inlineComponent.Component.syncAll({}, data)
end

--- @param data ammgui.dom.block.PParams
function ns.TextContainer:onUpdate(data)
    local text, outdated = inlineComponent.Component.syncAll(self._text, data)
    self._text = text
    self.outdated = self.outdated or outdated
end

function ns.TextContainer:prepareLayout(gpu, textMeasure)
    self._baseWord = icom.Word:New(" ", { size = 12, })
    self._baseWord:prepareLayout(gpu, textMeasure)
    self._elements = self:_makeElements()
    for _, element in ipairs(self._elements) do
        element:prepareLayout(gpu, textMeasure)
    end
end

function ns.TextContainer:calculateIntrinsicLayout(gpu)
    local totalWidth, maxWidth = 0, 0
    local totalHeight, maxHeightA = 0, 0
    local baseHeightA, baseHeightB = self._baseWord:getHeight()

    for _, element in ipairs(self._elements) do
        local width = element:getWidth()
        local heightA, heightB = element:getHeight()

        totalWidth = totalWidth + width
        maxHeightA = math.max(maxHeightA, heightA)

        if not element:canSkip() then
            maxWidth = math.max(maxWidth, width)
            totalHeight = totalHeight + math.max(baseHeightA, heightA) + baseHeightB
        end
    end
    return
        { x = maxWidth, y = totalHeight },
        { x = totalWidth, y = maxHeightA + baseHeightB }
end

function ns.TextContainer:calculateLayout(gpu, frameSize)
    --- @type { [integer]: ammgui.component.inline.Element, width: number, heightA: number, heightB: number }[]
    self._lines = {}
    local maxLineWidth, totalHeight = 0, 0

    --- @type { [integer]: ammgui.component.inline.Element, width: number, heightA: number, heightB: number }
    local line = {}
    local lineWidth = 0

    local function pushLine()
        local lineHeightA, lineHeightB = self._baseWord:getHeight()
        for _, element in ipairs(line) do
            local heightA = element:getHeight()
            lineHeightA = math.max(lineHeightA, heightA)
        end
        line.width = lineWidth
        line.heightA = lineHeightA
        line.heightB = lineHeightB
        table.insert(self._lines, line)
        maxLineWidth = math.max(maxLineWidth, lineWidth)
        totalHeight = totalHeight + lineHeightA + lineHeightB
    end

    for _, element in ipairs(self._elements) do
        local width = element:getWidth()
        if lineWidth + width > frameSize.x then
            -- This line is full, start a new one.
            while #line > 0 and line[#line]:canSkip() do
                -- Clean up spaces at the end of the line.
                lineWidth = lineWidth - table.remove(line):getWidth()
            end
            if #line > 0 then
                pushLine()
            end
            if element:canSkip() then
                lineWidth = 0
                line = {}
            else
                lineWidth = width
                line = { element }
            end
        else
            table.insert(line, element)
            lineWidth = lineWidth + width
        end
    end

    if #line > 0 then
        pushLine()
    end

    return { x = maxLineWidth, y = totalHeight }
end

--- @param gpu FINComputerGPUT2
function ns.TextContainer:draw(gpu)
    local x, y = 0, 0
    for _, line in ipairs(self._lines) do
        gpu:drawLines(
            {
                { x = 0, y = y + line.heightA },
                { x = 2000, y = y + line.heightA },
            },
            1,
            structs.Color { r = 1, g = 0.5, b = 0.5, a = 0.1 }
        )
        for _, element in ipairs(line) do
            local width = element:getWidth()
            local heightA, heightB = element:getHeight()
            gpu:pushLayout(
                { x = x, y = y + line.heightA - heightA },
                { x = width, y = heightA + heightB },
                1
            )
            element:render(gpu)
            gpu:popGeometry()
            x = x + element:getWidth()
        end
        x = 0
        y = y + line.heightA + line.heightB
    end
end

--- @private
--- @return ammgui.component.inline.Element[]
function ns.TextContainer:_makeElements()
    local elements = {}
    local lastIsSpace = false
    for _, component in ipairs(self._text) do
        for _, element in ipairs(component:getCachedElements()) do
            local isSpace = element:canSkip()
            if not isSpace or (isSpace and not lastIsSpace) then
                table.insert(elements, element)
            end
            lastIsSpace = isSpace
        end
    end
    return elements
end

return ns
