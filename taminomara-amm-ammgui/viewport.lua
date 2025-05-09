local class = require "ammcore.class"
local theme = require "ammgui.css.theme"
local log = require "ammcore.log"
local fun = require "ammcore.fun"
local eventListener = require "ammgui._impl.eventListener"
local devtools = require "ammgui._impl.devtools"
local render = require "ammgui._impl.context.render"
local root = require "ammgui._impl.component.root"
local sync = require "ammgui._impl.context.sync"
local css = require "ammgui._impl.context.css"
local resolved = require "ammgui._impl.css.resolved"
local tracy = require "ammcore.tracy"
local textMeasure = require "ammgui._impl.context.textMeasure"
local node = require "ammgui._impl.component.node"

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
--- @param pos ammgui.Vec2
--- @param size ammgui.Vec2
function ns.Viewport:update(pos, size)
    error("not implemented")
end

--- Render components.
---
--- @param pos ammgui.Vec2
--- @param size ammgui.Vec2
function ns.Viewport:draw(pos, size)
    error("not implemented")
end

--- Get topmost event listener by mouse coordinates.
---
--- @param pos ammgui.Vec2
--- @return ammgui._impl.eventListener.EventListener? topReceiver
--- @return table<ammgui._impl.eventListener.EventListener, ammgui.Vec2> affectedReceivers
--- @return ammgui.viewport.Window? window
function ns.Viewport:getEventListener(pos)
    error("not implemented")
end

--- Event listener for selecting elements in devtools.
---
--- @class ammgui.viewport.DevtoolsHighlightEventListener: ammgui._impl.eventListener.EventListener
DevtoolsHighlightEventListener = class.create("DevtoolsHighlightEventListener", eventListener.EventListener)

--- @param target ammgui.viewport.Window
---
--- !doctype classmethod
--- @generic T: ammgui.viewport.DevtoolsHighlightEventListener
--- @param self T
--- @return T
function DevtoolsHighlightEventListener:New(target)
    self = eventListener.EventListener.New(self)

    --- Target window.
    ---
    --- @type ammgui.viewport.Window
    self.target = target

    --- @private
    --- @type ammgui._impl.id.EventListenerId?
    self._highlightedId = nil

    return self
end

function DevtoolsHighlightEventListener:onMouseEnter(pos, modifiers)
    self:onMouseMove(pos, modifiers, true)
end

function DevtoolsHighlightEventListener:onMouseMove(pos, modifiers, propagate)
    if propagate then
        local targetElement = self.target._context:getEventListener(pos)
        while targetElement do
            if class.isChildOf(targetElement, node.Node) then
                --- @cast targetElement ammgui._impl.component.node.Node
                self._highlightedId = targetElement.id
                self.target:setHighlighted(
                    targetElement.id,
                    true,
                    true,
                    true,
                    true
                )
                self.target:setPreSelectedId(targetElement.id)
                break
            end
            targetElement = targetElement.parent
        end
    end
    return propagate
end

function DevtoolsHighlightEventListener:onMouseExit(pos, modifiers)
    self.target:setHighlighted(nil)
    self.target:setPreSelectedId(nil)
end

function DevtoolsHighlightEventListener:onClick(pos, modifiers, propagate)
    propagate = self:onMouseMove(pos, modifiers, propagate)
    if propagate then
        self.target:setSelectedId(self._highlightedId)
        self._highlightedId = nil
        self.target:setSelectionEnabled(false)
    end
    return propagate
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

--- @param name string
--- @param gpu FINComputerGPUT2
--- @param page fun(data): ammgui.dom.AnyNode
--- @param data unknown
--- @param settings ammgui.viewport.WindowSettings
--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui.viewport.Window
--- @param self T
--- @return T
function ns.Window:New(
    name,
    gpu,
    page,
    data,
    settings,
    earlyRefreshEvent
)
    self = ns.Viewport.New(self)

    --- Window name, used for debugging.
    ---
    --- @type string
    self.name = name

    --- @private
    --- @type FINComputerGPUT2
    self._gpu = gpu

    --- @private
    --- @type fun(data): ammgui.dom.AnyNode
    self._page = page

    --- @private
    --- @type unknown
    self._data = data

    --- @private
    --- @type integer
    self._fontSize = settings.fontSize or 12

    --- @private
    --- @type ammgui.css.stylesheet.Stylesheet[]
    self._stylesheets = settings.stylesheets or {}

    local themeStylesheet = settings.themeStylesheet or theme.DEFAULT
    table.insert(self._stylesheets, themeStylesheet)
    table.insert(self._stylesheets, theme.SYSTEM)

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
    --- @type ammgui._impl.component.root.Root
    self._root = root.Root:New()

    --- @private
    --- @type ammgui.dom.Node?
    self._rootNode = nil

    --- @package
    --- @type ammgui._impl.context.render.Context
    self._context = render.Context:New(self._gpu, self._earlyRefreshEvent)

    --- @private
    --- @type ammgui.viewport.DevtoolsHighlightEventListener
    self._devtoolsHighlighter = DevtoolsHighlightEventListener:New(self)

    --- @private
    --- @type boolean
    self._devtoolsHighlighterActive = false

    --- @private
    --- @type ammgui._impl.devtools.Element?
    self._devtoolsRepr = nil

    --- @private
    --- @type ammgui._impl.id.EventListenerId?
    self._devtoolsHighlightedId = nil

    --- @private
    --- @type [boolean, boolean, boolean, boolean]?
    self._devtoolsHighlightedParams = nil

    --- @private
    --- @type ammgui._impl.id.EventListenerId?
    self._devtoolsSelectedId = nil

    --- @private
    --- @type ammgui._impl.id.EventListenerId?
    self._devtoolsPreSelectedId = nil

    self:_compileRules()

    self._root:onMount(
        sync.Context:New(self._earlyRefreshEvent),
        self._page(self._data)
    )

    return self
end

function ns.Window:_compileRules()
    --- @private
    --- @type { selector: ammgui.css.selector.Selector, rule: ammgui._impl.css.resolved.CompiledRule }[]
    self._rules = {}

    local i = 0
    for _, style in ipairs(self._stylesheets) do
        for _, r in ipairs(style.rules) do
            i = i + 1
            local compiled = resolved.compile(r, style.layer, i)
            for _, selector in ipairs(compiled.compiledSelectors) do
                table.insert(self._rules, { selector = selector, rule = compiled })
            end
        end
    end
    table.sort(self._rules, function(a, b) return a.selector < b.selector end)
    logger:trace("Compiled %s CSS selectors", #self._rules)
end

--- Set new data for the page function and update GUI.
---
--- @param data any
function ns.Window:setData(data)
    self._data = data
    self._earlyRefreshEvent:set()
end

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

    do
        local _ <close> = tracy.zoneScopedN("AmmGui/Window/Sync")
        tracy.zoneNameF("AmmGui/Window/Sync | %q", self.name)

        self._root:onUpdate(
            sync.Context:New(self._earlyRefreshEvent),
            self._page(self._data)
        )
    end

    do
        local _ <close> = tracy.zoneScopedN("AmmGui/Window/UpdateLayout")
        tracy.zoneNameF("AmmGui/Window/UpdateLayout | %q", self.name)

        if sizeOutdated or self._root.cssOutdated then
            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Impl/Css")
                self._root:syncCss(
                    css.Context:New(self._rules, self._theme, self._units, sizeOutdated)
                )
            end

            self._devtoolsRepr = nil
        end

        if self._root.layoutOutdated then
            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Impl/ResetLayout")
                self._root:updateLayoutTree()
            end

            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Impl/PrepareLayout")
                local tms = textMeasure.TextMeasure:New()
                self._root.layout:prepareLayout(tms)
                do
                    local _ <close> = tracy.zoneScopedN("AmmGui/Impl/PrepareLayout/TmsRun")
                    tms:run(self._gpu)
                end
            end

            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Impl/CalculateLayout")
                self._root.layout:asBlock():getLayout(size.x, size.y)
            end

            self._devtoolsRepr = nil
        else
            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Impl/ResetLayout")
                self._root:updateLayoutTree()
            end
        end
    end
end

function ns.Window:draw(pos, size)
    do
        local _ <close> = tracy.zoneScopedN("AmmGui/Window/Draw")
        tracy.zoneNameF("AmmGui/Window/Draw | %q", self.name)

        self._context.gpu:pushClipRect(pos, size)
        self._context.gpu:pushLayout(pos, size, 1)
        self._context:reset(size, self._devtoolsHighlightedId, self._devtoolsHighlightedParams)

        do
            local _ <close> = tracy.zoneScopedN("AmmGui/Impl/Draw")
            self._root.layout:asBlock():draw(self._context)
        end

        self._context:finalize()
        self._context.gpu:popGeometry()
        self._context.gpu:popClip()
    end
end

--- Get root element's representation for devtools panel.
---
--- @return ammgui._impl.devtools.Element?
function ns.Window:getDevtoolsData()
    if not self._devtoolsRepr then
        self._devtoolsRepr = self._root:devtoolsRepr()
    end
    return self._devtoolsRepr
end

--- Set ID of a component that should be have its debug overlay displayed.
---
--- @param id ammgui._impl.id.EventListenerId?
--- @param drawContent boolean?
--- @param drawPadding boolean?
--- @param drawOutline boolean?
--- @param drawMargin boolean?
function ns.Window:setHighlighted(id, drawContent, drawPadding, drawOutline, drawMargin)
    self._devtoolsHighlightedId = id
    self._devtoolsHighlightedParams = { drawContent, drawPadding, drawOutline, drawMargin }
end

--- Set flag that enables selecting elements for debug overlay.
---
--- @param enabled boolean
function ns.Window:setSelectionEnabled(enabled)
    self._devtoolsHighlighterActive = enabled
    if not enabled then
        self:setHighlighted(nil)
        self:setPreSelectedId(nil)
    end
end

--- Get flag that enables selecting elements for debug overlay.
---
--- @return boolean enabled
function ns.Window:getSelectionEnabled()
    return self._devtoolsHighlighterActive
end

--- Set ID of a component that should be selected in a debug window
--- attached to this window.
---
--- @param id ammgui._impl.id.EventListenerId?
function ns.Window:setSelectedId(id)
    self._devtoolsSelectedId = id
end

--- Get ID of a component that should be selected in a debug window
--- attached to this window.
---
--- @return ammgui._impl.id.EventListenerId? id
function ns.Window:getSelectedId()
    return self._devtoolsSelectedId
end

--- Get ID of a component that should be pre-selected in a debug window
--- attached to this window.
---
--- @return ammgui._impl.id.EventListenerId? id
function ns.Window:setPreSelectedId(id)
    self._devtoolsPreSelectedId = id
end

--- Get ID of a component that should be pre-selected in a debug window
--- attached to this window.
---
--- @return ammgui._impl.id.EventListenerId? id
function ns.Window:getPreSelectedId()
    return self._devtoolsPreSelectedId
end

--- Get topmost event listener by mouse coordinates.
---
--- @param pos ammgui.Vec2
--- @return ammgui._impl.eventListener.EventListener? topReceiver
--- @return table<ammgui._impl.eventListener.EventListener, ammgui.Vec2> affectedReceivers
--- @return ammgui.viewport.Window? window
function ns.Window:getEventListener(pos)
    if self._devtoolsHighlighterActive then
        if
            self._pos.x <= pos.x and pos.x < self._pos.x + self._size.x
            and self._pos.y <= pos.y and pos.y < self._pos.y + self._size.y
        then
            return
                self._devtoolsHighlighter,
                { [self._devtoolsHighlighter] = self._pos }, self
        else
            return nil, {}, self
        end
    else
        local firstReceiver, receivers = self._context:getEventListener(pos - self._pos)
        return firstReceiver, receivers, self
    end
end

--- Window that displays devtools panel.
---
--- @class ammgui.viewport.Devtools: ammgui.viewport.Window
ns.Devtools = class.create("Devtools", ns.Window)

--- @param name string
--- @param gpu FINComputerGPUT2
--- @param target ammgui.viewport.Window?
--- @param settings ammgui.viewport.WindowSettings
--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui.viewport.Devtools
--- @param self T
--- @return T
function ns.Devtools:New(name, gpu, target, settings, earlyRefreshEvent)
    self = ns.Window.New(
        self,
        name,
        gpu,
        devtools.panel,
        {},
        settings,
        earlyRefreshEvent
    )

    --- @private
    --- @type ammgui.viewport.Window?
    self._target = target

    --- @private
    --- @type ammgui._impl.devtools.Element?
    self._oldDevtoolsData = nil

    --- @private
    --- @type ammgui._impl.id.EventListenerId?
    self._oldSelectedId = nil

    --- @private
    --- @type ammgui._impl.id.EventListenerId?
    self._oldPreSelectedId = nil

    --- @private
    --- @type boolean?
    self._oldSelectionEnabled = nil

    return self
end

--- Set new target for devtools window.
---
--- @param target ammgui.viewport.Window?
function ns.Devtools:setTarget(target)
    if self._target then
        self._target:setSelectionEnabled(false)
        self._target:setSelectedId(nil)
        self._target:setPreSelectedId(nil)
        self._target:setHighlighted(nil)
    end
    self._target = target
end

function ns.Devtools:update(pos, size)
    -- Do nothing; we'll update during the draw call.
end

function ns.Devtools:draw(pos, size)
    local newDevtoolsData = self._target and self._target:getDevtoolsData()
    local newSelectedId = self._target and self._target:getSelectedId()
    local newPreSelectedId = self._target and self._target:getPreSelectedId()
    local newSelectionEnabled = self._target and self._target:getSelectionEnabled()

    if
        newDevtoolsData ~= self._oldDevtoolsData
        or newSelectedId ~= self._oldSelectedId
        or newPreSelectedId ~= self._oldPreSelectedId
        or newSelectionEnabled ~= self._oldSelectionEnabled
    then
        self._oldDevtoolsData = newDevtoolsData
        self._oldSelectedId = newSelectedId
        self._oldPreSelectedId = newPreSelectedId
        self._oldSelectionEnabled = newSelectionEnabled
        self:setData({
            root = newDevtoolsData,
            selectedId = newSelectedId,
            preSelectedId = newPreSelectedId,
            selectionEnabled = newSelectionEnabled,
            setSelectionEnabled = function(...)
                if self._target then
                    self._target:setSelectionEnabled(...)
                end
            end,
            setSelectedId = function(...)
                if self._target then
                    self._target:setSelectedId(...)
                end
            end,
            setHighlightedId = function(...)
                if self._target then
                    self._target:setHighlighted(...)
                end
            end,
        })
    end

    ns.Window.update(self, pos, size)
    ns.Window.draw(self, pos, size)
end

--- Scroll bar drag handle.
---
--- @class ammgui.vewport.SplitHandleEventListener: ammgui._impl.eventListener.EventListener
local SplitHandleEventListener = class.create("SplitHandleEventListener", eventListener.EventListener)

--- @param view ammgui.viewport.Split
--- @param index integer
---
--- !doctype classmethod
--- @generic T: ammgui.vewport.SplitHandleEventListener
--- @param self T
--- @return T
function SplitHandleEventListener:New(view, index)
    self = eventListener.EventListener.New(self)

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

    local mainSize = math.max(0,
        self._view._size[self._view._mainDirection] - self._view._gap * math.max(0, #self._view.items - 1))

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
    --- @type ammgui._impl.context.render.Context
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
    --- @type ammgui.Vec2[]
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
        local factor = 1 - fun.a.sum(self._proportions, 0)
        for i, v in ipairs(self._proportions) do
            self._proportions[i] = factor * v
        end
    elseif #self._proportions < #self.items then
        for i, v in ipairs(self._proportions) do
            self._proportions[i] = 3 * v / 4
        end
        local factor = (1 - fun.a.sum(self._proportions, 0)) / (#self.items - #self._proportions)
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
            Vec2:FromTable {
                [self._mainDirection] = viewMainSize,
                [self._crossDirection] = crossSize,
            }
        )
        pos = pos + Vec2:FromTable {
            [self._mainDirection] = viewMainSize + self._gap,
            [self._crossDirection] = 0,
        }
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
            Vec2:FromTable {
                [self._mainDirection] = viewMainSize,
                [self._crossDirection] = crossSize,
            }
        )

        pos = pos + Vec2:FromTable {
            [self._mainDirection] = viewMainSize,
            [self._crossDirection] = 0,
        }

        if i < #self.items then
            self:_addSeparator(i, pos, size)
        end

        pos = pos + Vec2:FromTable {
            [self._mainDirection] = self._gap,
            [self._crossDirection] = 0,
        }

        table.insert(self._positions, pos)
    end

    if self._drag then
        self._context.gpu:drawRect(
            Vec2:FromTable {
                [self._mainDirection] = self._dragPos - self._gap,
                [self._crossDirection] = pos[self._crossDirection],
            },
            Vec2:FromTable {
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
--- @param pos ammgui.Vec2
--- @param size ammgui.Vec2
function ns.Split:_addSeparator(i, pos, size)
    local color = (i == self._hoverIndex and self._hover and not self._drag)
        and structs.Color { 0.3, 0.3, 0.3, 1 }
        or structs.Color { 0.1, 0.1, 0.1, 1 }

    local size = Vec2:FromTable {
        [self._mainDirection] = self._gap,
        [self._crossDirection] = size[self._crossDirection],
    }

    self._context.gpu:drawRect(pos, size, color, "", 0)
    self._context:pushEventListener(pos, size, self._handles[i])
end

return ns
