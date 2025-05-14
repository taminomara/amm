local dom = require "ammgui.dom"
local fun = require "ammcore.fun"
local api = require "ammgui.api"

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

--- @class ammgui.dom.resize.SplitParams: ammgui.dom.FunctionalParams
--- @field direction ammgui.css.rule.FlexDirectionValue?
--- @field class string?
--- @field [integer] ammgui.dom.ContainerNodeParams

--- @param ctx ammgui.Context
--- @param params ammgui.dom.resize.SplitParams
--- @return ammgui.dom.AnyNode
local function _split(ctx, params)
    local dragState = ctx:useRef(nil)

    --- @type ammgui.Ref<ammgui.Ref<ammgui.NodeApi?>[]>
    local refs = ctx:useRef({})
    refs.current = {}

    local body = dom.div {
        class = { "__amm_resize__split", params.class },
        style = { flexDirection = params.direction },
    }

    for i, node in ipairs(params) do
        local ref = api.Ref:New(nil)
        table.insert(refs.current, ref)
        table.insert(body, dom.list { node --[[ @as any ]], key = node.key, ref = ref })
        if i < #params then
            table.insert(
                body,
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

    return body
end
local split = dom.Functional(_split)

--- @param params ammgui.dom.resize.SplitParams
local function makePanels(params)
    params = fun.t.copy(params)
    for i, v in ipairs(params) do
        params[i] = dom.div(fun.t.copy(v))
        params[i].class = { "__amm_resize__split-panel", v.class --[[ @as any ]] }
        if params[i].style then
            params[i].style = fun.t.copy(params[i].style)
        else
            params[i].style = {}
        end
        params[i].style.flex = nil
        params[i].style.flexGrow = 1
        params[i].style.flexShrink = 1
        params[i].style.flexBasis = 0
    end
    return params
end

--- Make a resizeable stack of split-panels.
---
--- Accepts an array of panels. Each panel is a lua table with array items representing
--- its body. Additionally, it can contain ``class`` and ``style`` properties.
---
--- Technically, all panels become scrollable DIVs in a flex container,
--- and resizing controls their ``flexBasis``. You can control how much each panel
--- can be resized by setting its ``minHeight``, ``maxHeight``, ``minWidth``,
--- and ``maxWidth``.
---
--- By default, panels are stacked horizontally; pass ``direction`` to control split's
--- direction. Pass ``class`` to add a class to the outer-most flex element.
---
--- **Example:**
---
--- .. code-block:: lua
---
---    local split = dom.Split {
---        direction = "column",
---        {
---            dom.div { ... }, -- panel 1
---        },
---        {
---            dom.div { ... }, -- panel 2
---        },
---    }
---
--- **Example: adding a non-resizeable panel.**
---
--- Here, we set ``minHeight`` and ``maxHeight`` properties for the middle panel,
--- thus disabling its sizing:
---
--- .. code-block:: lua
---
---    local split = dom.Split {
---        direction = "column",
---        {
---            "Can resize this panel."
---        },
---        {
---            style = { minHeight = u.rem(1.2), maxHeight = u.rem(1.2) },
---            "Not resizeable."
---        },
---        {
---            "Can resize this one as well."
---        },
---    }
---
--- @param params ammgui.dom.resize.SplitParams
--- @return ammgui.dom.FunctionalNode
function ns.Split(params)
    return split(makePanels(params))
end

return ns
