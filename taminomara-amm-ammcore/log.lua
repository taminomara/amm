local class = require "ammcore.class"
local bootloader = require "ammcore.bootloader"

--- Error reporting facilities.
---
---
--- Basic usage
--- -----------
---
--- Create an instance of `Logger`. By default, it will inherit its name
--- from the module where it was created.
---
--- Then, use the `Logger` to print messages:
---
--- .. code-block:: lua
---
---    local log = require "ammcore.log"
---
---    local logger = log.Logger:New()
---
---    logger.info("Print any messages you like!")
---    logger.info("You can even format them: %s", "how cool is that?")
---
---
--- Configuring logging level
--- -------------------------
---
--- You can configure logging level for each logger individually
--- by calling `Logger.setLevel` or by setting its level via the
--- `~ammcore.bootloader.BootloaderConfig`
--- (see `~ammcore.bootloader.BootloaderConfig.logLevels`).
---
--- You can also configure level for the root logger by adding ``logLevel`` parameter
--- to the computer's nick (see `ammcore.nick`).
---
--- !doctype module
--- @class ammcore.log
local ns = {}

--- Logging level.
---
--- @class ammcore.log.Level: integer
ns.Level = {}

--- For detailed log that you only need to see when investigating behavior
--- of a certain system. It doesn't make sense to enable trace logging
--- for the root logger, there's just too many of them.
---
--- @type ammcore.log.Level
ns.Level.Trace = 0

--- For messages that are helpful when you're investigating an error
--- and need more information, but aren't intended for end users.
---
--- @type ammcore.log.Level
ns.Level.Debug = 100

--- For messages intended for the end user.
---
--- @type ammcore.log.Level
ns.Level.Info = 200

--- Something that the user should be aware of.
---
--- Warnings indicate that system's behavior may differ from what the user might
--- be expecting, but otherwise they don't require user attention.
---
--- @type ammcore.log.Level
ns.Level.Warning = 300

--- Something went wrong and parts of the system aren't operational,
--- but some other parts keep working, or there is a chance they'll recover.
---
--- Errors require eventual user attention.
---
--- @type ammcore.log.Level
ns.Level.Error = 400

--- Something went so wrong that the system can't operate any longer.
---
--- Errors require immediate user attention.
---
--- @type ammcore.log.Level
ns.Level.Critical = 500

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
--- @param name string|integer level name or value.
--- @return ammcore.log.Level? levelName level value.
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
--- @param s string string that was printed.
--- @param msgLevel integer verbosity that was used to print the string.
--- @return { logger: string, level: integer, message: string }
function ns.parseLogRecord(s, msgLevel)
    local logger, level, message = s:match("^%[([^%]]*)%] (%w+): (.*)$")
    return {
        logger = logger or "",
        level = ns.levelFromName(level) or (100 + msgLevel * 100),
        message = message or s,
    }
end

--- Mapping from log level to its canonical name.
---
--- You can add your own names if you plan on extending the logging system.
---
--- @type table<ammcore.log.Level, string>
ns.LevelName = {
    [ns.Level.Trace] = "TRACE",
    [ns.Level.Debug] = "DEBUG",
    [ns.Level.Info] = "INFO",
    [ns.Level.Warning] = "WARNING",
    [ns.Level.Error] = "ERROR",
    [ns.Level.Critical] = "CRITICAL",
}

--- @private
--- @type table<string, ammcore.log.Logger>
ns._loggers = {}

--- Logger.
---
--- @class ammcore.log.Logger: ammcore.class.Base
ns.Logger = class.create("Logger")

--- @param name string?
---
--- !doctype classmethod
--- @generic T: ammcore.log.Logger
--- @param self T
--- @return T
function ns.Logger:New(name)
    name = name or bootloader.getMod(2)

    if ns._loggers[name] then
        return ns._loggers[name]
    end

    self = class.Base.New(self)

    --- Name of this logger.
    ---
    --- !doctype const
    --- @type string
    self.name = name

    --- Prefix to be printed before every message.
    ---
    --- !doctype const
    --- @protected
    --- @type string
    self._prefix = name:len() > 0 and name or "<root>"

    --- Parent logger, if any.
    ---
    --- !doctype const
    --- @protected
    --- @type ammcore.log.Logger?
    self._parent = name:len() > 0 and ns.Logger:New(name:match("(.*)%.[^.]*$") or "") or nil

    ns._loggers[name] = self

    return self
end

function ns.Logger:__tostring()
    return string.format("%s(%q)", self.__name, self.name)
end

--- Set level for this logger.
---
--- If this logger has no level, messages will be relayed to its parent.
--- Otherwise, they will be displayed or ignored according to the level given.
---
--- @param level ammcore.log.Level? new logging level.
function ns.Logger:setLevel(level)
    local logLevels = bootloader.getBootloaderConfig().logLevels
    logLevels[self.name] = level
end

--- Get level for this logger.
---
--- @return ammcore.log.Level? level current logging level.
function ns.Logger:getLevel()
    local logLevels = bootloader.getBootloaderConfig().logLevels
    return logLevels[self.name]
end

--- Get level of this logger; if it has no configured level,
--- return level of its parent.
---
--- @return ammcore.log.Level level current effective logging level.
function ns.Logger:getEffectiveLevel()
    local logLevels = bootloader.getBootloaderConfig().logLevels
    local logger = self
    while logger and not logLevels[logger.name] do
        logger = logger._parent
    end
    if logger and logLevels[logger.name] then
        return logLevels[logger.name]
    else
        return ns.Level.Info
    end
end

--- Log a message with the given ``level``.
---
--- @param level ammcore.log.Level target logging level.
--- @param msg string message to be printed; will be formatted using `string.format`.
--- @param ... any arguments for `string.format`.
function ns.Logger:log(level, msg, ...)
    if level >= self:getEffectiveLevel() then
        local levelName = ns.LevelName[level] or tostring(level)
        local verbosity = math.min(math.max(0, math.tointeger(level / 100) - 1), 4)
        computer.log(
            verbosity,
            string.format("[%s] %s: %s", self._prefix, levelName, string.format(msg, ...))
        )
    end
end

--- Log a trace message.
---
--- See `ammcore.log.Level.Trace` for details.
---
--- @param msg string message to be printed; will be formatted using `string.format`.
--- @param ... any arguments for `string.format`.
function ns.Logger:trace(msg, ...)
    self:log(ns.Level.Trace, msg, ...)
end

--- Log a debug message.
---
--- See `ammcore.log.Level.Debug` for details.
---
--- @param msg string message to be printed; will be formatted using `string.format`.
--- @param ... any arguments for `string.format`.
function ns.Logger:debug(msg, ...)
    self:log(ns.Level.Debug, msg, ...)
end

--- Log an info message.
---
--- See `ammcore.log.Level.Info` for details.
---
--- @param msg string message to be printed; will be formatted using `string.format`.
--- @param ... any arguments for `string.format`.
function ns.Logger:info(msg, ...)
    self:log(ns.Level.Info, msg, ...)
end

--- Log a warning message.
---
--- See `ammcore.log.Level.Warning` for details.
---
--- @param msg string message to be printed; will be formatted using `string.format`.
--- @param ... any arguments for `string.format`.
function ns.Logger:warning(msg, ...)
    self:log(ns.Level.Warning, msg, ...)
end

--- Log an error message.
---
--- See `ammcore.log.Level.Error` for details.
---
--- @param msg string message to be printed; will be formatted using `string.format`.
--- @param ... any arguments for `string.format`.
function ns.Logger:error(msg, ...)
    self:log(ns.Level.Error, msg, ...)
end

--- Log a critical message.
---
--- @param msg string message to be printed; will be formatted using `string.format`.
--- @param ... any arguments for `string.format`.
function ns.Logger:critical(msg, ...)
    self:log(ns.Level.Critical, msg, ...)
end

local userdataKeys = {
    ["Struct<Vector>"] = { "x", "y", "z" },
    ["Struct<Vector2D>"] = { "x", "y" },
    ["Struct<Color>"] = { "r", "g", "b", "a" },
    ["Struct<Rotator>"] = { "pitch", "yaw", "roll" },
    ["Struct<Vector4>"] = { "x", "y", "z", "w" },
    ["Struct<Margin>"] = { "left", "right", "top", "bottom" },
    ["Struct<Item>"] = { "type" },
    ["Struct<ItemStack>"] = { "count", "item" },
    ["Struct<ItemAmount>"] = { "amount", "type" },
}

--- @param x any
--- @param long boolean
--- @param depth integer
--- @return string
local function _pprintImpl(x, long, depth)
    long = long or false
    depth = (depth or 0) + 1
    if not long and depth > 3 then
        return "..."
    end
    if type(x) == "userdata" then
        local name = tostring(x)
        if userdataKeys[name] then
            local res = name .. "{"
            local sep = ""
            for _, k in ipairs(userdataKeys[name]) do
                res = string.format("%s%s%s=%s", res, sep, k, _pprintImpl(x[k], long, depth))
                sep = long and ", " or ","
            end
            return res .. "}"
        end
    end
    if type(x) == "table" then
        if (getmetatable(x) or {}).__tostring then
            return tostring(x)
        end

        local res = "{"
        local sep = ""
        local i = 0
        local seenKeys = {}

        -- Print array keys.
        for k, v in ipairs(x) do
            i = i + 1
            if not long and i > 5 then
                break
            end

            res = string.format("%s%s%s", res, sep, _pprintImpl(v, long, depth))
            sep = long and ", " or ","
            seenKeys[k] = true
        end

        -- Print identifier keys.
        local stringKeys = {}
        for k in pairs(x) do
            if type(k) == "string" and string.match(k, "^[_%a][_%w]*$") then
                table.insert(stringKeys, k)
            end
        end
        table.sort(stringKeys)
        for _, k in ipairs(stringKeys) do
            i = i + 1
            if not long and i > 5 then
                break
            end

            res = string.format("%s%s%s=%s", res, sep, k, _pprintImpl(x[k], long, depth))
            sep = long and ", " or ","
            seenKeys[k] = true
        end

        for k, v in pairs(x) do
            if seenKeys[k] then
                goto continue
            end
            i = i + 1
            if not long and i > 5 then
                break
            end

            res = string.format("%s%s[%s]=%s", res, sep, _pprintImpl(k, long, depth), _pprintImpl(v, long, depth))
            sep = long and ", " or ","

            ::continue::
        end
        if not long and i > 5 then
            res = res .. sep .. "..."
        end
        return res .. "}"
    end

    if type(x) == "string" then
        x = string.format("%q", x):gsub("\\\n", "\\n"):gsub("\\9", "\\t"):gsub("\\009", "\\t")
    else
        x = tostring(x)
    end

    if long then
        return x
    else
        return x:len() > 33 and (x:sub(1, 15) .. "..." .. x:sub(x:len() - 14)) or x
    end
end

--- Pretty print a table/variable.
---
--- @param x any value to be pretty printed.
--- @param long boolean? whether to shorten the value or not, default is `false`.
--- @return string # pretty printed value.
function ns.pprint(x, long)
    return _pprintImpl(x, long or false, 0)
end

--- Pretty print function arguments, one on each line.
---
--- @param params any[] array of function arguments.
--- @param long boolean? whether to shorten the value or not, default is `false`.
--- @return string # pretty printed value.
function ns.pprintVa(params, long)
    if #params == 0 then
        return "nil"
    elseif #params == 1 then
        return ns.pprint(params[1], long)
    else
        local res = ""
        for i, param in ipairs(params) do
            res = string.format("%s\n  %s: %s", res, i, ns.pprint(param, long))
        end
        return res
    end
end

--- !doc private
--- @class ammcore.log._Pretty
local Pretty = { __tostring = function(self) return ns.pprintVa(self, self.long) end }

--- Return a wrapper that pretty prints function's arguments when converted to string.
---
--- If given one argument, this function will use `pprint`, otherwise
--- it will use `pprintVa`.
---
--- Example usage:
---
--- .. code-block::
---
---    local log = require "ammcore.log"
---    local logger = log.Logger:New()
---    logger:info("Starting a server with config=%s", log.p(config))
---
--- This example will pretty-print config. It will not run printing if log level
--- is above `~log.Level.Info`, though, because `p` does pretty printing lazily.
---
--- @param ... any values to be pretty printed.
--- @return ammcore.log._Pretty an opaque value that pretty-prints given arguments.
function ns.p(...)
    return setmetatable({ long = false, ... }, Pretty)
end

--- Like `p`, but set ``long`` to `true`.
function ns.pp(...)
    return setmetatable({ long = true, ... }, Pretty)
end

return ns
