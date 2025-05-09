local dom = require "ammgui.dom"
local fun = require "ammcore.fun"
local api= require "ammgui.api"

--- Allows creating resize-able split-panels.
---
--- !doctype module
--- @class ammgui.dom.resize
local ns = {}

local function calculateMaxDelta(i, delta, dragState)
    local sizeBefore, minSizeBefore, maxSizeBefore = 0, 0, 0
    do
        for j = i, 1, -1 do
            sizeBefore = sizeBefore + dragState[j].size
            minSizeBefore = minSizeBefore + dragState[j].minSize
            maxSizeBefore = maxSizeBefore + dragState[j].maxSize
        end
    end
    local newSizeBefore = math.max(minSizeBefore, math.min(
        maxSizeBefore, sizeBefore + delta
    ))
    local sizeBeforeChange = sizeBefore - newSizeBefore

    local sizeAfter, minSizeAfter, maxSizeAfter = 0, 0, 0
    do
        for j = i + 1, #dragState do
            sizeAfter = sizeAfter + dragState[j].size
            minSizeAfter = minSizeAfter + dragState[j].minSize
            maxSizeAfter = maxSizeAfter + dragState[j].maxSize
        end
    end
    local newSizeAfter = math.max(minSizeAfter, math.min(
        maxSizeAfter, sizeAfter - delta
    ))
    local sizeAfterChange = sizeAfter - newSizeAfter

    local maxPossibleDelta = math.min(
        math.abs(sizeBeforeChange), math.abs(sizeAfterChange))
    if delta < 0 then maxPossibleDelta = -maxPossibleDelta end

    return maxPossibleDelta
end

--- @class ammgui.dom.resize.ResizeParams: ammgui.dom.FunctionalParamsWithChildren
--- @field direction ammgui.css.rule.FlexDirectionValue?
--- @field class string|string[]?

--- @param ctx ammgui.Context
--- @param params ammgui.dom.resize.ResizeParams
--- @return ammgui.dom.AnyNode
local function _split(ctx, params)
    local dragState = ctx:useRef(nil)

    --- @type ammgui.Ref<ammgui.Ref<ammgui.NodeApi?>[]>
    local refs = ctx:useRef({})
    refs.current = {}

    local class = params.class
    if not class then
        class = "__amm_resize__split"
    elseif type(class) == "string" then
        class = { class, "__amm_resize__split" }
    else
        class = fun.a.extend({ "__amm_resize__split" }, class)
    end

    local flex = dom.flex {
        class = class,
        style = { flexDirection = params.direction },
    }

    for i, node in ipairs(params) do
        local ref = api.Ref:New(nil)
        table.insert(refs.current, ref)
        table.insert(flex, dom.list { node, key = node.key, ref = ref })
        if i < #params then
            table.insert(
                flex,
                dom.div {
                    class = "__amm_resize__handle",
                    onDragStart = function()
                        dragState.current = {}
                        for _, ref in ipairs(refs.current) do
                            table.insert(dragState.current, {
                                size = assert(ref.current):getBorderBoxSize().y,
                                minSize = assert(ref.current):getBorderBoxMinSize().y,
                                maxSize = assert(ref.current):getBorderBoxMaxSize().y,
                            })
                        end
                    end,
                    onDrag = function(pos, origin)
                        local delta = (pos - origin).y
                        local maxPossibleDelta = calculateMaxDelta(i, delta, assert(dragState.current))

                        do
                            local deltaLeft = maxPossibleDelta
                            for j = i, 1, -1 do
                                local newSize = math.max(
                                    dragState.current[j].minSize, math.min(
                                        dragState.current[j].size + deltaLeft, dragState.current[j].maxSize))
                                local sizeChange = dragState.current[j].size - newSize
                                deltaLeft = deltaLeft + sizeChange
                                assert(refs.current[j].current):setInlineCss { flexBasis = newSize }
                            end
                        end
                        do
                            local deltaLeft = -maxPossibleDelta
                            for j = i + 1, #refs.current do
                                local newSize = math.max(
                                    dragState.current[j].minSize, math.min(
                                        dragState.current[j].size + deltaLeft, dragState.current[j].maxSize))
                                local sizeChange = dragState.current[j].size - newSize
                                deltaLeft = deltaLeft + sizeChange
                                assert(refs.current[j].current):setInlineCss { flexBasis = newSize }
                            end
                        end
                    end,
                }
            )
        end
    end

    return flex
end

--- Make a resize-able split-panel.
---
--- Pass an array of block nodes as a parameter. Each node becomes
--- a panel that can be resized. Technically, all panels are added into a flex
--- element, and resizing controls their ``flexBasis``. You can control how much
--- each panel can be resized by setting its ``min-height``, ``max-height``,
--- ``min-width``, and ``max-width``.
---
--- By default, panels are stacked vertically; pass ``direction`` to control split's
--- direction. Pass ``class`` to add a class to the outer-most flex element.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    local split = dom.Split {
---        direction = "row",
---        class = "my-split",
---        dom.scroll { ... }, -- panel 1
---        dom.scroll { ... }, -- panel 2
---    }
ns.Split = dom.Functional(_split)

return ns
