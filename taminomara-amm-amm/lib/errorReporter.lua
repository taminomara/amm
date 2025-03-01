local class = require "ammcore.util.class"
local severity = require "amm.lib.severity"
local array = require "ammcore.util.array"

local errorReporter = {}

--- Prototype data for a message.
---
--- @see errorReporter.addErrorCode
--- @package
--- @class errorReporter.MsgProto
--- @field code string
--- @field msg string
--- @field sv severity.Severity

--- Message data.
---
--- @see errorReporter.ErrorReporter.add
--- @package
--- @class errorReporter.Msg
--- @field msg string | nil
--- @field sv severity.Severity
--- @field locations Vector[]
--- @field persistentLocations Vector[]
--- @field firstSeen integer
--- @field lastSeen integer
--- @field persistent boolean

--- @param data errorReporter.Msg
local function clearNonPersistentData(data)
    data.locations = {}
end

--- @type table<string, errorReporter.MsgProto>
local Messages = {}

--- A class that tracks errors in the system.
---
--- There are two ways to collect messages about the system's status.
---
--- The first one is persistent messages. When an error is encountered,
--- call `raise` to log it. When an error is fixed, call `clear` to reset its message.
---
--- This approach requires keeping track of what's fixed and what's still actual.
--- To make our lifes easier, there's a second way: non-persistent messages.
---
--- Before running check, the controller manager calls `startCollectingMessages`. Then,
--- during a check, you verify system integrity and report all new messages.
--- Then, the controller manager calls `finishCollectingMessages`.
---
--- This way, you don't need to keep track of which errors were reported,
--- which weren't, and which were resolved. You just report everything that you find,
--- and the error reporter will figure it out.
---
--- @class errorReporter.ErrorReporter: class.Base
errorReporter.ErrorReporter = class.create("ErrorReporter")

function errorReporter.ErrorReporter:New()
    self = class.Base.New(self)

    --- @private
    --- @type table<string, errorReporter.Msg>
    self._messages = {}

    --- @private
    --- @type integer
    self._generation = 0

    --- @private
    --- @type Vector[]
    self._pendingPings = {}

    --- @private
    --- @type boolean
    self._messagesChanged = false

    --- @private
    --- @type table<severity.Severity, integer>
    self._svCount = {
        [severity.Severity.CRIT] = 0,
        [severity.Severity.ERR] = 0,
        [severity.Severity.WARN] = 0,
        [severity.Severity.INFO] = 0,
        [severity.Severity.OK] = 0,
    }

    return self
end

--- Get maximum severity of all messages.
---
--- @return severity.Severity
function errorReporter.ErrorReporter:getSeverity()
    if self._svCount[severity.Severity.CRIT] > 0 then return severity.Severity.CRIT end
    if self._svCount[severity.Severity.ERR] > 0 then return severity.Severity.ERR end
    if self._svCount[severity.Severity.WARN] > 0 then return severity.Severity.WARN end
    if self._svCount[severity.Severity.INFO] > 0 then return severity.Severity.INFO end
    return severity.Severity.OK
end

--- Add an error code to the table of known errors.
---
--- You will not be able to report errors without registering them first.
---
--- Params:
---  - `code`: a string identifier of the error code,
---  - `msg`: a default message for errors with this code,
---  - `sv`: a default severity for errors with this code.
---
--- @param code string
--- @param msg string
--- @param sv severity.Severity
function errorReporter.addErrorCode(code, msg, sv)
    if not code then error("No error code provided") end
    if Messages[code] then error("Error code " .. code .. " already registered") end
    if not msg then error("No error message provided") end
    if not sv then error("No error severity provided") end

    Messages[code] = {
        code = code,
        msg = msg,
        sv = sv,
    }
end

--- @private
--- @param code string
--- @param msg string | nil
--- @return errorReporter.Msg
function errorReporter.ErrorReporter:_addOrUpdate(code, msg)
    if not code then error("No error code provided") end
    if not Messages[code] then error("Unknown error code " .. code) end

    local data = self._messages[code]

    if not data then
        data = {
            msg = msg,
            sv = Messages[code].sv,
            locations = {},
            persistentLocations = {},
            persistent = false,
            firstSeen = self._generation,
            lastSeen = self._generation,
        }
        self._messages[code] = data
        self._svCount[data.sv] = self._svCount[data.sv] + 1
        self._messagesChanged = true
    elseif msg then
        data.msg = msg
    end

    data.lastSeen = self._generation

    return data
end

--- Add a new message to the error reporter.
---
--- @param code string
--- @param msg string | nil
--- @param location Vector | nil
function errorReporter.ErrorReporter:add(code, msg, location)
    local data = self:_addOrUpdate(code, msg)
    if location then
        table.insert(data.locations, location)
    end
end

--- Raise a permanent status message.
---
--- @param code string
--- @param msg string | nil
--- @param location Vector | nil
function errorReporter.ErrorReporter:raise(code, msg, location)
    local data = self:_addOrUpdate(code, msg)

    if not data.persistent and data.lastSeen == self._generation then
        computer.log(math.max(0, data.sv - 1), data.msg or Messages[code].msg)
    end

    data.persistent = true

    if location then
        table.insert(data.persistentLocations, location)
    end
end

--- Clear a status message.
---
--- @param code string
function errorReporter.ErrorReporter:clear(code)
    local data = self._messages[code]
    if data then
        self._svCount[data.sv] = self._svCount[data.sv] - 1
        self._messages[code] = nil
        self._messagesChanged = true
    end
end

--- Reset `messagesChanged` status.
function errorReporter.ErrorReporter:resetMessagesChanged()
    self._messagesChanged = false
end

--- Check if messages changed since the last call
--- to `resetMessagesChanged` or `collectErrors`.
function errorReporter.ErrorReporter:messagesChanged()
    return self._messagesChanged
end

--- Prepare for collecting non-persistent messages. Clear all non-persistent data
--- because it will be added anew during collection, and reset the `messagesChanged`
--- status.
function errorReporter.ErrorReporter:startCollectingMessages()
    self._messagesChanged = false
    for _, data in pairs(self._messages) do
        clearNonPersistentData(data)
    end
    self._generation = self._generation + 1
end

--- Finish collecting non-persistent messages. Log all new messages,
--- clear messages that were not seen in this round of collection,
--- and update the `messagesChanged` status.
function errorReporter.ErrorReporter:finishCollectingMessages()
    for code, data in pairs(self._messages) do
        if data.firstSeen == self._generation then
            -- Appeared in this generation.
            self._messagesChanged = true
            -- Persistent messages are printed when added, no need to print them here.
            if not data.persistent then
                computer.log(math.max(0, data.sv - 1), data.msg or Messages[code].msg)
            end
            array.insertMany(self._pendingPings, data.locations)
            array.insertMany(self._pendingPings, data.persistentLocations)
        elseif data.lastSeen < self._generation and not data.persistent then
            -- not seen in this generation
            self._messagesChanged = true
            self._svCount[data.sv] = self._svCount[data.sv] - 1
            self._messages[code] = nil
        end
    end
end

--- Set colors of local status indicators according to errors in this reporter.
---
--- @param siManager indicatorManager.IndicatorManager
function errorReporter.ErrorReporter:applyLocalColors(siManager)
    for _, data in pairs(self._messages) do
        if data.lastSeen == self._generation then
            -- Seen in this generation, so non-persistent locations are accurate.
            for _, location in ipairs(data.locations) do
                siManager:setLocalColor(location, data.sv)
            end
        end
        for _, location in ipairs(data.persistentLocations) do
            siManager:setLocalColor(location, data.sv)
        end
    end
end

--- Get locations for status pings that appeared
--- since the last call to `extractPendingPingLocations`.
---
--- @return Vector[]
function errorReporter.ErrorReporter:extractPendingPingLocations()
    local pendingPings = self._pendingPings
    self._pendingPings = {}
    return pendingPings
end

--- Send status pings about all messages, regardless of `extractPendingPingLocations`
--- calls.
function errorReporter.ErrorReporter:ping()
    for _, data in pairs(self._messages) do
        for _, location in ipairs(data.locations) do
            computer.attentionPing(location)
        end
        for _, location in ipairs(data.persistentLocations) do
            computer.attentionPing(location)
        end
    end
end

--- Get current error messages.
---
--- @return { code: string, msg: string, sv: severity.Severity }[]
function errorReporter.ErrorReporter:getMessages()
    local result = {}
    for code, data in pairs(self._messages) do
        table.insert(result, {
            code = code,
            sv = data.sv,
            msg = data.msg or Messages[code].msg
        })
    end
    return result
end

-- --- Generate an error report that can be displayed on a text screen.
-- ---
-- --- @return string
-- function errorReporter.ErrorReporter:generateReport()
--     -- table.sort(self._messages, function (left, right) return left.sv > right.sv end)
--     local text = ""

--     for code, data in pairs(self._messages) do
--         if data.sv >= severity.Severity.CRIT then
--             text = text .. "C: "
--         elseif data.sv == severity.Severity.ERR then
--             text = text .. "E: "
--         elseif data.sv == severity.Severity.WARN then
--             text = text .. "W: "
--         else
--             text = text .. "I: "
--         end
--         local msg = data.msg or Messages[code].msg
--         text = text .. msg .. "\n"
--     end

--     if text == "" then
--         return "No messages"
--     else
--         return text
--     end
-- end

return errorReporter
