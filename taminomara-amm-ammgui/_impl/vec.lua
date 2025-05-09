local class = require "ammcore.class"

--- Vector implementation.
---
--- !doctype module
--- @class ammgui._impl.vec
local ns = {}

--- A pure lua implementation of vector with two coordinates.
---
--- At the moment, FIN's `Vector2D` has some performance issues, so we use
--- our own implementation.
---
--- Supported operations:
---
--- - adding, subtracting two vectors,
--- - multiplying, dividing by constant.
---
--- @class ammgui.Vec2: ammcore.class.Base, Vector2D
ns.Vec2 = class.create("Vec2")

--- !doctype classmethod
--- @param x number
--- @param y number
--- @return ammgui.Vec2
function ns.Vec2:New(x, y)
    self = class.Base.New(self)

    --- @type number
    self.x = x

    --- @type number
    self.y = y

    return self
end

--- Create a vector from table in-place.
---
--- The passed table becomes a vector instance.
---
--- !doctype classmethod
--- @param t { x: number, y: number }
--- @return ammgui.Vec2
function ns.Vec2:FromTable(t)
    return setmetatable(t, self.__class)
end

--- Create a vector from FIN's `Vector2D`.
---
--- !doctype classmethod
--- @param t Vector2D
--- @return ammgui.Vec2
function ns.Vec2:FromV2(t)
    return ns.Vec2:New(t.x, t.y)
end

function ns.Vec2.__add(lhs, rhs)
    return ns.Vec2:New(lhs.x + rhs.x, lhs.y + rhs.y)
end

function ns.Vec2.__sub(lhs, rhs)
    return ns.Vec2:New(lhs.x - rhs.x, lhs.y - rhs.y)
end

function ns.Vec2.__mul(lhs, rhs)
    return ns.Vec2:New(lhs.x * rhs, lhs.y * rhs)
end

function ns.Vec2.__div(lhs, rhs)
    return ns.Vec2:New(lhs.x / rhs, lhs.y / rhs)
end

function ns.Vec2.__idiv(lhs, rhs)
    return ns.Vec2:New(lhs.x // rhs, lhs.y // rhs)
end

function ns.Vec2.__unm(lhs)
    return ns.Vec2:New(-lhs.x, -lhs.y)
end

function ns.Vec2.__eq(lhs, rhs)
    return lhs.x == rhs.x and lhs.y == rhs.y
end

return ns
