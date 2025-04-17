--- Helpers for working with arrays and tables.
---
--- !doctype module
--- @class ammcore._util.array
local ns = {}

--- Check that two tables contain the same keys and values.
---
--- @param a table
--- @param b table
--- @return boolean
function ns.eq(a, b)
    if rawequal(a, b) then return true end
    if #a ~= #b then return false end
    for i, v in pairs(a) do
        if v ~= b[i] then return false end
    end
    for i, _ in pairs(b) do
        if not a[i] then return false end
    end
    return true
end

--- Check that two tables are deep-equal.
---
--- That is, if two values are tables, and the first table's metatable does not defined
--- a custom equality operator, then they should contain the same set of keys,
--- and their values should themselves be deep-equal; otherwise, they should be equal
--- when compared by the ``==`` operator.
---
--- @param a table
--- @param b table
--- @return boolean
function ns.deepEq(a, b)
    if type(a) == "table" and type(b) == "table" then
        if rawequal(a, b) then
            return true
        end
        local mt = getmetatable(a)
        if mt and mt.__eq then
            return mt.__eq(a, b)
        end
        if #a ~= #b then return false end
        for i, v in pairs(a) do
            if not ns.deepEq(v, b[i]) then return false end
        end
        for i, _ in pairs(b) do
            if not a[i] then return false end
        end
        return true
    else
        return a == b
    end
end

--- Check that all values in the table are not `nil`.
---
--- @param t table
--- @return boolean
function ns.all(t)
    for _, v in pairs(t) do
        if not v then return false end
    end
    return true
end

--- Check that any values in the table are true.
---
--- @param t table
--- @return boolean
function ns.any(t)
    for _, v in pairs(t) do
        if v then return true end
    end
    return false
end

--- Insert values from one array into another.
---
--- @generic T
--- @param to T[] array to be modified.
--- @param from T[] array to be copied.
--- @return T[] to reference to the ``to`` array.
function ns.insertMany(to, from)
    for _, v in ipairs(from) do
        table.insert(to, v)
    end
    return to
end

--- Insert values from one table into another.
---
--- @generic T
--- @generic U
--- @param to table<T, U> table to be modified.
--- @param from table<T, U> table to be copied.
--- @param merger nil | fun(l: U, r: U): U function used to merge values from left and right table.
--- @return table<T, U> to to reference to the ``to`` table.
function ns.insertTable(to, from, merger)
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

--- Apply function to every element of an array.
---
--- @generic T
--- @generic U
--- @param arr T[] array to be mapped.
--- @param fn fun(x: T): U mapper.
--- @return U[] mapped new array containing result of applying ``fn`` to every element in ``arr``.
function ns.map(arr, fn)
    local res = {}
    for _, v in ipairs(arr) do
        table.insert(res, fn(v))
    end
    return res
end

--- Apply function to every element of an array, placing results back to the same array.
---
--- @generic T
--- @param arr T[] array to be mapped.
--- @param fn fun(..., x: T): T mapper.
--- @param ... any additional arguments to mapper.
--- @return T[] mapped new array containing result of applying ``fn`` to every element in ``arr``.
function ns.mapInPlace(arr, fn, ...)
    for i, v in ipairs(arr) do
        arr[i] = fn(..., v)
    end
    return arr
end

--- Apply function to every element of an array and filter out all `nil` values.
---
--- @generic T
--- @generic U
--- @param arr T[] array to be mapped.
--- @param fn fun(..., x: T): U? mapper.
--- @param ... any additional arguments to mapper.
--- @return U[] mapped new array containing result of applying ``fn`` to every element in ``arr``, excluding all `nil` elements.
function ns.filterMap(arr, fn, ...)
    local res = {}
    for _, v in ipairs(arr) do
        local m = fn(..., v)
        if m then table.insert(res, m) end
    end
    return res
end

--- Fold an array using the given operator.
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

--- Right-fold an array using the given operator.
---
--- @generic T
--- @generic U
--- @param arr T[] array to be right-folded.
--- @param fn fun(lhs: T, rhs: U): U binary operator.
--- @param initial U right value for the first operation.
--- @return U[] result of the operation.
function ns.rfold(arr, fn, initial)
    for i = #arr, 1, -1 do
        initial = fn(arr[i], initial)
    end
    return initial
end

--- Sum numbers in an array.
---
--- @param arr number[]
--- @return number
function ns.sum(arr)
    return ns.fold(arr, function(a, b) return a + b end, 0)
end

return ns
