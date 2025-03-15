local class = require "ammcore.clas"
local errorReporter = require "amm.lib.errorReporter"
local log = require "ammcore.log"

local logger = log.Logger:New()

--- Base class for production controllers.
local controller = {}

--- Information about an incoming message.
---
--- @alias controller.Msg { addr: string, code: string }

--- An incoming message handler.
---
--- @alias controller.MsgHandler<T> fun(self: T, msg: controller.Msg, ...)

--- A handle that allows sending messages to other controllers.
---
--- @see controller.Controller.apiFor
--- @class controller.ApiHandle
--- @field package _ctl controller.Controller
--- @field package _addr string
--- @field package _code string?
--- @field [string] fun(self: controller.ApiHandle, ...: pickle.Ser)

--- A handle that allows sending messages to controller managers.
---
--- @class controller.ManagerApiHandle: ammcore.class.Base
controller.ManagerApiHandle = class.create("ManagerApiHandle")

--- @param ctl controller.Controller
--- @param addr string
function controller.ManagerApiHandle:New(ctl, addr)
    self = class.Base.New(self)

    --- @private
    --- @type controller.Controller
    self._ctl = ctl
    --- @private
    --- @type string
    self._addr = addr

    return self
end

--- Enable or disable status pings from this manager.
---
--- @param pingsEnabled boolean
function controller.ManagerApiHandle:setPingsEnabled(pingsEnabled)
    self._ctl:sendMessage(self._addr, nil, "_pingsEnabled", pingsEnabled)
end

--- Enable or disable alarms on panels related to this manager.
---
--- @param alarmEnabled boolean
function controller.ManagerApiHandle:setAlarmEnabled(alarmEnabled)
    self._ctl:sendMessage(self._addr, nil, "_alarmEnabled", alarmEnabled)
end

--- Mute alarms on panels related to this manager.
function controller.ManagerApiHandle:mute()
    self._ctl:sendMessage(self._addr, nil, "_mute")
end

--- Send status pings about all current messages in all error reporters.
function controller.ManagerApiHandle:ping()
    self._ctl:sendMessage(self._addr, nil, "_ping")
end

--- Base class for production controllers.
---
--- Each controller has the following lifetime:
---
--- 1. A controller is created in the main file and registeded in a controller manager.
---
--- 2. The manager sets `_manager`.
---
--- 3. The manager calls `start`. This routine should collect information about
---    the network, register event listeners and bus messages, report any found errors,
---    run all start-up procedures.
---
--- 4. Once every 10 seconds, the manager calls `Controller:_check`. This procedure should
---    run all relevant checks and report all current issues to the given `errRep`.
---
---    If there is a change in the system's status, it should call
---    `statusChange` to notify all listeners about it.
---
---    Note that it is the manager's job to setup an `errRep`
---    and then finalize it. If you need to trigger a check manually,
---    call `check`, not `_check`.
---
--- @class controller.Controller: ammcore.class.Base
controller.Controller = class.create("Controller")

--- Unique code for a controller. AMM allows only one instance of a particular
--- controller per computer. It means that computer's ID and controller's CODE
--- for a unique identifier.
---
--- @type string
controller.Controller.CODE = nil

function controller.Controller:__initSubclass()
    class.Base.__initSubclass(self)

    --- Class-level message handler storage.
    ---
    --- @private
    --- @type table<string, controller.MsgHandler<controller.Controller>>
    self._messageHandlers = {}

    local parent = self.__base
    if parent and type(parent["_messageHandlers"]) == "table" then
        for k, v in pairs(parent["_messageHandlers"]) do
            self._messageHandlers[k] = v
        end
    end
end

function controller.Controller:New()
    self = class.Base.New(self)

    --- @private
    --- @type manager.Manager
    self._manager = nil

    --- @type errorReporter.ErrorReporter
    self.errRep = errorReporter.ErrorReporter:New()

    --- @private
    --- @type integer
    self._checkInterval = 10000

    --- @private
    --- @type integer
    self._lastCheckTime = 0

    --- @private
    --- @type boolean
    self._needsCheck = false

    --- @private
    --- @type integer
    self._checkDeadline = 0

    --- @private
    --- @type boolean
    self._statusChanged = false

    return self
end

--- Class method: add a message handler.
---
--- Messages are used to communicate between controllers. To receive messages
--- from other controllers, register handlers via this class method.
---
--- # Parameters
---
--- - `name`: name of the message.
---
--- - `callback`: message handler that will be invoked when controller receives
---   a message with the given name. First argument of the callback must be `self`,
---   second `msg`, other arguments are arbitrary.
---
---   The `msg` table will contain data about the message sender:
---     - `msg.addr`: message sender's address,
---     - `msg.code`: message sender's controller code.
---
--- # Example
---
--- ```
--- FooCtl = class(Controller)
---
--- FooCtl:MessageHandler("ping", function(self, msg, ...)
---     print("Got ping", ...)
---     self:sendMessage(msg.addr, msg.code, "pong", ...)
--- end)
--- ```
---
--- @generic T: controller.Controller
--- @param self T
--- @param name string
--- @param callback controller.MsgHandler<T>
function controller.Controller:MessageHandler(name, callback)
    self = self.__class --[[ @as controller.Controller ]]

    if self._messageHandlers[name] then
        error("Message handler " .. name .. " already registered")
    end
    if #name == 0 then
        error("Message name can't be empty")
    end
    if name[1] == "_" then
        error("Message name can't start with underscore: " .. name)
    end

    self._messageHandlers[name] = callback
end

--- @return fun(self: controller.ApiHandle, ...: pickle.Ser)
local function _createApiHandle(name)
    return function(self, ...)
        self._ctl:sendMessage(self._addr, self._code, name, ...)
    end
end

--- Get an API facade for a controller of the given type.
---
--- This method allows sending messages to other controllers. It takes a controller
--- class and an address of the computer which runs this controller. It returns a table
--- that exposes methods for sending messages to the controller.
---
--- For example, if a controller `FooCtl` defines messages `meep` and `moop`:
---
--- ```
--- FooCtl = class(Controller)
---
--- FooCtl:MessageHandler("meep", function(self, msg, ...)
---     print(...)
--- end)
---
--- FooCtl:MessageHandler("moop", function(self, msg, ...)
---     print(...)
--- end)
--- ```
---
--- then another controller can send messages to it via requesting its API:
---
--- ```
--- BarCtl = class(Controller)
---
--- function BarCtl:_start(log)
---     --- Get an API for `Foo`.
---     local fooApi = self:apiFor(FooCtl, "<address of another computer>")
---     --- Send `meep`.
---     fooApi:meep("hello")
---     --- Send `moop`.
---     fooApi:meep("world")
--- end
--- ```
---
--- @param ctlClass controller.Controller
--- @param addr string
--- @return controller.ApiHandle
function controller.Controller:apiFor(ctlClass, addr)
    ctlClass = ctlClass.__class --[[ @as controller.Controller ]]

    --- @type controller.ApiHandle
    local api = { _ctl = self, _addr = addr, _code = ctlClass.CODE }

    for name, _ in pairs(ctlClass._messageHandlers) do
        api[name] = _createApiHandle(name)
    end

    return api
end

--- Get an API facade for a controller manager.
---
--- This method allows sending messages that control managers on remote computers.
---
--- @return controller.ManagerApiHandle
function controller.Controller:apiForManager(addr)
    return controller.ManagerApiHandle:New(self, addr)
end

--- Send message `name` to a controller with the given `code`
--- located at a computer with the given `addr`.
---
--- Note: prefer using `Controller:apiFor` instead of this method.
---
--- @see controller.Controller.apiFor
--- @param addr string
--- @param code string?
--- @param name string
--- @param ... pickle.Ser
function controller.Controller:sendMessage(addr, code, name, ...)
    self._manager:sendMessage(self.CODE, addr, code, name, ...)
end

--- Add an event listener that will receive all events mathing the given filter.
---
--- @param senders Object|Object[]
--- @param conditions EventFilter | { event?: string|string[], values?: table<string,any>}
--- @param callback fun(...)
function controller.Controller:addListener(senders, conditions, callback)
    local cb = function(...)
        local lastSeverity = self:getSeverity()
        callback(...)
        self._statusChanged = self._statusChanged or lastSeverity ~= self:getSeverity()
    end
    self._manager:addListener(self.CODE, senders, conditions, cb)
end

--- Remove all callbacks associated with the given sender.
---
--- @param senders Object|Object[]
function controller.Controller:clearListeners(senders)
    self._manager:clearListeners(self.CODE, senders)
end

--- Virtual method: return a severity code and optionally a color that will be used
--- to set global indicator colors.
---
--- @return severity.Severity?, severity.Color?
function controller.Controller:getSeverity()
    return nil, nil
end

--- Virtual method: return a structure that describes the system's state.
---
--- This can be used by other controllers to inspect or display the state.
---
--- @return pickle.Ser
function controller.Controller:getState()
    return nil
end

--- Virtual method: return a suggested factory name for monitoring.
---
--- This can be used by other controllers to inspect or display the state.
---
--- @return string?
function controller.Controller:getFactoryName()
    return nil
end

--- Abstract method: implementation of the controller's `start` routine.
function controller.Controller:start()
    self:_start()
end

--- Abstract method: implementation of the controller's `start` routine.
---
--- Do not call directly, use `start()` instead.
---
--- @protected
function controller.Controller:_start()
    -- nothing to do here
end

--- Run a status check.
---
--- Use this function in event listeners to properly reset error reporter
--- and status indicators, and run a check.
---
--- Prefer using `Controller:scheduleCheck` if you don't need results right now.
function controller.Controller:check()
    logger:trace("Checking %s", self.CODE)

    self._needsCheck = false

    local lastSeverity = self:getSeverity()
    self.errRep:startCollectingMessages()

    self:_check()

    self.errRep:finishCollectingMessages()
    self._statusChanged = (
        self._statusChanged
        or self.errRep:messagesChanged()
        or lastSeverity ~= self:getSeverity()
    )
    self._lastCheckTime = computer.millis()
end

--- Abstract method: implementation of the controller's `check` routine.
---
--- Do not call directly, use `check()` instead.
---
--- @protected
function controller.Controller:_check()
    -- nothing to do here
end

--- Schedule a check in the nearest future, while making sure
--- that we don't run checks too often.
---
--- Use this function in event listeners to properly reset error reporter
--- and status indicators, and run all checks.
---
--- @param deadlineInterval integer?
function controller.Controller:scheduleCheck(deadlineInterval)
    if not self._needsCheck then
        self._needsCheck = true
        self._checkDeadline = computer.millis() + (deadlineInterval or 1000)
    end
end

--- Indicate that the system changed its status. All controllers that subscribe
--- to the state of this controller will receive an update message.
---
--- Use this function in status ckecers and event handlers to indicate that
--- the system changed its status. After handling the current event, all subscribers
--- will be notified about the new system status.
---
--- Do not use this function when system's production metrics (i.e. input/output speeds)
--- change; monitors will pull these changes themselves.
function controller.Controller:notifySubscribers()
    self._statusChanged = true
end

--- Load state from persistent storage.
---
--- @return pickle.Ser | nil ...
function controller.Controller:loadState()
    return self._manager:loadState(self.CODE)
end

--- Save state to a persistent storage.
---
--- @param ... pickle.Ser
function controller.Controller:saveState(...)
    self._manager:saveState(self.CODE, ...)
end

--- Observed state of a computer.
---
--- @class controller.ObservedState: ammcore.class.Base
--- @field sv severity.Severity
--- @field color severity.Color?
--- @field pingsEnabled boolean
--- @field alarmEnabled boolean
--- @field alarmSounding boolean
--- @field factoryName string?
--- @field controllers table<string, controller.ObservedCtlState>

--- Observed state of a controller.
---
--- @class controller.ObservedCtlState: ammcore.class.Base
--- @field sv severity.Severity
--- @field color severity.Color?
--- @field state any
--- @field messages { code: string, msg: string, sv: severity.Severity }[]

--- @class controller.MonitoringController: controller.Controller
controller.MonitoringController = class.create("MonitoringController", controller.Controller)

--- Request state from controllers at the given address.
---
--- If `subscribe` is `true`, the controller manager of the polled machine
--- will send state updates whenever a significant event happens.
---
--- Subscription will only last for `ttl` number of milliseconds, defaults
--- to 60 seconds. This is done to decrease network traffic. You should renew
--- the subscription by requesting new state in every `_check` call. If this computer
--- gets turned off, the subscription will expire, and the polled machine will
--- no longer send updates.
---
--- @param addr string
--- @param subscribe boolean
--- @param ttl integer?
function controller.MonitoringController:requestState(addr, subscribe, ttl)
    ttl = ttl or 60000
    self:sendMessage(addr, nil, "_reqState", subscribe, ttl)
end

--- Abstract method: handle response to `requestState`.
---
--- @param from string
--- @param state controller.ObservedState
function controller.MonitoringController:onStateReceived(from, state)
    -- nothing to do here
end

controller.MonitoringController:MessageHandler("_rcvState", function(self, msg, state)
    self:onStateReceived(msg.addr, state)
end)

return controller
