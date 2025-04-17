local dom = require "ammgui.dom"
local array = require "ammcore._util.array"
local log = require "ammcore.log"

--- Resize boxes.
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

--- @param ctx ammgui.dom.Context
--- @param params { direction: ammgui.css.rule.FlexDirectionValue?, class: string|string[]?, [integer]: ammgui.dom.block.Node }
--- @return ammgui.dom.block.Node
local function _split(ctx, params)
    local dragState = ctx:useRef(nil)

    local class = params.class
    if not class then
        class = "__amm_resize__split"
    elseif type(class) == "string" then
        class = { class, "__amm_resize__split" }
    else
        class = array.insertMany({ "__amm_resize__split" }, class)
    end

    local flex = dom.flex {
        class = class,
        style = { flexDirection = params.direction },
    }

    --- @type ammgui.component.block.func.Ref<ammgui.component.block.Component?>[]
    local refs = {}

    for i, node in ipairs(params) do
        node.ref = ctx:useRef(nil)
        table.insert(refs, node.ref)
        table.insert(flex, node)
        if i < #params then
            table.insert(
                flex,
                dom.div {
                    class = "__amm_resize__handle",
                    onDragStart = function()
                        dragState.current = {}
                        for _, ref in ipairs(refs) do
                            local borderBoxAdjustment =
                                assert(ref.current).usedLayout.resolvedBorderBoxSize.y
                                - assert(ref.current).usedLayout.resolvedContentSize.y
                            table.insert(dragState.current, {
                                size = assert(ref.current).usedLayout.resolvedContentSize.y + borderBoxAdjustment,
                                minSize = assert(ref.current).verticalLayout.resolvedContentMinSize + borderBoxAdjustment,
                                maxSize = assert(ref.current).verticalLayout.resolvedContentMaxSize + borderBoxAdjustment,
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
                                assert(refs[j].current):setInlineCss { flexBasis = newSize }
                            end
                        end
                        do
                            local deltaLeft = -maxPossibleDelta
                            for j = i + 1, #refs do
                                local newSize = math.max(
                                    dragState.current[j].minSize, math.min(
                                        dragState.current[j].size + deltaLeft, dragState.current[j].maxSize))
                                local sizeChange = dragState.current[j].size - newSize
                                deltaLeft = deltaLeft + sizeChange
                                assert(refs[j].current):setInlineCss { flexBasis = newSize }
                            end
                        end
                    end,
                }
            )
        end
    end

    return flex
end
ns.Split = dom.functional(_split)

return ns
