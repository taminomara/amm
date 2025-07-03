local class = require "ammcore.class"
local log = require "ammcore.log"
local defer = require "ammcore.defer"
local theme = require "ammgui.css.theme"
local promise = require "ammcore.promise"
local viewport = require "ammgui.viewport"
local eventManager = require "ammgui._impl.eventManager"
local render = require "ammgui._impl.context.render"
local tracy = require "ammcore.tracy"
local devtools = require "ammgui._impl.devtools"

--- AMM GUI Library.
---
--- Life cycle:
---
--- 1. User creates an app and provides a root component.
---
--- 2. Upon every update, components are rendered using their backends.
---    Rendering a component means running its logic and building a shadow DOM.
---
--- 3. Whenever a new version of a shadow DOM is ready, it is committed
---    to an actual DOM. Committing shadow DOM means running diff algorithm
---    to find changes between shadow DOM and actual DOM, and updating actual DOM
---    accordingly.
---
--- 4. After the actual DOM is updated, it is drawn onto a screen. This step includes
---    the following:
---
---    1. CSS update step: we create a CSS context and run a CSS update stage.
---       During this stage, each node calculates new CSS properties for itself.
---
---    2. Layout update step: each DOM node creates an appropriate layout engine
---       for itself, or reuses a layout engine from previous drawing if it's safe
---       to do so. Layout engine then run their logic in order to calculate
---       all the data necessary to display respective nodes.
---
---    3. Drawing step: we create a draw context and run drawing logic in all layout
---       engines.
---
---    4. Optional: devtools repr and update. If devtools window is open, we repr
---       DOM nodes and update the window (i.e. run steps 1-4 for devtools window as well).
---
--- !doctype module
--- @class ammgui
local ns = {}

local logger = log.Logger:New()

---
---
--- @class ammgui.App<T>: ammcore.class.Base, { setData: fun(self: ammgui.App, data: T) }
ns.App = class.create("App")

--- !doctype classmethod
--- @generic T: ammgui.dom.FunctionalParams
--- @param page fun(data: T): ammgui.component.Any
--- @param data `T`
--- @return ammgui.App<T>
function ns.App:New(gpu, page, data)
    self = class.Base.New(self)

    --- @private
    --- @type FINComputerGPUT2
    self._gpu = gpu

    --- @private
    --- @type fun(data): ammgui.component.Any
    self._page = page

    --- @private
    --- @type unknown
    self._data = data

    --- @private
    --- @type integer
    self._refreshRate = 250

    --- @private
    --- @type integer
    self._fontSize = 12

    --- @private
    --- @type ammgui.css.stylesheet.Stylesheet[]
    self._stylesheets = {}

    --- @private
    --- @type ammgui.css.theme.Theme
    self._themeStylesheet = theme.DEFAULT

    --- @private
    --- @type ammcore.promise.Event
    self._earlyRefreshEvent = promise.Event:New()

    --- @private
    --- @type ammcore.promise.Event
    self._stoppedEvent = promise.Event:New()
    self._stoppedEvent:set()

    return self
end

--- Add a stylesheet to this app.
---
--- @param style ammgui.css.stylesheet.Stylesheet
function ns.App:addStyle(style)
    if self:isRunning() then
        error("can't add style while app is running")
    end

    table.insert(self._stylesheets, style)
end

--- Add a theme stylesheet to this app.
---
--- @param style ammgui.css.theme.Theme
function ns.App:setTheme(style)
    if self:isRunning() then
        error("can't set theme while app is running")
    end

    self._themeStylesheet = style
end

--- Set font size for the root element (default is 12).
---
--- @param size integer
function ns.App:setRootFontSize(size)
    if self:isRunning() then
        error("can't set root font size while app is running")
    end

    self._fontSize = size
end

--- Set new data for the page function and update GUI.
function ns.App:setData(data)
    self._data = data
    if self:isRunning() then
        self._mainWindow:setData(data)
    end
end

--- Start the rendering thread.
function ns.App:start()
    if self:isRunning() then
        return
    end

    self._stoppedEvent:reset()
    self._earlyRefreshEvent:reset()

    --- @private
    --- @type EventQueue
    self._queue = event.queue(event.filter { sender = self._gpu })

    --- @private
    --- @type ammgui._impl.context.render.Context
    self._context = render.Context:New(self._gpu, self._earlyRefreshEvent)

    --- @private
    --- @type ammgui.viewport.Window
    self._mainWindow = viewport.Window:New(
        "main",
        self._gpu,
        self._page,
        self._data,
        {
            stylesheets = self._stylesheets,
            fontSize = self._fontSize,
            themeStylesheet = self._themeStylesheet,
        },
        self._earlyRefreshEvent
    )

    --- @private
    --- @type ammgui.viewport.Window
    self._devtoolsWindow = viewport.Devtools:New(
        "devtools",
        self._gpu,
        self._mainWindow,
        {
            stylesheets = { devtools.style },
        },
        self._earlyRefreshEvent
    )

    --- @private
    --- @type ammgui.viewport.Split
    self._rootWindow = viewport.Split:New(
        "row",
        {
            self._mainWindow,
            self._devtoolsWindow,
            -- viewport.Devtools:New(
            -- "",
            --     self._gpu,
            --     self._devtoolsWindow,
            --     {
            --         stylesheets = { devtools.style },
            --     },
            --     self._earlyRefreshEvent
            -- ),
        },
        self._context
    )

    --- @private
    --- @type ammgui.eventManager.EventManager
    self._eventManager = eventManager.EventManager:New()

    --- @private
    --- @type boolean
    self._shouldStop = false

    event.listen(self._gpu)
    future.addTask(async(self._runProtected, self))
end

--- Check if rendering thread is running.
---
--- @return boolean
function ns.App:isRunning()
    return not self._stoppedEvent:isSet()
end

--- Stop the rendering thread and wait for it to finish.
function ns.App:stop()
    if self:isRunning() then
        self._shouldStop = true
        self._earlyRefreshEvent:set() -- Ensure GUI thread doesn't wait for events.
        self._stoppedEvent:await()
    end
end

function ns.App:_runProtected()
    --- @type any, any
    local ok, err = defer.xpcall(self._run, self)

    local msg, color
    if not ok then
        if type(err) == "table" and err.message then
            err = string.format("%s\n%s", err.message, err.trace)
        elseif type(err) ~= "string" then
            err = log.pprint(err)
        end
        logger:error("Error in GUI thread: %s", err)
        msg = "Error"
        color = structs.Color { 0.8, 0.2, 0.2, 1 }
    else
        msg = "Offline"
        color = structs.Color { 0.8, 0.8, 0.8, 1 }
    end

    pcall(function()
        self._gpu:flush()
        local size = self._gpu:getScreenSize()
        self._gpu:drawRect(
            { x = 0, y = 0 },
            size,
            structs.Color { 0.02, 0.02, 0.02, 1 },
            "",
            0
        )
        local textSize = self._gpu:measureText(msg, 16, true)
        self._gpu:drawText(
            (size - textSize) * 0.5,
            msg,
            16,
            color,
            true
        )
        self._gpu:flush()
    end)
end

function ns.App:_run()
    self._gpu:flush()

    --- @type Future?
    local eventFt = nil

    while true do
        do
            local _ <close> = tracy.zoneScopedNS("AmmGui/Tick", 25)
            local size = Vec2:FromV2(self._gpu:getScreenSize())

            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Tick/Reset")
                self._context:reset(size)
            end
            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Tick/Update")
                self._rootWindow:update(Vec2:New( 0, 0 ), size)
            end
            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Tick/Draw")
                self._rootWindow:draw(Vec2:New( 0, 0 ), size)
            end
            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Tick/Finalize")
                self._context:finalize()
            end
            do
                local _ <close> = tracy.zoneScopedN("AmmGui/Tick/Flush")
                self._gpu:flush()
            end
        end

        if self._shouldStop then
            self._stoppedEvent:set()
            return
        end

        eventFt = eventFt or self._queue:waitFor({}) --[[ @as Future ]]
        local e = future.any(
            eventFt,
            -- future.sleep(self._refreshRate / 1000),
            self._earlyRefreshEvent:future()
        ):await()
        self._earlyRefreshEvent:reset()

        if type(e) == "table" then
            eventFt = nil
            while e[1] do
                self._eventManager:onEvent(self._rootWindow, self._context, table.unpack(e))
                -- Read and process all events before performing a costly update.
                e = { self._queue:pull(0) }
            end
        end
    end
end

return ns
