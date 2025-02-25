local class = require "ammcore/util/class"
local debugHelpers = require "ammcore/util/debugHelpers"

--- Error reporting facilities.
local log = {}

--- Global log filter. By default, log level is "Info" for all messages.
---
--- Note: modify this value in EEPROM, before calling code loader.
--- In libraries, use `log.Logger:New("..."):setLevel` instead,
--- otherwise your changes might not be noticed.
---
--- @type table<string, log.Level>
AMM_LOG_LEVELS = AMM_LOG_LEVELS or { [""] = "Info" }

--- Logging level.
---
--- @alias log.Level "Crit"|"Err"|"Warn"|"Info"|"Debug"|"Trace"

--- @type table<log.Level, integer>
local levels = { Crit = 5, Err = 4, Warn = 3, Info = 2, Debug = 1, Trace = 0 }
--- @private
--- @type table<string, log.Logger>
log._loggers = {}

--- Logger.
---
--- @class log.Logger: class.Base
log.Logger = class.create("Logger")

--- @param name string?
function log.Logger:New(name)
    name = name or debugHelpers.getMod(2):gsub("%.<locals>", "")

    if log._loggers[name] then
        return log._loggers[name]
    end

    self = class.Base.New(self)

    --- Name of this logger.
    ---
    --- @type string
    self.name = name

    --- Level of this logger.
    ---
    --- @type log.Level?
    self.level = AMM_LOG_LEVELS[name]

    --- This is set by `setLevel` or assigning value to `level`.
    --- This declaration is just for type inference.
    ---
    --- @protected
    --- @type integer?
    self._level = self._level

    --- @protected
    --- @type string
    self._prefix = string.format("[%s] ", name)

    --- @protected
    --- @type log.Logger?
    self._parent = name:len() > 0 and log.Logger:New(name:match("(.*)%.[^.]*$") or "") or nil

    log._loggers[name] = self

    return self
end

function log.Logger:__tostring()
    return string.format("%s(%q)", self.__name, self.name)
end

function log.Logger:__newindex(k, v)
    if k == "level" then
        local levelInt = v and levels[v]
        if v and not levelInt then
            error("Unknown log level " .. tostring(v))
        end

        rawset(self, "_level", levelInt)
        rawset(self, "level", v)
    else
        rawset(self, k, v)
    end
end

--- @private
--- @param levelInt integer
--- @param prefix string
--- @param msg string
--- @param ... any
function log.Logger:_log(levelInt, prefix, msg, ...)
    if self._level then
        self:_handleMessage(levelInt, prefix, msg, ...)
    elseif self._parent then
        self._parent:_log(levelInt, prefix, msg, ...)
    end
end

--- @private
--- @param levelInt integer
--- @param prefix string
--- @param msg string
--- @param ... any
function log.Logger:_handleMessage(levelInt, prefix, msg, ...)
    if levelInt >= self._level then
        computer.log(math.max(0, levelInt - 1), prefix .. string.format(msg, ...))
    end
end

--- Log a trace message.
---
--- To see traces, enable them by setting up `AMM_LOG_LEVELS`:
---
--- ```
--- AMM_LOG_LEVELS = {
---     ["amm.ctl"] = "Trace", -- Enable traces from `amm.ctl` and its children.
--- }
--- ```
---
--- @param msg string
--- @param ... any
function log.Logger:trace(msg, ...)
    self:_log(0, self._prefix, msg, ...)
end

--- Log a debug message.
---
--- @param msg string
--- @param ... any
function log.Logger:debug(msg, ...)
    self:_log(1, self._prefix, msg, ...)
end

--- Log an info message.
---
--- @param msg string
--- @param ... any
function log.Logger:info(msg, ...)
    self:_log(2, self._prefix, msg, ...)
end

--- Log a warning message.
---
--- @param msg string
--- @param ... any
function log.Logger:warning(msg, ...)
    self:_log(3, self._prefix, msg, ...)
end

--- Log an error message.
---
--- @param msg string
--- @param ... any
function log.Logger:error(msg, ...)
    self:_log(4, self._prefix, msg, ...)
end

--- Log a critical message.
---
--- @param msg string
--- @param ... any
function log.Logger:critical(msg, ...)
    self:_log(5, self._prefix, msg, ...)
end

return log
