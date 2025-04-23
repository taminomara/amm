--- Helpers for working with arrays and tables in a functional manner.
---
--- !doctype module
--- @class ammcore.fun
local ns = {}

ns.a = require "ammcore.fun.a"

ns.t = require "ammcore.fun.t"

--- Create a function that extracts property with the given name.
---
--- @param name any
--- @return fun(x: table): unknown
function ns.get(name)
    return function(x) return x[name] end
end

return ns, ns.a, ns.t
