---@diagnostic disable: invisible
local severity = require "amm.lib.severity"
local class = require "ammcore.clas"
local pickle = require "amm.lib.pickle"
local indicatorManager = require "amm.lib.indicatorManager"
local nick = require "ammcore.nick"
local array = require "ammcore._util.array"
local log = require "ammcore.log"
local filesystemHelpers = require "ammcore._util.fsh"
local fin = require "ammcore._util.fin"

--- Facilities for actually running controllers.
local manager = {}

local logger = log.Logger:New()

local function suppressErrors(callback, ...)
    local success, err = fin.xpcall(callback, ...)
    if not success then
        logger:error("%s\n%s", err.message, err.trace)
    end
end

--- Controller manager is a heart of the AMM package. It runs production controllers
--- and provides inter-component messaging, event handling, error reporting, etc.
---
--- @class manager.Manager: ammcore.class.Base
manager.Manager = class.create("Manager")

function manager.Manager:New()
    self = class.Base.New(self)

    --- Status pings will not happen more often than once in `pingInterval` miliseconds.
    ---
    --- @type integer
    self.pingInterval = 10000

    --- ID of the hard drive to mount. By default, the system mounts
    --- to the first drive.
    ---
    --- @type string | nil
    --- @diagnostic disable-next-line: undefined-global
    self.driveId = AMM_STATE_DRIVE_ID

    --- Point for mounting the drive.
    ---
    --- @type string
    --- @diagnostic disable-next-line: undefined-global
    self.mountPoint = AMM_STATE_MOUNT_POINT or "/srv/ammctl"

    --- Directory for files that keep persistent state.
    ---
    --- @type string
    --- @diagnostic disable-next-line: undefined-global
    self.storageDir = AMM_STATE_DIR or "/srv/ammctl/.state"

    --- @private
    --- @type boolean
    self._mounted = false

    --- @private
    --- @type controller.Controller[]
    self._controllers = {}

    --- @private
    --- @type table<string, controller.Controller>
    self._registeredCodes = {}

    --- @private
    --- @type boolean
    self._started = false

    --- @private
    --- @type table<integer, table<string, { filter: EventFilter, callback: fun() }[]>>
    self._listeners = {}

    --- @private
    --- @type number
    self._lastPingTime = 0

    --- @private
    --- @type indicatorManager.IndicatorManager
    self._siManager = indicatorManager.IndicatorManager:New()

    --- @private
    --- @type NetworkCard
    self._net = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard ]]

    --- @private
    --- @type table<string, table<string, integer>>
    self._subscribers = {}

    --- @private
    --- @type boolean
    self._pingsEnabled = false

    --- @private
    --- @type boolean
    self._alarmEnabled = false

    --- @private
    --- @type boolean
    self._muted = false

    --- @private
    --- @type boolean
    self._statusChanged = false

    return self
end

--- Add a controller to this manager.
---
--- Should be called before starting the manager.
---
--- @param controller controller.Controller
function manager.Manager:addController(controller)
    if self._started then error("can't add controllers after start") end
    if controller._manager then error("this controller is already registered") end
    if not controller.CODE then error("all controllers must define a static attribute `CODE`") end
    if self._registeredCodes[controller.CODE] then error("only one instance of a controller can be loaded") end
    controller._manager = self
    self._registeredCodes[controller.CODE] = controller
    table.insert(self._controllers, controller)
end

--- Run the controller manager indefinitely.
function manager.Manager:run()
    if self._started then error("already started") end
    self._started = true

    if not self._net then
        error("Controller can't run without a network card")
    end

    event.listen(self._net)
    self._net:open(AMM_PORT)

    logger:trace("Start")

    computer.beep(1)

    local pingsEnabled, alarmEnabled, muted = self:loadState("Amm.Manager")
    self._pingsEnabled = pingsEnabled and true or false
    self._alarmEnabled = alarmEnabled and true or false
    self._muted = muted and true or false

    for _, controller in ipairs(self._controllers) do
        controller:start()
    end

    sleep(0.4)
    computer.beep(1)
    sleep(0.1)
    computer.beep(1.5)

    self:_loop()
end

--- Get severity and color for global status indicators.
---
--- @return severity.Severity, severity.Color?
function manager.Manager:getSeverity()
    local sv = severity.Severity.OK
    local color = nil
    for _, controller in ipairs(self._controllers) do
        local ctlSv, ctlColor = controller:getSeverity()
        if not ctlSv then
            ctlSv = severity.Severity.OK
        end
        if ctlSv > sv then
            sv = ctlSv
            color = ctlColor
        elseif ctlSv == sv and not color then
            color = ctlColor
        end
    end
    if not color then
        color = { table.unpack(severity.getColor(sv)) }
        if sv >= severity.Severity.ERR then
            color[4] = true
        end
    end
    return sv, color
end

--- Get severity and color for global status indicators.
---
--- @return string?
function manager.Manager:getFactoryName()
    local parsedNick = nick.parse(computer.getInstance().nick)

    local factoryName = parsedNick:getOne("factoryName", tostring)
    if factoryName then return factoryName end

    for _, controller in ipairs(self._controllers) do
        local factoryName = controller:getFactoryName()
        if factoryName then return factoryName end
    end
end

--- Add an event listener that will receive all events matching the given filter.
---
--- @param code string
--- @param senders Object|Object[]
--- @param conditions EventFilter | { event?: string|string[], values?: table<string,any>}
--- @param callback fun(...)
function manager.Manager:addListener(code, senders, conditions, callback)
    local filter = event.filter(conditions)
    for _, sender in ipairs(senders.getType and { senders --[[ @as Object ]] } or senders) do
        event.listen(sender)
        self._listeners[sender.hash] = self._listeners[sender.hash] or {}
        self._listeners[sender.hash][code] = self._listeners[sender.hash][code] or {}
        table.insert(self._listeners[sender.hash][code], { filter = filter, callback = callback })
    end
end

--- Remove all callbacks associated with the given sender.
---
--- @param senders Object|Object[]
function manager.Manager:clearListeners(code, senders)
    for _, sender in pairs(senders.getType and { senders --[[ @as Object ]] } or senders) do
        if self._listeners[sender.hash] then
            self._listeners[sender.hash][code] = nil
            if next(self._listeners[sender.hash]) == nil then
                self._listeners[sender.hash] = nil
            end
        end
    end
end

--- @private
function manager.Manager:_loop()
    local netFilter = event.filter { event = "NetworkMessage", values = { port = AMM_PORT } }

    -- We pull events from a queue so that we don't loose any when loader waits
    -- for netboot servers to respond.
    local queue = event.queue {}

    local checkDeadline = computer.millis() + 300

    while true do
        local e = { queue:pull(0) }

        if #e == 0 then
            -- Our queue is empty, time to poll the global one.
            local e = event.pull(0)
            if not e and computer.millis() < checkDeadline then
                -- Nothing to do here.
                future.run()
                computer.skip()
                goto continue
            end
        end

        e = { queue:pull(0) }

        logger:trace("Main loop woke up with event %s", e[1])

        if #e > 0 then
            --- @cast e [string, Object, ...]
            if netFilter:matches(table.unpack(e)) then
                self:_onNetworkEvent(table.unpack(e))
            else
                for code, listeners in pairs(self._listeners[e[2].hash] or {}) do
                    local controller = self._registeredCodes[code]
                    local lastSeverity = controller:getSeverity()
                    controller.errRep:resetMessagesChanged()

                    for _, listener in ipairs(listeners) do
                        if listener.filter:matches(table.unpack(e)) then
                            suppressErrors(listener.callback, table.unpack(e))
                        end
                    end

                    controller._statusChanged = (
                        controller._statusChanged
                        or controller.errRep:messagesChanged()
                        or lastSeverity ~= controller:getSeverity()
                    )
                end
            end
        end

        -- Determine which controllers need checks.
        local checkNow = false
        local checkSoon = false
        local now = computer.millis()
        for _, controller in ipairs(self._controllers) do
            if controller._lastCheckTime + controller._checkInterval < now then
                checkNow = true
            elseif controller._needsCheck then
                if
                    -- we had no events for at least .3s
                    #e == 0
                    -- or the controller has been waiting for its check for >=1s
                    or now >= controller._checkDeadline
                then
                    -- check the controller now
                    checkNow = true
                else
                    -- we'll run the check after .3s
                    checkSoon = true
                end
            end
        end

        -- We're running checks now.
        if checkNow then
            logger:trace("Running checks now")
            for _, controller in ipairs(self._controllers) do
                -- Adding 300ms helps batch controller checks. I.e. if the controller
                -- will need check soon, we mught as well check it now.
                if controller._needsCheck or now + 300 >= controller._checkDeadline then
                    suppressErrors(controller.check, controller)
                end
            end
            checkSoon = false
        end
        -- We're running checks in the neares future.
        if checkSoon then
            logger:trace("Will run checks soon")
            checkDeadline = now + 300
        -- We're running checks as usual.
        else
            checkDeadline = now + 300000
            for _, controller in ipairs(self._controllers) do
                checkDeadline = math.min(
                    checkDeadline,
                    controller._lastCheckTime + controller._checkInterval
                )
            end
            -- Limit checks to once per .3s.
            checkDeadline = math.max(checkDeadline, now + 300)
        end

        -- Discover any changes in status indicators.
        self._siManager:discover()

        -- Update local colors.
        for _, controller in ipairs(self._controllers) do
            controller.errRep:applyLocalColors(self._siManager)
        end
        self._siManager:applyLocalColors()

        -- Update global colors.
        local sv, color = self:getSeverity()
        self._siManager:globalOn(color or sv)

        -- Maybe unmute.
        self._muted = self._muted and sv >= severity.Severity.ERR

        -- If controllers changed status, send updates.
        for _, controller in ipairs(self._controllers) do
            if controller._statusChanged then
                self._statusChanged = true
                controller._statusChanged = false
            end
        end
        if self._statusChanged then
            logger:trace("Status changed, sending updates")

            self._statusChanged = false

            -- Send pings.
            if self._lastPingTime == 0 or now > self._lastPingTime + self.pingInterval then
                local pendingPings = {}
                for _, controller in ipairs(self._controllers) do
                    local controllerPings = controller.errRep:extractPendingPingLocations()
                    if self._pingsEnabled then
                        array.insertMany(pendingPings, controllerPings)
                    end
                end
                for _, location in ipairs(pendingPings) do
                    computer.attentionPing(location)
                end
            end

            local subscribers = self._subscribers
            self._subscribers = {}
            local observedState = nil
            for addr, codes in pairs(subscribers) do
                for code, expires in pairs(codes) do
                    if expires >= now then
                        self._subscribers[addr] = self._subscribers[addr] or {}
                        self._subscribers[addr][code] = expires
                        if not observedState then
                            observedState = self:_getState(nil)
                        end
                        self:sendMessage("Amm.Manager", addr, code, "_rcvState", observedState)
                    end
                end
            end
        end

        -- Run any coroutines that were added to the default FIN scheduler.
        future.run()

        logger:trace("Main loop done")

        ::continue::
    end
end

--- @private
--- @param sender string
--- @param fromCode string
--- @param code string?
--- @param name string
--- @param data string
function manager.Manager:_onNetworkEvent(_, _, sender, _, fromCode, code, name, data)
    local unpickledData = pickle.unpickle(data) --[[ @as pickle.Ser[] ]]
    local msg = { addr = sender, code = fromCode }

    if name == "_reqState" then
        -- request state
        local observedState = self:_getState(code)
        self:sendMessage("Amm.Manager", msg.addr, msg.code, "_rcvState", observedState)

        local subscribe, ttl = table.unpack(unpickledData)
        if subscribe then
            local expires = computer.millis() + (math.tointeger(ttl) or 40000)
            self._subscribers[msg.addr] = self._subscribers[msg.addr] or {}
            self._subscribers[msg.addr][fromCode] = expires
        end
        return
    elseif name == "_pingsEnabled" then
        local pingsEnabled = table.unpack(unpickledData)
        self._pingsEnabled = pingsEnabled and true or false
        self:saveState("Amm.Manager", self._pingsEnabled, self._alarmEnabled, self._muted)
        self._statusChanged = true
    elseif name == "_alarmEnabled" then
        local alarmEnabled = table.unpack(unpickledData)
        if alarmEnabled and not self._alarmEnabled then
            self._muted = false
        end
        self._alarmEnabled = alarmEnabled and true or false
        self:saveState("Amm.Manager", self._pingsEnabled, self._alarmEnabled, self._muted)
        self._statusChanged = true
    elseif name == "_mute" then
        if self:getSeverity() >= severity.Severity.ERR then
            self:saveState("Amm.Manager", self._pingsEnabled, self._alarmEnabled, self._muted)
            self._muted = true
            self._statusChanged = true
        end
    elseif name == "_ping" then
        for _, controller in ipairs(self._controllers) do
            controller.errRep:ping()
        end
        self._lastPingTime = computer.millis()
    end

    for _, controller in ipairs(self._controllers) do
        if not code or controller.CODE == code then
            local handler = controller._messageHandlers[name]
            if handler then
                suppressErrors(handler, controller, msg, table.unpack(unpickledData))
            end
        end
    end
end

--- @param fromCode string
--- @param addr string
--- @param code string?
--- @param name string
--- @param ... pickle.Ser
function manager.Manager:sendMessage(fromCode, addr, code, name, ...)
    local data = pickle.pickle({ ... })

    if addr == "_loopback_" then
        addr = self._net.id
    end
    if addr == "_broadcast_" then
        self._net:broadcast(AMM_PORT, fromCode, code, name, data)
    else
        self._net:send(addr, AMM_PORT, fromCode, code, name, data)
    end
end

--- Get directory for files that keep persistent state,
--- lazily initialising file system.
---
--- @return string
function manager.Manager:getStorageDir()
    if not self._mounted then
        filesystem.initFileSystem("/dev")
        if not self.driveId and AMM_BOOT_CONFIG then
            ---@diagnostic disable-next-line: undefined-global
            self.driveId = AMM_BOOT_CONFIG.driveId
        end

        if not self.driveId then
            local devices = filesystem.children("/dev")
            if #devices == 0 then
                error("no hard drive detected")
            elseif #devices > 1 then
                error("multiple hard drives detected, AMM_STATE_DRIVE_ID is required")
            end
            self.driveId = devices[1]
        end

        if type(self.driveId) ~= "string" then
            error(string.format("driveId has invalid value %q", self.driveId))
        elseif not filesystem.exists(filesystem.path("/dev", self.driveId)) then
            error(string.format("no hard drive with id %q", self.driveId))
        end

        filesystem.mount(filesystem.path("/dev", self.driveId), self.mountPoint)

        self._mounted = true
    end

    return self.storageDir
end

--- Load state from persistent storage.
---
--- @param code string
--- @return pickle.Ser | nil ...
function manager.Manager:loadState(code)
    local storageDir = self:getStorageDir()
    local stateFile = filesystem.path(storageDir, code)

    if not (filesystem.exists(stateFile) and filesystem.isFile(stateFile)) then
        return nil
    else
        local content = filesystemHelpers.readFile(stateFile)

        local result
        local success = pcall(function () result = pickle.unpickle(content) end)

        if success then
            return table.unpack(result)
        else
            logger:warning("Failed restoring state from a persistent storage")
            return nil
        end
    end
end

--- Save state to a persistent storage.
---
--- @param code string
--- @param ... pickle.Ser
function manager.Manager:saveState(code, ...)
    local storageDir = self:getStorageDir()

    local content = pickle.pickle({ ... })

    filesystem.createDir(storageDir, true)
    local stateFile = filesystem.path(storageDir, code)
    local fd = filesystem.open(stateFile, "w")
    fd:write(content)
    fd:close()
end

--- Get state of all controllers.
---
--- @param code string?
--- @return controller.ObservedState
function manager.Manager:_getState(code)
    local sv, color = self:getSeverity()
    local observedState = {
        sv = sv,
        color = color,
        factoryName = self:getFactoryName(),
        pingsEnabled = self._pingsEnabled,
        alarmEnabled = self._alarmEnabled,
        alarmSounding = sv >= severity.Severity.ERR and self._alarmEnabled and not self._muted,
        controllers = {},
    }
    for _, controller in ipairs(self._controllers) do
        if not code or controller.CODE == code then
            local sv, color = controller:getSeverity()
            local state = controller:getState()
            local messages = controller.errRep:getMessages()
            observedState.controllers[controller.CODE] = {
                sv = sv, color = color, state = state, messages = messages,
            }
        end
    end
    return observedState
end

return manager
