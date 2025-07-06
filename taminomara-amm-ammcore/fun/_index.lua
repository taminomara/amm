--- @namespace ammcore.fun

--- Helpers for working with arrays and tables in a functional manner.
local ns = {}

--- @module "ammcore.fun.a"
ns.a = require "ammcore.fun.a"

--- @module "ammcore.fun.t"
ns.t = require "ammcore.fun.t"

--- Create a function that extracts property with the given name.
---
--- @param name any
--- @return fun(x: table): any
function ns.get(name)
    return function(x) return x[name] end
end

--- Create a function that extracts property with the given name and calls it
--- with the given arguments.
---
--- @param name any
--- @return fun(x: table): any
function ns.call_fun(name, ...)
    local args = { ... }
    return function(x) return x[name](table.unpack(args)) end
end

--- Create a function that extracts property with the given name and calls it
--- with ``self`` and the given arguments.
---
--- @param name any
--- @return fun(x: table): any
function ns.call_meth(name, ...)
    local args = { ... }
    return function(x) return x[name](x, table.unpack(args)) end
end

return ns
