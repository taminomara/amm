--- @namespace ammcore.fun._common

local ns = {}

--- @generic T, E
--- @param t T
--- @param pred? fun(e: E, i: integer): any
--- @param iter fun(t: T): fun(t: T): integer, E
--- @return boolean
function ns.all(t, pred, iter)
    if pred then
        for i, v in iter(t) do
            if not pred(v, i) then
                return false
            end
        end
    else
        for _, v in iter(t) do
            if not v then
                return false
            end
        end
    end
    return true
end

--- @generic T, E
--- @param t T
--- @param pred? fun(e: E, i: integer): any
--- @param iter fun(t: T): fun(t: T): integer, E
--- @return boolean
function ns.any(t, pred, iter)
    if pred then
        for i, v in iter(t) do
            if pred(v, i) then
                return true
            end
        end
    else
        for _, v in iter(t) do
            if v then
                return true
            end
        end
    end
    return false
end

--- @generic K, V
--- @param a table<K, V>
--- @param b table<K, V>
--- @param iter fun(t: table<K, V>): fun(t: table<K, V>): K, V
--- @param getter? fun(v: V, k: K): any
--- @return boolean
function ns.eq(a, b, iter, getter)
    if rawequal(a, b) then
        return true
    end
    if type(a) == "table" and type(b) == "table" then
        local mt = getmetatable(a)
        if mt and mt.__eq then
            return mt.__eq(a, b)
        end
        if #a ~= #b then
            return false
        end
        if getter then
            for k, v in iter(a) do
                if getter(v, k) ~= getter(b[k], k) then
                    return false
                end
            end
        else
            for k, v in iter(a) do
                if v ~= b[k] then
                    return false
                end
            end
        end
        for k, _ in iter(b) do
            if a[k] == nil then
                return false
            end
        end
        return true
    else
        return a == b
    end
end

--- @generic K, V
--- @param a table<K, V>|any
--- @param b table<K, V>|any
--- @param iter fun(t: table<K, V>): fun(t: table<K, V>): K, V
--- @return boolean
function ns.deepEq(a, b, iter)
    if rawequal(a, b) then
        return true
    end
    if type(a) == "table" and type(b) == "table" then
        local mt = getmetatable(a)
        if mt and mt.__eq then
            return mt.__eq(a, b)
        end
        if #a ~= #b then
            return false
        end
        for k, v in iter(a) do
            if not ns.deepEq(v, b[k], iter) then
                return false
            end
        end
        for k, _ in iter(b) do
            if a[k] == nil then
                return false
            end
        end
        return true
    else
        return a == b
    end
end

return ns
