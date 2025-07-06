--- @namespace ammcore.defer

local log = require "ammcore.log"

--- Type-safe utilities for working with errors in Lua.
local ns = {}

local logger = log.getLogger()

--- Version of FIN xpcall for proper type checking.
---
--- Calls the given function with the given parameters.
--- Returns `true` if function call was successful, `false` if function call
--- raised an error.
---
--- @param fn fun(...) a function that will be called in protected environment.
--- @param ... any function parameters.
--- @return boolean ok `true` if function call was successful.
--- @return { message: any, trace: string } err an object describing an error; only returned when ``ok`` is `false`.
function ns.xpcall(fn, ...)
    return xpcall(fn, ...) ---@diagnostic disable-line: return-type-mismatch
end

--- Deferred function, must be assigned to a `close` local variable.
---
--- See `defer` for more info.
---
--- @class Defer
--- @field fn fun(...)
--- @field args any[]
--- @field closed boolean
local Defer = {
    __name = "Defer",
    __tostring = function(self)
        return string.format("defer(%s)", self.fn)
    end,
    __close = function(self, upErr)
        self.closed = true
        local ok, err = ns.xpcall(self.fn, table.unpack(self.args))
        if not ok and upErr then
            error(string.format(
                "error in deferred function:\n%s\n\ncaused by:\n%s",
                (tostring(err.message) .. err.trace):gsub("([^\n\r]+)", "\t%1"),
                (tostring(upErr.message) .. upErr.trace):gsub("([^\n\r]+)", "\t%1")
            ))
        elseif not ok then
            error(tostring(err.message) .. err.trace)
        end
    end,
    __gc = function(self)
        if not self.closed then
            logger:warning(
                "value returned from 'defer' was not properly closed; closing it now"
            )
            getmetatable(self).__close(self)
        end
    end,
}

--- Defer code execution till the end of the current block.
---
--- Assign result of this function to a local ``close`` variable:
---
--- .. code-block:: lua
---
---    do
---        local _<close> = defer.defer(function()
---            print("I run at the end of the `do` block!")
---        end)
---
---        -- Do something else, maybe even throw an error.
---
---    end -- When `_` goes out of scope, the function above is executed.
---
--- @nodiscard
--- @param fn fun(...) a function that will be called upon closing the returned value.
--- @param ... any function parameters.
--- @return Defer defer an opaque object that should be placed to a ``close`` variable.
function ns.defer(fn, ...)
    return setmetatable({ fn = fn, args = { ... }, closed = false }, Defer)
end

return ns
