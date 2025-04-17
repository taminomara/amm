local class = require "ammcore.class"
local defer = require "ammcore.defer"
local rule = require "ammgui.css.rule"
local array = require "ammcore._util.array"
local log = require "ammcore.log"

--- Rendering context.
---
--- !doctype module
--- @class ammgui.component.context
local ns = {}

--- Text measuring service.
---
--- Allows measuring dimensions of rendered strings in batch.
---
--- @class ammgui.component.context.TextMeasure: ammcore.class.Base
ns.TextMeasure = class.create("TextMeasure")

--- !doctype classmethod
--- @generic T: ammgui.component.context.TextMeasure
--- @param self T
--- @return T
function ns.TextMeasure:New()
    self = class.Base.New(self)

    --- @private
    --- @type { text: string, size: integer, monospace: boolean, cb: fun(size: Vector2D, baseline: number) }[]
    self._requests = {}

    return self
end

--- Request measure for a word.
---
--- @param text string
--- @param size integer
--- @param monospace boolean
--- @param cb fun(size: Vector2D, baseline: number)
function ns.TextMeasure:addRequest(text, size, monospace, cb)
    table.insert(self._requests, { text = text, size = size, monospace = monospace, cb = cb })
end

--- Measure all words and save results.
---
--- @param gpu FINComputerGPUT2
function ns.TextMeasure:run(gpu)
    if #self._requests == 0 then
        return
    end

    local text = {}
    local size = {}
    local monospace = {}

    for _, word in ipairs(self._requests) do
        table.insert(text, word.text)
        table.insert(size, word.size)
        table.insert(monospace, word.monospace)
    end

    local measured = gpu:measureTextBatch(text, size, monospace)
    local baselines = gpu:getFontBaselineBatch(size, monospace)

    for i = 1, #self._requests do
        self._requests[i].cb(measured[i], baselines[i])
    end

    self._requests = {}
end

--- CSS calculation context.
---
--- @class ammgui.css.component.CssContext: ammcore.class.Base
ns.CssContext = class.create("CssContext")

--- @param rules { selector: ammgui.css.selector.Selector, rule: ammgui.css.rule.CompiledRule }[]
--- @param theme table<string, Color | string>
--- @param units table<string, number>
--- @param outdated boolean?
---
--- !doctype classmethod
--- @generic T: ammgui.css.component.CssContext
--- @param self T
--- @return T
function ns.CssContext:New(rules, theme, units, outdated)
    self = class.Base.New(self)

    --- @private
    --- @type table<string, Color | string>
    self._theme = theme

    --- @private
    --- @type table<string, number>
    self._units = units

    --- @private
    --- @type boolean
    self._outdated = outdated or false

    --- @private
    --- @type { selector: ammgui.css.selector.Selector, rule: ammgui.css.rule.CompiledRule }[]
    self._rules = rules

    --- @private
    --- @type { elem: string, classes: table<string, true>, pseudo: table<string, true> }[]
    self._path = {}

    --- @private
    --- @type { parent: ammgui.css.rule.Resolved, cssOutdated: boolean, layoutOutdated: boolean }[]
    self._context = {}

    return self
end

--- @private
--- @return ammgui.css.rule.Resolved? parent
--- @return boolean cssOutdated
--- @return boolean layoutOutdated
function ns.CssContext:_getContext()
    if #self._context > 0 then
        local context = self._context[#self._context]
        return context.parent, context.cssOutdated, context.layoutOutdated
    else
        return nil, self._outdated, self._outdated
    end
end

--- @private
--- @param inline ammgui.css.rule.CompiledRule
--- @return ammgui.css.rule.CompiledRule[] newRules
function ns.CssContext:_matchRules(inline)
    --- @type ammgui.css.rule.CompiledRule[]
    local matchingRules = {}
    for _, ruleData in ipairs(self._rules) do
        if ruleData.selector:match(self._path) then
            table.insert(matchingRules, ruleData.rule)
        end
    end
    table.insert(matchingRules, inline)

    return matchingRules
end

--- Enter a new DOM node and update context accordingly.
---
--- @param css ammgui.css.rule.Resolved previous CSS settings.
--- @param elem string name of the DOM node.
--- @param classes table<string, true> set of CSS classes applied to the DOM node.
--- @param pseudo table<string, true> set of CSS pseudoclasses applied to the DOM node.
--- @param inline ammgui.css.rule.CompiledRule inline CSS settings of a component.
--- @param childCssSettingsChanged boolean indicates that there were changes in component's or child's CSS settings.
--- @param cssSettingsChanged boolean indicates that there were changes in component's inline CSS settings or set of classes and pseudoclasses.
--- @return boolean outdated `true` if layout settings were changed.
--- @return boolean shouldPropagate `true` if component should propagate CSS changes to its children.
--- @return ammgui.css.rule.Resolved newCss new CSS settings for component.
function ns.CssContext:enterNode(css, elem, classes, pseudo, inline, childCssSettingsChanged, cssSettingsChanged)
    local parent, cssOutdated, layoutOutdated = self:_getContext()

    table.insert(self._path, { elem = elem, classes = classes, pseudo = pseudo })

    cssOutdated = cssOutdated or not css
    layoutOutdated = layoutOutdated or not css

    if cssOutdated or cssSettingsChanged then
        local newRules = self:_matchRules(inline)

        if not cssOutdated or not layoutOutdated then
            local oldRules = css and rawget(css, "_context") or {}

            -- Only reset calculated css values if rules actually changed.
            -- I.e. we toggle `:hover` often, but most components don't have
            -- any rules related to `:hover`. And those that do, only update
            -- their layout-safe options.
            cssOutdated = cssOutdated or not array.eq(oldRules, newRules)
            if cssOutdated and not layoutOutdated then
                local i, j, n = 1, 1, math.max(#newRules, #oldRules)
                while i <= n and j <= n do
                    while i <= #newRules and newRules[i].isLayoutSafe do
                        i = i + 1
                    end
                    while j <= #oldRules and oldRules[j].isLayoutSafe do
                        j = j + 1
                    end
                    if newRules[i] ~= oldRules[j] then
                        layoutOutdated = true
                        break
                    end
                    i = i + 1
                    j = j + 1
                end
            end
        end

        if cssOutdated or layoutOutdated then
            css = rule.Resolved:New(newRules, parent, self._theme, self._units)
        end
    end
    table.insert(self._context, { parent = css, cssOutdated = cssOutdated, layoutOutdated = layoutOutdated })

    return layoutOutdated, cssOutdated or childCssSettingsChanged, css
end

--- Exit a DOM node and update context accordingly.
function ns.CssContext:exitNode()
    if #self._path == 0 or #self._context == 0 then
        error("'exitNode' was called before 'enterNode'")
    else
        table.remove(self._path)
        table.remove(self._context)
    end
end

--- A helper which enters a DOM node and returns a deferred statement to exit it.
---
--- See `ammcore.defer` for more info.
---
--- @param css ammgui.css.rule.Resolved previous CSS settings.
--- @param elem string name of the DOM node.
--- @param classes table<string, true> set of CSS classes applied to the DOM node.
--- @param pseudo table<string, true> set of CSS pseudoclasses applied to the DOM node.
--- @param inline ammgui.css.rule.CompiledRule inline CSS settings of a component.
--- @param childCssSettingsChanged boolean indicates that there were changes in component's or child's CSS settings.
--- @param cssSettingsChanged boolean indicates that there were changes in component's inline CSS settings or set of classes and pseudoclasses.
--- @return ammcore.defer._Defer deferred statement. See `ammcore.defer` for more info.
--- @return boolean outdated `true` if layout settings were changed.
--- @return boolean shouldPropagate `true` if component should propagate CSS changes to its children.
--- @return ammgui.css.rule.Resolved newCss new CSS settings for component.
function ns.CssContext:descendNode(css, elem, classes, pseudo, inline, childCssSettingsChanged, cssSettingsChanged)
    return defer.defer(self.exitNode, self),
        self:enterNode(css, elem, classes, pseudo, inline, childCssSettingsChanged, cssSettingsChanged)
end

--- Rendering context.
---
--- All clipping should be added through this context so that mouse event handlers
--- can calculate whether an interactive element is in a clipped zone or not.
---
--- @class ammgui.component.context.RenderingContext: ammcore.class.Base
ns.RenderingContext = class.create("Context")

--- @param gpu FINComputerGPUT2
--- @param earlyRefreshEvent ammcore.promise.Event
---
--- !doctype classmethod
--- @generic T: ammgui.component.context.RenderingContext
--- @param self T
--- @return T
function ns.RenderingContext:New(gpu, earlyRefreshEvent)
    self = class.Base.New(self)

    --- GPU used for rendering.
    ---
    --- !doc const
    --- @type FINComputerGPUT2
    self.gpu = gpu

    --- @private
    --- @type ammcore.promise.Event
    self._earlyRefreshEvent = earlyRefreshEvent

    self:reset(gpu:getScreenSize())

    return self
end

--- Reset rendering context before next redraw.
---
--- @param size Vector2D
function ns.RenderingContext:reset(size)
    --- @private
    --- @type Vector2D
    self._size = size

    --- @private
    --- @type Vector2D
    self._posA = structs.Vector2D { 0, 0 }

    --- @private
    --- @type Vector2D
    self._posB = size

    --- @private
    --- @type Vector2D
    self._clipPosA = self._posA

    --- @private
    --- @type Vector2D
    self._clipPosB = self._posB

    --- A single large screen panel is ``300x300``, resulting in ``6x6`` event grid.
    ---
    --- @private
    --- @type integer
    self._eventGridResolution = 50

    --- @private
    --- @type integer
    self._eventGridSizeX = math.floor(size.x / self._eventGridResolution) + 1

    --- @private
    --- @type integer
    self._eventGridSizeY = math.floor(size.y / self._eventGridResolution) + 1

    --- @private
    --- @type { posA: Vector2D, posB: Vector2D, clipPosA: Vector2D, clipPosB: Vector2D, clip: boolean }[]
    self._layoutStack = {}

    --- @private
    --- @type table<integer, { posA: Vector2D, posB: Vector2D, eventReceiver: ammgui.eventManager.EventListener }[]>
    self._eventGrid = {}
end

function ns.RenderingContext:requestEarlyRefresh()
    self._earlyRefreshEvent:set()
end

--- @param coords Vector2D
--- @return integer
function ns.RenderingContext:_coordsToEventGrid(coords)
    local x = math.floor(coords.x / self._eventGridResolution)
    local y = math.floor(coords.y / self._eventGridResolution)
    return math.floor(y + self._eventGridSizeX + x)
end

--- Get topmost event receiver by mouse coordinates.
---
--- @param pos Vector2D
--- @return ammgui.eventManager.EventListener? topReceiver
--- @return table<ammgui.eventManager.EventListener, Vector2D> affectedReceivers
function ns.RenderingContext:getEventListener(pos)
    if not (0 <= pos.x and pos.x < self._size.x) then return nil, {} end
    if not (0 <= pos.y and pos.y < self._size.y) then return nil, {} end
    local cell = self._eventGrid[self:_coordsToEventGrid(pos)]
    if not cell then return nil, {} end

    local receivers = {}
    local firstReceiver = nil
    for _, eventCoords in ipairs(cell) do
        if
            eventCoords.posA.x <= pos.x and pos.x < eventCoords.posB.x
            and eventCoords.posA.y <= pos.y and pos.y < eventCoords.posB.y
        then
            receivers[eventCoords.eventReceiver] = eventCoords.posA
            firstReceiver = eventCoords.eventReceiver
        end
    end
    return firstReceiver, receivers
end

--- Add an event receiver to the depth buffer.
---
--- Depth buffer is cleared before every redraw.
---
--- @param position Vector2D
--- @param size Vector2D
--- @param eventReceiver ammgui.eventManager.EventListener
function ns.RenderingContext:pushEventListener(position, size, eventReceiver)
    local posA = self._posA + position
    local posB = posA + size
    local x1, x2 = math.max(posA.x, self._clipPosA.x), math.min(posB.x, self._clipPosB.x)
    local y1, y2 = math.max(posA.y, self._clipPosA.y), math.min(posB.y, self._clipPosB.y)
    if x1 < x2 and y1 < y2 then
        local x1g = math.floor(x1 / self._eventGridResolution)
        local x2g = math.floor((x2 - 1) / self._eventGridResolution)
        local y1g = math.floor(y1 / self._eventGridResolution)
        local y2g = math.floor((y2 - 1) / self._eventGridResolution)
        local eventCoords = {
            posA = structs.Vector2D { x1, y1 },
            posB = structs.Vector2D { x2, y2 },
            eventReceiver = eventReceiver,
        }

        for x = x1g, x2g do
            for y = y1g, y2g do
                local i = y + self._eventGridSizeX + x
                self._eventGrid[i] = self._eventGrid[i] or {}
                table.insert(self._eventGrid[i], eventCoords)
            end
        end
    end
end

--- @param position Vector2D
--- @param size Vector2D
--- @param clip boolean
--- @return boolean visible `true` if new layout is visible on the screen.
function ns.RenderingContext:pushLayout(position, size, clip)
    table.insert(self._layoutStack, {
        posA = self._posA,
        posB = self._posB,
        clipPosA = self._clipPosA,
        clipPosB = self._clipPosB,
        clip = clip,
    })
    self._posA = self._posA + position
    self._posB = self._posA + size

    if clip then
        self._clipPosA = structs.Vector2D {
            math.max(self._clipPosA.x, self._posA.x),
            math.max(self._clipPosA.y, self._posA.y),
        }
        self._clipPosB = structs.Vector2D {
            math.min(self._clipPosB.x, self._posB.x),
            math.min(self._clipPosB.y, self._posB.y),
        }

        self.gpu:pushClipRect(position, size)
    end

    self.gpu:pushLayout(position, size, 1)

    return
        self._posA.x < self._clipPosB.x
        and self._posA.y < self._clipPosB.y
        and self._posB.x >= self._clipPosA.x
        and self._posB.y >= self._clipPosA.y
end

function ns.RenderingContext:popLayout()
    local prevLayout = table.remove(self._layoutStack)
    if not prevLayout then
        error("'popLayout' called before 'pushLayout'")
    end

    self._posA = prevLayout.posA
    self._posB = prevLayout.posB
    self._clipPosA = prevLayout.clipPosA
    self._clipPosB = prevLayout.clipPosB

    self.gpu:popGeometry()
    if prevLayout.clip then
        self.gpu:popClip()
    end
end

function ns.RenderingContext:finalize()
    -- if self._dragging and self._dragIconPos then
    --     self.gpu:drawBox {
    --         position = self._dragIconPos,
    --         size = structs.Vector2D { 20, 20 },
    --         rotation = 0,
    --         color = structs.Color { 1, 1, 1, 0.12 },
    --         image = "",
    --         imageSize = structs.Vector2D { x = 0, y = 0 },
    --         hasCenteredOrigin = true,
    --         horizontalTiling = false,
    --         verticalTiling = false,
    --         isBorder = false,
    --         margin = { top = 0, right = 0, bottom = 0, left = 0 },
    --         isRounded = true,
    --         radii = structs.Vector4 { 10, 10, 10, 10 },
    --         hasOutline = true,
    --         outlineThickness = 1,
    --         outlineColor = structs.Color { 1, 1, 1, 0.5 },
    --     }
    -- end
end

return ns
