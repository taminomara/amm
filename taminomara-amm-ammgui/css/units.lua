--- Helpers for working with CSS units.
---
--- !doctype module
--- @class ammgui.css.units
local ns = {}

--- Create a `px` value.
---
--- @param x number
--- @return [ number, "px" ]
function ns.px(x)
    return { x, "px" }
end

--- Create a `pt` value.
---
--- @param x number
--- @return [ number, "pt" ]
function ns.pt(x)
    return { x, "pt" }
end

--- Create a `pc` value.
---
--- @param x number
--- @return [ number, "pc" ]
function ns.pc(x)
    return { x, "pc" }
end

--- Create a `Q` value.
---
--- @param x number
--- @return [ number, "Q" ]
function ns.Q(x)
    return { x, "Q" }
end

--- Create a `mm` value.
---
--- @param x number
--- @return [ number, "mm" ]
function ns.mm(x)
    return { x, "mm" }
end

--- Create a `cm` value.
---
--- @param x number
--- @return [ number, "cm" ]
function ns.cm(x)
    return { x, "cm" }
end

--- Create a `m` value.
---
--- @param x number
--- @return [ number, "m" ]
function ns.m(x)
    return { x, "m" }
end

--- Create a `in` value.
---
--- @param x number
--- @return [ number, "in" ]
function ns.inch(x)
    return { x, "in" }
end

--- Create a `em` value.
---
--- @param x number
--- @return [ number, "em" ]
function ns.em(x)
    return { x, "em" }
end

--- Create a `rem` value.
---
--- @param x number
--- @return [ number, "rem" ]
function ns.rem(x)
    return { x, "rem" }
end

--- Create a `vw` value.
---
--- @param x number
--- @return [ number, "vw" ]
function ns.vw(x)
    return { x, "vw" }
end

--- Create a `vh` value.
---
--- @param x number
--- @return [ number, "vh" ]
function ns.vh(x)
    return { x, "vh" }
end

--- Create a `vmin` value.
---
--- @param x number
--- @return [ number, "vmin" ]
function ns.vmin(x)
    return { x, "vmin" }
end

--- Create a `vmax` value.
---
--- @param x number
--- @return [ number, "vmax" ]
function ns.vmax(x)
    return { x, "vmax" }
end

--- Create a `%` value.
---
--- @param x number
--- @return [ number, "%" ]
function ns.percent(x)
    return { x, "%" }
end

return ns
