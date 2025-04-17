local class = require "ammcore.class"
local context = require "ammgui.component.context"
local theme = require "ammgui.css.theme"
local root = require "ammgui.component.block.root"
local rule = require "ammgui.css.rule"
local log = require "ammcore.log"
local dom = require "ammgui.dom"
local defer = require "ammcore.defer"
local array = require "ammcore._util.array"
local eventManager = require "ammgui.eventManager"
local devtools     = require "ammgui.devtools"

--- Viewport and panel management.
---
--- !doctype module
--- @class ammgui.viewport
local ns = {}

local logger = log.Logger:New()

--- Base interface for a viewport.
---
--- @class ammgui.viewport.Viewport: ammcore.class.Base
ns.Viewport = class.create("Viewport")

--- Update components.
---
--- @param pos Vector2D
--- @param size Vector2D
function ns.Viewport:update(pos, size)
    error("not implemented")
end

--- Render components.
---
--- @param pos Vector2D
--- @param size Vector2D
function ns.Viewport:draw(pos, size)
    error("not implemented")
end

--- Get topmost event listener by mouse coordinates.
---
--- @param pos Vector2D
--- @return ammgui.eventManager.EventListener? topReceiver
--- @return table<ammgui.eventManager.EventListener, Vector2D> affectedReceivers
--- @return ammgui.viewport.Window? window
function ns.Viewport:getEventListener(pos)
    error("not implemented")
end

--- Style settings for a window.
---
--- @class ammgui.viewport.WindowSettings
--- @field fontSize integer? root font size.
--- @field stylesheets ammgui.css.stylesheet.Stylesheet[]? stylesheets used in this window.
--- @field themeStylesheet ammgui.css.theme.Theme? theme stylesheet used in this window.

--- Viewport that displays GUI.
---
--- @class ammgui.viewport.Window: ammgui.viewport.Viewport
ns.Window = class.create("Window")

--- @param gpu FINComputerGPUT2
--- @param page fun(data): ammgui.dom.block.Node
--- @param data unknown
--- @param settings ammgui.viewport.WindowSettings
--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui.viewport.Window
--- @param self T
--- @return T
function ns.Window:New(
    gpu,
    page,
    data,
    settings,
    earlyRefreshEvent
)
    self = ns.Viewport.New(self)

    --- @private
    --- @type FINComputerGPUT2
    self._gpu = gpu

    --- @private
    --- @type fun(data): ammgui.dom.block.Node
    self._page = page

    --- @private
    --- @type unknown
    self._data = data

    --- @private
    --- @type boolean
    self._hasNewData = true

    --- @private
    --- @type integer
    self._fontSize = settings.fontSize or 12

    --- @private
    --- @type ammgui.css.stylesheet.Stylesheet[]
    self._stylesheets = settings.stylesheets or {}

    local themeStylesheet = settings.themeStylesheet or theme.DEFAULT
    table.insert(self._stylesheets, themeStylesheet)

    --- @private
    --- @type table<string, Color | string>
    self._theme = themeStylesheet.theme

    --- @private
    --- @type ammcore.promise.Event
    self._earlyRefreshEvent = earlyRefreshEvent

    --- @private
    --- @type table<string, number>
    self._units = {
        ["Q"] = 3 / 4,
        ["mm"] = 3,
        ["cm"] = 30,
        ["m"] = 300,
        ["in"] = 76.2,
        ["rem"] = 726 / 400 * self._fontSize,
        ["pc"] = 726 / 400 * 12,
        ["pt"] = 726 / 400,
    }

    --- @private
    --- @type ammgui.component.block.root.Root
    self._root = root.Root:New(nil)

    --- @private
    --- @type ammgui.dom.DivNode?
    self._rootNode = nil

    --- @private
    --- @type ammgui.component.context.RenderingContext
    self._context = context.RenderingContext:New(self._gpu, self._earlyRefreshEvent)

    --- @private
    --- @type ammgui.devtools.Element?
    self._devtoolsRepr = nil

    self:_compileRules()
    self:_refreshRoot()
    self._root:onMount(self._context, self._rootNode)

    return self
end

function ns.Window:_compileRules()
    --- @private
    --- @type { selector: ammgui.css.selector.Selector, rule: ammgui.css.rule.CompiledRule }[]
    self._rules = {}

    local i = 0
    for _, style in ipairs(self._stylesheets) do
        for _, r in ipairs(style.rules) do
            i = i + 1
            local compiled = rule.compile(r, style.layer, i)
            for _, selector in ipairs(compiled.compiledSelectors) do
                table.insert(self._rules, { selector = selector, rule = compiled })
            end
        end
    end
    table.sort(self._rules, function(a, b) return a.selector < b.selector end)
    logger:trace("Compiled %s CSS selectors", #self._rules)
end

--- Set new data for the page function and update GUI.
function ns.Window:setData(data)
    self._data = data
    self._hasNewData = true
    self._earlyRefreshEvent:set()
end

--- @param pos Vector2D
--- @param size Vector2D
function ns.Window:update(pos, size)
    local sizeOutdated = self._size ~= size

    self._size = size
    self._pos = pos

    if sizeOutdated then
        self._units["vw"] = size.x / 100
        self._units["vh"] = size.y / 100
        self._units["vmin"] = math.min(size.x, size.y) / 100
        self._units["vmax"] = math.max(size.x, size.y) / 100
    end

    self:_refreshRoot()
    self._root:onUpdate(self._context, self._rootNode)

    if sizeOutdated or self._root.outdatedCss then
        logger:trace("Dispatch css update")
        self._root:updateCss(
            context.CssContext:New(self._rules, self._theme, self._units, sizeOutdated)
        )

        self._devtoolsRepr = nil
    end

    if sizeOutdated or self._root.outdated then
        logger:trace("Dispatch layout update")

        local tms = context.TextMeasure:New()
        self._root:prepareLayout(tms)
        tms:run(self._gpu)

        self._root:getLayout(size.x, size.y)

        self._devtoolsRepr = nil
    end
end

function ns.Window:draw(pos, size)
    self._context.gpu:pushLayout(pos, size, 1)
    self._context:reset(size)
    self._root:draw(self._context)
    self._context:finalize()
    self._context.gpu:popGeometry()
end

function ns.Window:getDevtoolsData()
    if not self._devtoolsRepr then
        self._devtoolsRepr = self._root:repr()
    end
    return self._devtoolsRepr
end

function ns.Window:_refreshRoot()
    if self._hasNewData then
        self._hasNewData = false

        local ok, err = defer.xpcall(function()
            self._rootNode = dom.div { self._page(self._data) }
        end)

        if not ok then
            logger:error("Error in page function: %s\n%s", err.message, err.trace)
            self._rootNode = dom.div {}
        end
    end
end

--- Get topmost event listener by mouse coordinates.
---
--- @param pos Vector2D
--- @return ammgui.eventManager.EventListener? topReceiver
--- @return table<ammgui.eventManager.EventListener, Vector2D> affectedReceivers
--- @return ammgui.viewport.Window? window
function ns.Window:getEventListener(pos)
    local firstReceiver, receivers = self._context:getEventListener(pos - self._pos)
    return firstReceiver, receivers, self
end

--- Window that displays devtools panel.
---
--- @class ammgui.viewport.Devtools: ammgui.viewport.Window
ns.Devtools = class.create("Devtools", ns.Window)

--- @param gpu FINComputerGPUT2
--- @param target ammgui.viewport.Window
--- @param settings ammgui.viewport.WindowSettings
--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui.viewport.Devtools
--- @param self T
--- @return T
function ns.Devtools:New(gpu, target, settings, earlyRefreshEvent)
    self = ns.Window.New(
        self,
        gpu,
        devtools.panel,
        { root = target:getDevtoolsData() },
        settings,
        earlyRefreshEvent
    )

    --- @type ammgui.viewport.Window
    self.target = target

    --- @private
    --- @type ammgui.devtools.Element
    self._oldDevtoolsData = target:getDevtoolsData()

    return self
end

function ns.Devtools:update(pos, size)
    -- Do nothing; we'll update during the draw call.
end

function ns.Devtools:draw(pos, size)
    local newData = self.target:getDevtoolsData()
    if newData ~= self._oldDevtoolsData then
        self._oldDevtoolsData = newData
        self:setData({ root = newData })
    end

    ns.Window.update(self, pos, size)
    ns.Window.draw(self, pos, size)
end

--- Scroll bar drag handle.
---
--- @class ammgui.vewport.SplitHandleEventListener: ammgui.eventManager.EventListener
local SplitHandleEventListener = class.create("SplitHandleEventListener", eventManager.EventListener)

--- @param view ammgui.viewport.Split
--- @param index integer
---
--- !doctype classmethod
--- @generic T: ammgui.vewport.SplitHandleEventListener
--- @param self T
--- @return T
function SplitHandleEventListener:New(view, index)
    self = eventManager.EventListener.New(self)

    --- @package
    --- @type boolean
    self._isActive = true

    --- @private
    --- @type ammgui.viewport.Split
    self._view = view

    --- @private
    --- @type integer
    self._index = index

    --- @private
    --- @type integer
    self._lastClick = 0

    return self
end

function SplitHandleEventListener:isActive()
    return self._isActive
end

function SplitHandleEventListener:isDraggable()
    return true
end

function SplitHandleEventListener:onMouseEnter(pos, origin, modifiers)
    self._view._hover = true
    self._view._hoverIndex = self._index
end

function SplitHandleEventListener:onMouseExit(pos, origin, modifiers)
    self._view._hover = false
end

function SplitHandleEventListener:onClick(pos, modifiers, propagate)
    local now = computer.millis()
    if now - self._lastClick < 500 then
        local totalProportion = self._view._proportions[self._index] + self._view._proportions[self._index + 1]
        self._view._proportions[self._index + 1] = totalProportion / 4
        self._view._proportions[self._index] = totalProportion - self._view._proportions[self._index + 1]
    end
    self._lastClick = now

    return false
end

function SplitHandleEventListener:onDragStart(pos, origin, modifiers, target)
    self._view._drag = true
    self._view._dragIndex = self._index

    self.initialPos = self._view._positions[self._index + 1]

    return self:onDrag(pos, origin, modifiers, target)
end

function SplitHandleEventListener:onDrag(pos, origin, modifiers, target)
    local dragPos = (self.initialPos + pos - origin)[self._view._mainDirection]
    self._view._dragPos = math.max(
        self._view._positions[self._index][self._view._mainDirection] + 20,
        math.min(
            dragPos,
            self._view._positions[self._index + 2][self._view._mainDirection] - 20
        )
    )
    return "none" -- Don't highlight drop zones.
end

function SplitHandleEventListener:onDragEnd(pos, origin, modifiers, target)
    self:onDrag(pos, origin, modifiers, target)

    local newPos = math.max(
        self._view._positions[self._index][self._view._mainDirection],
        math.min(
            self._view._dragPos,
            self._view._positions[self._index + 2][self._view._mainDirection]
        )
    )

    local mainSize = math.max(0, self._view._size[self._view._mainDirection] - self._view._gap * math.max(0, #self._view.items - 1))

    local width1 = newPos - self._view._gap - self._view._positions[self._index][self._view._mainDirection]
    local scale1 = width1 / mainSize
    self._view._proportions[self._index] = scale1

    local width2 = self._view._positions[self._index + 2][self._view._mainDirection] - self._view._gap - newPos
    local scale2 = width2 / mainSize
    self._view._proportions[self._index + 1] = scale2

    self._view._drag = false
end

--- A viewport that splits screen in two.
---
--- @class ammgui.viewport.Split: ammgui.viewport.Viewport
ns.Split = class.create("Split", ns.Viewport)

--- @param direction "row"|"column"
--- @param items ammgui.viewport.Viewport[]
---
--- !doctype classmethod
--- @generic T: ammgui.viewport.Split
--- @param self T
--- @return T
function ns.Split:New(direction, items, context)
    self = ns.Viewport.New(self)

    --- Split direction.
    ---
    --- @type "row"|"column"
    self.direction = direction

    --- Nested viewports.
    ---
    --- @type ammgui.viewport.Viewport[]
    self.items = items

    --- @private
    --- @type ammgui.component.context.RenderingContext
    self._context = context

    --- @private
    --- @type "row"|"column"
    self._prevDirection = direction

    --- @package
    --- @type "x"|"y"
    self._mainDirection = direction == "row" and "x" or "y"

    --- @package
    --- @type "x"|"y"
    self._crossDirection = direction == "row" and "y" or "x"

    --- @package
    --- @type number[]
    self._proportions = {}

    --- @package
    --- @type number
    self._gap = 5

    --- @package
    --- @type boolean
    self._hover = false

    --- @package
    --- @type integer
    self._hoverIndex = 0

    --- @package
    --- @type boolean
    self._drag = false

    --- @package
    --- @type number
    self._dragPos = 0

    --- @package
    --- @type integer
    self._dragIndex = 0

    --- @package
    --- @type Vector2D[]
    self._positions = {}

    --- @private
    --- @type ammgui.vewport.SplitHandleEventListener[]
    self._handles = {}

    return self
end

function ns.Split:update(pos, size)
    --- @package
    self._size = size

    if self._prevDirection ~= self.direction then
        self._prevDirection = self.direction
        self._mainDirection = self.direction == "row" and "x" or "y"
        self._crossDirection = self.direction == "row" and "y" or "x"
        self._proportions = {}
    end

    if #self._proportions > #self.items then
        for i = #self.items + 1, #self._proportions do
            self._proportions[i] = nil
            self._handles[i]._isActive = false
            self._handles[i] = nil
        end
        local factor = 1 - array.sum(self._proportions)
        for i, v in ipairs(self._proportions) do
            self._proportions[i] = factor * v
        end
    elseif #self._proportions < #self.items then
        for i, v in ipairs(self._proportions) do
            self._proportions[i] = 3 * v / 4
        end
        local factor = (1 - array.sum(self._proportions)) / (#self.items - #self._proportions)
        for i = #self._proportions + 1, #self.items do
            table.insert(self._proportions, factor)
            table.insert(self._handles, SplitHandleEventListener:New(self, i))
        end
    end

    local mainSize = math.max(0, size[self._mainDirection] - self._gap * math.max(0, #self.items - 1))
    local crossSize = size[self._crossDirection]
    for i, item in ipairs(self.items) do
        local viewMainSize = mainSize * self._proportions[i]
        item:update(
            pos,
            structs.Vector2D {
                [self._mainDirection] = viewMainSize,
                [self._crossDirection] = crossSize,
            }
        )
        pos = pos + structs.Vector2D { [self._mainDirection] = viewMainSize + self._gap }
    end
end

function ns.Split:draw(pos, size)
    local mainSize = math.max(0, size[self._mainDirection] - self._gap * math.max(0, #self.items - 1))
    local crossSize = size[self._crossDirection]

    self._positions = { pos }

    for i, item in ipairs(self.items) do
        local viewMainSize = mainSize * self._proportions[i]

        item:draw(
            pos,
            structs.Vector2D {
                [self._mainDirection] = viewMainSize,
                [self._crossDirection] = crossSize,
            }
        )

        pos = pos + structs.Vector2D {
            [self._mainDirection] = viewMainSize,
            [self._crossDirection] = 0,
        }

        if i < #self.items then
            self:_addSeparator(i, pos, size)
        end

        pos = pos + structs.Vector2D {
            [self._mainDirection] = self._gap,
            [self._crossDirection] = 0,
        }

        table.insert(self._positions, pos)
    end

    if self._drag then
        self._context.gpu:drawRect(
            structs.Vector2D {
                [self._mainDirection] = self._dragPos - self._gap,
                [self._crossDirection] = pos[self._crossDirection],
            },
            structs.Vector2D {
                [self._mainDirection] = self._gap,
                [self._crossDirection] = size[self._crossDirection],
            },
            structs.Color { 1, 1, 1, 0.3 },
            "",
            0
        )
    end
end

function ns.Split:getEventListener(pos)
    for i = 2, #self._positions do
        if pos[self._mainDirection] < self._positions[i][self._mainDirection] then
            return self.items[i - 1]:getEventListener(pos)
        end
    end
end

--- @param i integer
--- @param pos Vector2D
--- @param size Vector2D
function ns.Split:_addSeparator(i, pos, size)
    local color = (i == self._hoverIndex and self._hover and not self._drag)
        and structs.Color { 0.3, 0.3, 0.3, 1 }
        or structs.Color { 0.1, 0.1, 0.1, 1 }

    local size = structs.Vector2D {
        [self._mainDirection] = self._gap,
        [self._crossDirection] = size[self._crossDirection],
    }

    self._context.gpu:drawRect(pos, size, color, "", 0)
    self._context:pushEventListener(pos, size, self._handles[i])
end

return ns
