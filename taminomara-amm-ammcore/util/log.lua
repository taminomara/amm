local class = require "ammcore.util.class"
local debugHelpers = require "ammcore.util.debugHelpers"

--- Error reporting facilities.
local ns = {}

--- Global log filter. By default, log level is "Info" for all messages.
---
--- @type table<string, ammcore.util.log.Level>
AMM_LOG_LEVELS = AMM_LOG_LEVELS or {}

--- Logging level.
---
--- @enum ammcore.util.log.Level
ns.Level = {
    --- For detailed log that you only need to see when investigating behaviour
    --- of a certain system. It doesn't make sense to enable trace logging
    --- for the root logger, there's just too many of them.
    Trace = 0,

    --- For messages that are helpful when you're investigating an error
    --- and need more information, but aren't intended for end users.
    Debug = 100,

    --- For messages intended for the end user.
    Info = 200,

    --- Something that the user should be aware of.
    ---
    --- Warnings indicate that system's behaviour may differ from what the user might
    --- be expecting, but otherwise they don't require user attention.
    Warning = 300,

    --- Something went wrong and parts of the system aren't operational,
    --- but some other parts keep working, or there is a chance they'll recover.
    ---
    --- Errors require eventual user attention.
    Error = 400,

    --- Something went so wrong that the system can't operate any longer.
    ---
    --- Errors require immediate user attention.
    Critical = 500,
}

local lowercaseLevels = {}
for k, v in pairs(ns.Level) do
    lowercaseLevels[k:lower()] = v
end
lowercaseLevels["dbg"] = ns.Level.Debug
lowercaseLevels["warn"] = ns.Level.Warning
lowercaseLevels["err"] = ns.Level.Error
lowercaseLevels["crit"] = ns.Level.Critical

--- Parse level name and return an appropriate level value.
---
--- @param name string|integer
--- @return integer?
function ns.levelFromName(name)
    if type(name) == "string" then
        local level = lowercaseLevels[name:lower()]
        if level then
            return level
        end
        local level = math.tointeger(name)
        if level and level >= 0 then
            return level
        end
    elseif type(name) == "number" then
        if name >= 0 and name == math.floor(name) then
            return name
        end
    end
    return nil
end

--- Parse a log record and get its components.
---
--- If parsing fails, assume the record was printed manually.
---
--- @param s string string that was printed
--- @param msgLevel integer verbosity that was used to print the string
--- @return { logger: string, level: integer, message: string }
function ns.parseLogRecord(s, msgLevel)
    local logger, level, message = s:match("^%[([^%]]*)%] (%w+): (.*)$")
    return {
        logger = logger or "",
        level = ns.levelFromName(level) or (100 + msgLevel * 100),
        message = message or s,
    }
end

--- Mapping from logger name to its level.
---
--- @enum ammcore.util.log.LevelName
ns.LevelName = {
    [ns.Level.Trace] = "TRACE",
    [ns.Level.Debug] = "DEBUG",
    [ns.Level.Info] = "INFO",
    [ns.Level.Warning] = "WARNING",
    [ns.Level.Error] = "ERROR",
    [ns.Level.Critical] = "CRITICAL",
}

--- @private
--- @type table<string, ammcore.util.log.Logger>
ns._loggers = {}

--- Logger.
---
--- @class ammcore.util.log.Logger: class.Base
ns.Logger = class.create("Logger")

--- @param name string?
function ns.Logger:New(name)
    name = name or debugHelpers.getMod(2)

    if ns._loggers[name] then
        return ns._loggers[name]
    end

    self = class.Base.New(self)

    --- Name of this logger.
    ---
    --- @type string
    self.name = name

    --- @protected
    --- @type string
    self._prefix = name:len() > 0 and name or "<root>"

    --- @protected
    --- @type ammcore.util.log.Logger?
    self._parent = name:len() > 0 and ns.Logger:New(name:match("(.*)%.[^.]*$") or "") or nil

    ns._loggers[name] = self

    return self
end

function ns.Logger:__tostring()
    return string.format("%s(%q)", self.__name, self.name)
end

--- @private
--- @param levelInt integer
--- @param msg string
--- @param ... any
function ns.Logger:_log(levelInt, msg, ...)
    if levelInt >= self:getEffectiveLevel() then
        local levelName = ns.LevelName[levelInt] or tostring(levelInt)
        local level = math.min(math.max(0, math.tointeger(levelInt / 100) - 1), 4)
        computer.log(
            level,
            string.format("[%s] %s: %s", self._prefix, levelName, string.format(msg, ...))
        )
    end
end

--- Set level for this logger.
---
--- If this logger has no level, messages will be relayed to its parent.
--- Otherwise, they will be displayed or ignored according to the level given.
---
--- @param level ammcore.util.log.Level?
function ns.Logger:setLevel(level)
    AMM_LOG_LEVELS[self.name] = level
end

--- Get level for this logger.
---
--- @return ammcore.util.log.Level?
function ns.Logger:getLevel()
    return AMM_LOG_LEVELS[self.name]
end

--- Get level of this logger; if it has no configured level,
--- return level of its parent.
---
--- @return ammcore.util.log.Level
function ns.Logger:getEffectiveLevel()
    if AMM_LOG_LEVELS[self.name] then
        return AMM_LOG_LEVELS[self.name]
    elseif self._parent then
        return self._parent:getEffectiveLevel()
    else
        return ns.Level.Info
    end
end

--- Log a trace message.
---
--- @see ammcore.util.log.Level.Trace
--- @param msg string
--- @param ... any
function ns.Logger:trace(msg, ...)
    self:_log(ns.Level.Trace, msg, ...)
end

--- Log a debug message.
---
--- @see ammcore.util.log.Level.Debug
--- @param msg string
--- @param ... any
function ns.Logger:debug(msg, ...)
    self:_log(ns.Level.Debug, msg, ...)
end

--- Log an info message.
---
--- @see ammcore.util.log.Level.Info
--- @param msg string
--- @param ... any
function ns.Logger:info(msg, ...)
    self:_log(ns.Level.Info, msg, ...)
end

--- Log a warning message.
---
--- @see ammcore.util.log.Level.Warning
--- @param msg string
--- @param ... any
function ns.Logger:warning(msg, ...)
    self:_log(ns.Level.Warning, msg, ...)
end

--- Log an error message.
---
--- @see ammcore.util.log.Level.Error
--- @param msg string
--- @param ... any
function ns.Logger:error(msg, ...)
    self:_log(ns.Level.Error, msg, ...)
end

--- Log a critical message.
---
--- @param msg string
--- @param ... any
function ns.Logger:critical(msg, ...)
    self:_log(ns.Level.Critical, msg, ...)
end

return ns
