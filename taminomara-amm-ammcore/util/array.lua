-- Helpers for working with arrays.
local ns = {}

--- Check that two tables contain the same keys and values.
---
--- @param array1 table
--- @param array2 table
--- @return boolean
function ns.eq(array1, array2)
    if #array1 ~= #array2 then return false end
    for i, v in pairs(array1) do
        if v ~= array2[i] then return false end
    end
    for i, _ in pairs(array2) do
        if not array1[i] then return false end
    end
    return true
end

--- Check that all values in the table are true.
---
--- @param arr table
--- @return boolean
function ns.all(arr)
    for _, v in pairs(arr) do
        if not v then return false end
    end
    return true
end

--- Check that any values in the table are true.
---
--- @param arr table
--- @return boolean
function ns.any(arr)
    for _, v in pairs(arr) do
        if v then return true end
    end
    return false
end

--- Insert values from one array into another.
---
--- @generic T
--- @param t T[]
--- @param arr T[]
--- @return T[]
function ns.insertMany(t, arr)
    for _, v in ipairs(arr) do
        table.insert(t, v)
    end
    return t
end

--- Allpy function over array.
---
--- @generic T
--- @generic U
--- @param arr T[]
--- @param fn fun(..., x: T): U
--- @param ... any
--- @return U[]
function ns.map(arr, fn, ...)
    local res = {}
    for _, v in ipairs(arr) do
        table.insert(res, fn(..., v))
    end
    return res
end

return ns
