--- Type-safe wrappers for FIN API.
local ns = {}

--- Version of FIN xpcall for proper type checking.
---
--- @param f fun(...)
--- @param ... any
--- @return boolean, { message: any, trace: string }
function ns.xpcall(f, ...)
    return xpcall(f, ...)
end

--- Raise an error with a formatted message.
---
--- @param msg string
--- @param ... any
function ns.raise(msg, ...)
    error(string.format(msg, ...), 0)
end

--- Raise an error with a formatted message at the given stack level.
---
--- @param n integer
--- @param msg string
--- @param ... any
function ns.raiseLevel(n, msg, ...)
    error(string.format(msg, ...), n + 1)
end

--- Deferred function, must be assigned to a `close` local variable.
---
--- @see fin.defer
--- @class ammcore.utils.fin.Defer
--- @field fn fun(...)
--- @field args any[]
local Defer = {
    __name = "Defer",
    __tostring = function (self)
        return string.format("fin.defer(%s)", self.fn)
    end,
    __close = function(self, upErr)
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
}

--- Defer code execution till the end of the current block.
---
--- Assign result of this function to a local `close` variable:
---
--- ```
--- do
---     local _<close> = fin.defer(function()
---         print("I run at the end of the `do` block!")
---     end)
---
---     -- Do something else, maybe even throw an error.
---
--- end -- When `_` goes out of scope, the function above is executed.
--- ```
---
--- @nodiscard
--- @param fn fun(...)
--- @param ... any
--- @return ammcore.utils.fin.Defer
function ns.defer(fn, ...)
    return setmetatable({ fn = fn, args = { ... } }, Defer)
end

return ns
