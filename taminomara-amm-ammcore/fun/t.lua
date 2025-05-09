local common = require "ammcore.fun._common"

--- Functions that work on tables.
---
--- !doctype module
--- @class ammcore.fun.t
local ns = {}

--- Check that all values in the table are `true`.
---
--- @generic K, V
--- @param t table<K, V>
--- @param pred? fun(v: V, k: K): any
--- @return boolean
function ns.all(t, pred)
    return common.all(t, pred, pairs)
end

--- Check that any value in the table is `true`.
---
--- @generic K, V
--- @param t table<K, V>
--- @param pred? fun(v: V, k: K): any
--- @return boolean
function ns.any(t, pred)
    return common.any(t, pred, pairs)
end

--- Insert values from one table into another, overriding any values
--- that exist in both tables.
---
--- @generic T
--- @generic U
--- @param to T table to be modified.
--- @param from U table to be copied.
--- @return T | U to to reference to the ``to`` table.
function ns.update(to, from)
    for k, v in pairs(from) do
        to[k] = v
    end
    return to
end

--- Insert values from one table into another, using the given function to merge values
--- that exist in both tables.
---
--- @generic T
--- @generic U
--- @param to table<T, U> table to be modified.
--- @param from table<T, U> table to be copied.
--- @param merger nil | fun(l: U, r: U): U function used to merge values from left and right table.
--- @return table<T, U> to to reference to the ``to`` table.
function ns.updateWith(to, from, merger)
    merger = merger or function(l, r) return r end
    for k, v in pairs(from) do
        if to[k] then
            to[k] = merger(to[k], v)
        else
            to[k] = v
        end
    end
    return to
end

--- Create a shallow copy of a table.
---
--- @generic T: table
--- @param t T
--- @return T copied copied version of ``t``.
function ns.copy(t)
    return ns.update({}, t)
end

--- Check that two tables are equal.
---
--- That is, if ``a`` and ``b`` are tables, and ``a`` does not have
--- a custom equality operator, then they should contain the same set of keys,
--- and their values should be equal when compared by the ``==`` operator.
---
--- Otherwise, if ``a`` or ``b`` is not a table, or ``a`` has custom equality operator,
--- then this function is equivalent to ``a == b``.
---
--- @generic K, V
--- @param a table<K, V> left array.
--- @param b table<K, V> right array.
--- @param getter? fun(v: V, k: K): any
--- @return boolean
function ns.eq(a, b, getter)
    return common.eq(a, b, pairs, getter)
end

--- Check that two tables are deep-equal.
---
--- That is, if ``a`` and ``b`` are tables, and ``a`` does not have
--- a custom equality operator, then they should contain the same set of keys,
--- and their values should themselves be deep-equal.
---
--- Otherwise, if ``a`` or ``b`` is not a table, or ``a`` has custom equality operator,
--- then this function is equivalent to ``a == b``.
---
--- @param a table
--- @param b table
--- @return boolean
function ns.deepEq(a, b)
    return common.deepEq(a, b, pairs)
end

return ns
