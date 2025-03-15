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
    if #a ~= #b then return false end
    for i, v in pairs(a) do
        if v ~= b[i] then return false end
    end
    for i, _ in pairs(b) do
        if not a[i] then return false end
    end
    return true
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
    merger = merger or function (l, r) return r end
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
--- @param fn fun(..., x: T): U mapper.
--- @param ... any additional arguments to mapper.
--- @return U[] mapped new array containing result of applying ``fn`` to every element in ``arr``.
function ns.map(arr, fn, ...)
    local res = {}
    for _, v in ipairs(arr) do
        table.insert(res, fn(..., v))
    end
    return res
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

return ns
