--- Type-safe wrappers for FIN API.
local fin = {}

--- Version of FIN xpcall for proper type checking.
---
--- @param f fun(...)
--- @param ... any
--- @return boolean, { message: any, trace: string }
function fin.xpcall(f, ...)
    return xpcall(f, ...)
end

--- Deferred function, must be assigned to a `close` local variable.
---
--- @see fin.defer
--- @class fin.Defer
--- @field fn fun(...)
--- @field args any[]
local Defer = {
    __name = "fin.Defer",
    __tostring = function (self)
        return string.format("fin.defer(%s)", self.fn)
    end,
    __close = function(self, upErr)
        local ok, err = fin.xpcall(self.fn, table.unpack(self.args))
        if not ok and upErr then
            error(string.format(
                "%s\n\ncaused by:\n%s",
                tostring(err.message) .. err.trace,
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
--- @return fin.Defer
function fin.defer(fn, ...)
    return setmetatable({ fn = fn, args = { ... } }, Defer)
end

return fin
