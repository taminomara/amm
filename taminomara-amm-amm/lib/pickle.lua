local class = require "ammcore.class"

--- A module for serializing and deserializing lua values.
local pickle = {}

local structPicklers
local itemPicklers

--- Values that can be serialized.
---
--- @alias pickle.Ser
--- | nil
--- | boolean
--- | number
--- | string
--- | pickle.Ser[]
--- | table<pickle.Ser, pickle.Ser>
--- | ItemType-Class
--- | Vector
--- | Vector2D
--- | Color
--- | Rotator
--- | Vector4
--- | Margin
--- | Item
--- | ItemStack
--- | ItemAmount

local Pickler = class.create("Pickler")

function Pickler:New()
    self = class.Base.New(self)
    self._refs = {}
    self._out = ""
    return self
end

function Pickler:result()
    return self._out
end

function Pickler:pickle(root)
    local ty = type(root)
    if ty == "nil" then
        self._out = self._out .. "nil"
    elseif ty == "string" then
        self._out = self._out .. string.format("%q", root)
    elseif ty == "number" then
        self._out = self._out .. string.format("%q", root)
    elseif ty == "boolean" then
        self._out = self._out .. string.format("%q", root)
    elseif ty == "table" then
        if self._refs[root] then
            error("Cyclical structs not supported")
        end
        self._refs[root] = true
        self._out = self._out .. "{"
        for k, v in pairs(root) do
            self._out = self._out .. "["
            self:pickle(k)
            self._out = self._out .. "]="
            self:pickle(v)
            self._out = self._out .. ","
        end
        self._out = self._out .. "}"
    elseif ty == "userdata" then
        local name = tostring(root):match("^.-<(.*)>$")
        if structPicklers[name] then
            self._out = self._out .. "{__amm_s=\"" .. name .. "\",v={"
            structPicklers[name].ser(root, self)
            self._out = self._out .. "}}"
        elseif name == "ItemType" then
            self._out = self._out .. "{__amm_i=\"" .. root.internalName .. "\"}"
        else
            error("Can't pickle this value: " .. tostring(root))
        end
    else
        error("Pickling a " .. type(root) .. " is not supported: " .. tostring(root))
    end
end

--- Serialize a lua table into string.
---
--- @param t pickle.Ser
--- @return string
function pickle.pickle(t)
    local p = Pickler:New()
    p:pickle(t)
    return p:result()
end

--- @param root pickle.Ser
--- @return pickle.Ser
local function process(root)
    if type(root) == "table" then
        if root["__amm_s"] then
            local pk = structPicklers[root["__amm_s"]]
            if not pk then error("Unknown struct " .. tostring(root["__amm_s"])) end
            return pk.de(process(root["v"]))
        elseif root["__amm_i"] then
            local res = itemPicklers[root["__amm_i"]]
            if not res then error("Unknown singletone " .. tostring(root["__amm_i"])) end
            return res
        else
            for k, v in pairs(root) do
                root[k] = process(v)
            end
            return root
        end
    else
        return root
    end
end

--- Load a lua table from string.
---
--- @param s string
--- @return pickle.Ser
function pickle.unpickle(s)
    if type(s) ~= "string" then error("Can't unpickle a " .. type(s) .. ", only strings") end
    local gen = load("return " .. s, "<pickled data>", "bt", {})
    if not gen then error("Unpickling failed") end
    return process(gen())
end

local function structSerializer(ctor, fields)
    return {
        ser = function(root, pickler)
            for _, k in ipairs(fields) do
                pickler._out = pickler._out .. "["
                pickler:pickle(k)
                pickler._out = pickler._out .. "]="
                pickler:pickle(root[k])
                pickler._out = pickler._out .. ","
            end
        end,
        de = ctor,
    }
end

structPicklers = {
    Vector = structSerializer(structs.Vector, { "x", "y", "z" }),
    Vector2D = structSerializer(structs.Vector2D, { "x", "y" }),
    Color = structSerializer(structs.Color, { "r", "g", "b", "a" }),
    Rotator = structSerializer(structs.Rotator, { "pitch", "yaw", "roll" }),
    Vector4 = structSerializer(structs.Vector4, { "x", "y", "z", "w" }),
    Margin = structSerializer(structs.Margin, { "left", "right", "top", "bottom" }),
    Item = structSerializer(structs.Item, { "type" }),
    ItemStack = structSerializer(structs.ItemStack, { "count", "item" }),
    ItemAmount = structSerializer(structs.ItemAmount, { "amount", "type" }),
}

itemPicklers = {}

--- @diagnostic disable-next-line: undefined-global
for _, item in pairs(getItems() --[[ @as table<string, ItemType-Class> ]]) do
    itemPicklers[item.internalName] = item
end

return pickle
