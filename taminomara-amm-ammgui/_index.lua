local class = require "ammcore.class"
local context = require "ammgui.component.context"
local rule = require "ammgui.css.rule"
local log = require "ammcore.log"
local defer = require "ammcore.defer"
local root = require "ammgui.component.block.root"
local dom = require "ammgui.dom"
local theme = require "ammgui.css.theme"
local promise = require "ammcore.promise"
local viewport = require "ammgui.viewport"
local eventManager = require "ammgui.eventManager"
local panel        = require "ammgui.devtools"

--- AMM GUI Library.
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
--- @param page fun(data: T): ammgui.dom.AnyNode
--- @param data `T`
--- @return ammgui.App<T>
function ns.App:New(gpu, page, data)
    self = class.Base.New(self)

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
    --- @type ammgui.component.context.RenderingContext
    self._context = context.RenderingContext:New(self._gpu, self._earlyRefreshEvent)

    --- @private
    --- @type ammgui.viewport.Window
    self._mainWindow = viewport.Window:New(
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
        self._gpu,
        self._mainWindow,
        {
            stylesheets = { panel.style }
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
            viewport.Devtools:New(
                self._gpu,
                self._devtoolsWindow,
                {
                    stylesheets = { panel.style }
                },
                self._earlyRefreshEvent
            )
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
            structs.Vector2D { 0, 0 },
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
        local size = self._gpu:getScreenSize()
        self._context:reset(size)
        self._rootWindow:update(structs.Vector2D { 0, 0 }, size)
        self._rootWindow:draw(structs.Vector2D { 0, 0 }, size)
        self._context:finalize()
        self._gpu:flush()

        if self._shouldStop then
            self._stoppedEvent:set()
            return
        end

        eventFt = eventFt or self._queue:waitFor({}) --[[ @as Future ]]
        local e = future.any(
            eventFt,
            future.sleep(self._refreshRate / 1000),
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
