local common = require "ammcore.fun._common"

--- Functions that work on arrays.
---
--- !doctype module
--- @class ammcore.fun.a
local ns = {}

--- Concatenate array elements using the given separator.
---
--- Equivalent to `table.concat` from lua stdlib.
---
--- @param a string[]
--- @param sep? string
--- @return string
function ns.concat(a, sep) return table.concat(a, sep) end
rawset(ns, "concat", table.concat) -- Use `rawset` to bypass lua-ls analysis.

--- Insert a value into an array.
---
--- Equivalent to `table.insert` from lua stdlib.
---
--- @overload fun(a: any[], i: integer, v: any)
--- @generic T
--- @param a T[]
--- @param v T
function ns.insert(a, v) table.insert(a, v) end
rawset(ns, "insert", table.insert) -- Use `rawset` to bypass lua-ls analysis.

--- Remove a value from an array.
---
--- Equivalent to `table.remove` from lua stdlib.
---
--- @generic T
--- @param a T[]
--- @param i? integer
--- @return T
function ns.remove(a, i) return table.remove(a, i) end
rawset(ns, "remove", table.remove) -- Use `rawset` to bypass lua-ls analysis.

--- Equivalent to `table.sort` from lua stdlib.
---
--- @generic T
--- @param a T[]
--- @param cmp? fun(a: T, b: T): boolean
function ns.sort(a, cmp) return table.sort(a, cmp) end
rawset(ns, "sort", table.sort) -- Use `rawset` to bypass lua-ls analysis.

--- Check that all values in an array are `true`.
---
--- @generic T
--- @param a T[]
--- @param pred? fun(x: T): any
--- @return boolean
function ns.all(a, pred)
    return common.all(a, pred, ipairs)
end

--- Check that any value in an array is `true`.
---
--- @generic T
--- @param a T[]
--- @param pred? fun(x: T): any
--- @return boolean
function ns.any(a, pred)
    return common.any(a, pred, ipairs)
end

--- Insert values from one array into another.
---
--- @generic T
--- @param to T[] array to be modified.
--- @param from T[] array to be copied.
--- @return T[] to reference to the ``to`` array.
function ns.extend(to, from)
    for _, v in ipairs(from) do
        table.insert(to, v)
    end
    return to
end

--- Create a shallow copy of an array.
---
--- @generic T
--- @param a T[]
--- @return T[] copied copied version of ``a``.
function ns.copy(a)
    return ns.extend({}, a)
end

--- Apply function to every element of an array.
---
--- Automatically filter `nil` values.
---
--- @generic T, U
--- @param arr T[] array to be mapped.
--- @param fn fun(x: T, i: number): U mapper.
--- @return U[] mapped new array containing result of applying ``fn`` to every element in ``arr``.
function ns.map(arr, fn)
    local res = {}
    for i, v in ipairs(arr) do
        local m = fn(v, i)
        if m ~= nil then
            table.insert(res, m)
        end
    end
    return res
end

--- Filter values in array by the given predicate.
---
--- @generic T
--- @param arr T[] array to be filtered.
--- @param fn fun(x: T, i: number): boolean predicate.
--- @return T[] filtered new array containing values for which ``fn`` returned `true`.
function ns.filter(arr, fn)
    return ns.map(arr, function(x, i) return fn(x, i) and x or nil end)
end

--- Apply function to every element of an array, placing results back to the same array.
---
--- Automatically filter `nil` values.
---
--- @generic T, U
--- @param arr T[] array to be mapped.
--- @param fn fun(x: T, i: number): U mapper.
--- @return U[] mapped initial array type-casted to ``U[]``.
function ns.mapInPlace(arr, fn)
    local to
    for i, v in ipairs(arr) do
        local m = fn(v, i)
        if m ~= nil then
            arr[to] = m
            to = to + 1
        end
    end
    for i = to, #arr do
        arr[i] = nil
    end
    return arr
end

--- Filter values in array by the given predicate.
---
--- @generic T
--- @param arr T[] array to be filtered.
--- @param fn fun(x: T, i: number): boolean predicate.
--- @return T[] filtered new array containing values for which ``fn`` returned `true`.
function ns.filterInPlace(arr, fn)
    return ns.mapInPlace(arr, function(x, i) return fn(x, i) and x or nil end)
end

--- Fold an array using the given operator.
---
--- This is equivalent to:
---
--- .. code-block:: lua
---
---    -- If array is non-empty:
---    local result = fn(initial, fn(arr[1], fn(arr[2], ...)))
---    -- If array is empty:
---    local result = initial
---
--- @generic T
--- @generic U
--- @param arr T[] array to be folded.
--- @param fn fun(lhs: U, rhs: T): U binary operator.
--- @param initial U left value for the first operation.
--- @return U result of the operation.
function ns.fold(arr, fn, initial)
    for _, x in ipairs(arr) do
        initial = fn(initial, x)
    end
    return initial
end

--- Fold an array using the given operator. If array is empty, return ``ifEmpty``.
---
--- This is equivalent to:
---
--- .. code-block:: lua
---
---    -- If array is non-empty:
---    local result = fn(arr[1], fn(arr[2], ...))
---    -- If array is empty:
---    local result = ifEmpty
---
--- @generic T
--- @generic U
--- @param arr T[] array to be folded.
--- @param fn fun(lhs: T, rhs: T): T binary operator.
--- @param ifEmpty U value that's used when array is empty.
--- @return T|U result of the operation.
function ns.foldOr(arr, fn, ifEmpty)
    local result = arr[1] or ifEmpty
    for i = 2, #arr do
        result = fn(result, arr[i])
    end
    return result
end

--- Right-fold an array using the given operator.
---
--- This is equivalent to:
---
--- .. code-block:: lua
---
---    -- If array is non-empty:
---    local result = fn(..., fn(arr[#arr - 1], fn(arr[#arr], initial)))
---    -- If array is empty:
---    local result = initial
---
--- @generic T
--- @generic U
--- @param arr T[] array to be right-folded.
--- @param fn fun(lhs: T, rhs: U): U binary operator.
--- @param initial U right value for the first operation.
--- @return U[] result of the operation.
function ns.foldR(arr, fn, initial)
    for i = #arr, 1, -1 do
        initial = fn(arr[i], initial)
    end
    return initial
end

--- Fold an array using the given operator. If array is empty, return ``ifEmpty``.
---
--- This is equivalent to:
---
--- .. code-block:: lua
---
---    -- If array is non-empty:
---    local result = fn(..., fn(arr[#arr - 2], fn(arr[#arr - 1], arr[#arr])))
---    -- If array is empty:
---    local result = ifEmpty
---
--- @generic T
--- @generic U
--- @param arr T[] array to be folded.
--- @param fn fun(lhs: T, rhs: T): T binary operator.
--- @param ifEmpty U value that's used when array is empty.
--- @return T|U result of the operation.
function ns.foldROr(arr, fn, ifEmpty)
    local result = arr[#arr] or ifEmpty
    for i = #arr - 1, 1, -1 do
        result = fn(arr[i], result)
    end
    return result
end

--- Sum numbers in an array.
---
--- @generic T, U
--- @param arr T[]
--- @param ifEmpty U
--- @return T|U
function ns.sum(arr, ifEmpty)
    return ns.foldOr(arr, function(a, b) return a + b end, ifEmpty)
end

--- Check that two arrays are equal.
---
--- That is, if ``a`` and ``b`` are tables, and ``a`` does not have
--- a custom equality operator, then they should contain the same number of elements,
--- and their values should be equal when compared by the ``==`` operator.
---
--- Otherwise, if ``a`` or ``b`` is not a table, or ``a`` has custom equality operator,
--- then this function is equivalent to ``a == b``.
---
--- @param a any[] left array.
--- @param b any[] right array.
--- @return boolean
function ns.eq(a, b)
    return common.eq(a, b, ipairs)
end

return ns
