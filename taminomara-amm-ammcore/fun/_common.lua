--- !doc private
--- !doctype module
--- @class ammcore.fun._common
local ns = {}

function ns.all(t, pred, iter)
    pred = pred or function(x) return x end
    for i, v in iter(t) do
        if not pred(v, i) then return false end
    end
    return true
end

function ns.any(t, pred, iter)
    pred = pred or function(x) return x end
    for i, v in iter(t) do
        if pred(v, i) then return true end
    end
    return false
end

function ns.eq(a, b, iter, getter)
    if rawequal(a, b) then return true end
    if type(a) == "table" and type(b) == "table" then
        local mt = getmetatable(a)
        if mt and mt.__eq then
            return mt.__eq(a, b)
        end
        if #a ~= #b then return false end
        if getter then
            for k, v in iter(a) do
                if getter(v, k) ~= getter(b[k], k) then return false end
            end
        else
            for k, v in iter(a) do
                if v ~= b[k] then return false end
            end
        end
        for k, _ in iter(b) do
            if a[k] == nil then return false end
        end
        return true
    else
        return a == b
    end
end

function ns.deepEq(a, b, iter)
    if rawequal(a, b) then return true end
    if type(a) == "table" and type(b) == "table" then
        local mt = getmetatable(a)
        if mt and mt.__eq then
            return mt.__eq(a, b)
        end
        if #a ~= #b then return false end
        for k, v in iter(a) do
            if not ns.deepEq(v, b[k], iter) then return false end
        end
        for k, _ in iter(b) do
            if a[k] == nil then return false end
        end
        return true
    else
        return a == b
    end
end

return ns
