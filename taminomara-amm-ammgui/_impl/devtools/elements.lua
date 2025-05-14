local dom = require "ammgui.dom"
local log = require "ammcore.log"
local u = require "ammgui.css.units"
local diagram = require "ammgui._impl.devtools.diagram"
local resolved = require "ammgui._impl.css.resolved"
local resize = require "ammgui.dom.resize"
local tabs = require "ammgui.dom.tabs"
local fun = require "ammcore.fun"

--- !doctype module
--- @class ammgui._impl.devtools.elements
local ns = {}

--- @class ammgui._impl.devtools.Element
--- @field id ammgui._impl.id.EventListenerId
--- @field name string?
--- @field inlineContent string?
--- @field classes string[]
--- @field pseudoclasses string[]
--- @field css ammgui._impl.css.resolved.Resolved
--- @field children ammgui._impl.devtools.Element[]
--- @field baseLayout ammgui._impl.layout.blockBase.BaseLayout?
--- @field usedLayout ammgui._impl.layout.blockBase.UsedLayout?

--- @class ammgui._impl.devtools._ElementParams
--- @field root ammgui._impl.devtools.Element
--- @field depth number
--- @field expandedIds table<ammgui._impl.id.EventListenerId, true>
--- @field tempExpandedIds table<ammgui._impl.id.EventListenerId, true>
--- @field selectedId ammgui._impl.id.EventListenerId?
--- @field preSelectedId ammgui._impl.id.EventListenerId?
--- @field setSelectedId fun(id: ammgui._impl.id.EventListenerId?)
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)
--- @field setExpandedId fun(id: ammgui._impl.id.EventListenerId, e: boolean)

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._ElementParams
--- @return ammgui.dom.AnyNode
local function _element(ctx, params)
    local clickTime = ctx:useRef(0)

    local elementAnnotations = dom.list {}
    do
        local sep = (params.root.name and params.root.name:len() > 0) and " " or ""
        if #params.root.classes > 0 then
            table.insert(elementAnnotations, sep)
            sep = " "
            table.insert(elementAnnotations, dom.em { [[class="]] })
            table.insert(elementAnnotations, table.concat(params.root.classes, " "))
            table.insert(elementAnnotations, dom.em { [["]] })
        end
        if #params.root.pseudoclasses > 0 then
            table.insert(elementAnnotations, sep)
            sep = " "
            table.insert(elementAnnotations, dom.em { table.concat(params.root.pseudoclasses, " ") })
        end
    end

    local elementData
    do
        if params.root.name then
            elementData = dom.list {
                dom.em { "<" },
                params.root.name,
                elementAnnotations,
                dom.em { ">" },
            }
        else
            elementData = log.pprint(params.root.inlineContent, true)
        end
    end

    local selected = params.root.id == params.selectedId
    local preSelected = params.root.id == params.preSelectedId
    local expanded = params.expandedIds[params.root.id] or params.tempExpandedIds[params.root.id] or false

    return dom.div {
        class = {
            "devtools__element-title",
            expanded and "devtools__element-title__expanded",
            selected and "devtools__element-title__selected",
            preSelected and "devtools__element-title__pre-selected",
        },
        dom.div {
            style = { paddingLeft = u.rem(params.depth * 0.5) },
            dom.span {
                class = "devtools__element-arrow",
                #params.root.children > 0 and
                (expanded and "▼" or "▶")
                or "-",
                onClick = function()
                    params.setSelectedId(params.root.id)
                    params.setExpandedId(params.root.id, not expanded)
                    return false
                end,
            },
            " ",
            elementData,
        },
        onMouseEnter = function()
            params.setHighlightedId(params.root.id, true, true, true, true)
        end,
        onMouseExit = function()
            params.setHighlightedId(nil)
        end,
        onClick = function()
            params.setSelectedId(params.root.id)
            local now = computer.millis()
            if now - clickTime.current <= 300 then
                params.setExpandedId(params.root.id, not expanded)
            end
            clickTime.current = now
        end,
    }
end
local element = dom.Functional(_element)

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._ElementParams
--- @return ammgui.dom.AnyNode
local function _elementTree(ctx, params)
    local body = dom.section {}

    local function visit(root, depth)
        table.insert(body, element {
            key = root.id,
            root = root,
            depth = depth,
            expandedIds = params.expandedIds,
            tempExpandedIds = params.tempExpandedIds,
            selectedId = params.selectedId,
            preSelectedId = params.preSelectedId,
            setSelectedId = params.setSelectedId,
            setHighlightedId = params.setHighlightedId,
            setExpandedId = params.setExpandedId,
        })

        if params.expandedIds[root.id] or params.tempExpandedIds[root.id] then
            for _, child in ipairs(root.children) do
                visit(child, depth + 1)
            end
        end
    end

    if params.root then
        visit(params.root, 0)
    end

    return body
end
local elementTree = dom.Functional(_elementTree)

--- @class ammgui._impl.devtools._LayoutDiagramParams
--- @field root ammgui._impl.devtools.Element?
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._LayoutDiagramParams
--- @return ammgui.dom.AnyNode
local function _layoutDiagram(ctx, params)
    if params.root and params.root.baseLayout and params.root.usedLayout then
        local baseLayout = params.root.baseLayout ---@cast baseLayout -nil
        local usedLayout = params.root.usedLayout ---@cast usedLayout -nil

        local outline = baseLayout.outlineWidth

        local paddingTop = baseLayout.paddingTop
        local paddingBottom = baseLayout.paddingBottom
        local paddingLeft = baseLayout.paddingLeft
        local paddingRight = baseLayout.paddingRight

        local marginTop = baseLayout.marginTop or usedLayout.effectiveVerticalMargin.x
        local marginBottom = baseLayout.marginBottom or usedLayout.effectiveVerticalMargin.y
        local marginLeft = baseLayout.marginLeft or usedLayout.effectiveHorizontalMargin.x
        local marginRight = baseLayout.marginRight or usedLayout.effectiveHorizontalMargin.y

        local contentSize = usedLayout.resolvedContentSize

        return dom.section {
            diagram.layoutDiagram {
                class = "devtools__layout-diagram",
                highlightedId = params.root.id,
                setHighlightedId = params.setHighlightedId,
                outline = outline,
                paddingTop = paddingTop,
                paddingBottom = paddingBottom,
                paddingLeft = paddingLeft,
                paddingRight = paddingRight,
                marginTop = marginTop,
                marginBottom = marginBottom,
                marginLeft = marginLeft,
                marginRight = marginRight,
                contentSize = contentSize,
            },
        }
    else
        return dom.list {}
    end
end
local layoutDiagram = dom.Memo(dom.Functional(_layoutDiagram))

--- @param v any
--- @return ammgui.dom.AnyNode
local function pprintValue(v)
    if type(v) == "table" and #v == 2 and type(v[1]) == "number" and type(v[2]) == "string" then
        return dom.span {
            tostring(v[1]),
            dom.em { v[2] },
        }
    elseif type(v) == "userdata" and tostring(v) == "Struct<Color>" then
        --- @cast v Color
        return dom.span {
            dom.span {
                style = {
                    backgroundColor = v,
                    color = "transparent",
                    outlineWidth = 1,
                    lineHeight = 1,
                    fontSize = u.rem(0.7),
                    paddingLeft = u.rem(0.3),
                    marginRight = u.rem(0.2),
                },
                " ",
            },
            dom.em { "#" },
            string.format(
                "%02x%02x%02x%02x",
                math.floor(v.r * 0xff),
                math.floor(v.g * 0xff),
                math.floor(v.b * 0xff),
                math.floor(v.a * 0xff)
            ),
        }
    else
        return log.pprint(v, true)
    end
end

--- @class ammgui._impl.devtools._ElementStyleParams
--- @field root ammgui._impl.devtools.Element?
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)

--- @param cssRule ammgui._impl.css.resolved.CompiledRule
--- @param usedSelector ammgui.css.selector.Selector
--- @return ammgui.dom.AnyNode
local function selectors(cssRule, usedSelector)
    local body = dom.div { class = "devtools__selector-list" } -- TODO: ul/li?

    if cssRule.compiledSelectors and #cssRule.compiledSelectors > 0 then
        for _, selector in ipairs(cssRule.compiledSelectors) do
            table.insert(body, dom.div {
                key = selector,
                class = {
                    "devtools__selector-list-element",
                    (usedSelector and selector ~= usedSelector) and "devtools__selector-list-element__unused",
                },
                selector:repr(),
                dom.small {
                    selector.layer < 0 and dom.dim { " theme" },
                    selector.layer > 0 and dom.strong { " layer ", tostring(selector.layer) },
                    cssRule.loc ~= nil and dom.dim { " @ ", cssRule.loc },
                },
            })
        end
    else
        table.insert(body, dom.div {
            key = "inline",
            class = "devtools__selector-list-element",
            "<inline>",
            dom.small {
                cssRule.loc ~= nil and dom.dim { " @ ", cssRule.loc },
            },
        })
    end

    return body
end

--- @param cssRule ammgui._impl.css.resolved.CompiledRule
--- @param keys string[]
--- @param seenProperties table<string, true>
--- @return ammgui.dom.AnyNode
local function ruleData(cssRule, keys, seenProperties)
    local body = dom.div { class = "devtools__property-list" }

    for _, k in ipairs(keys) do
        table.insert(body, dom.div {
            key = k,
            class = {
                "devtools__property-list-element",
                seenProperties[k] and "devtools__property-list-element__unused",
            },
            dom.em { k, " = " },
            pprintValue(cssRule[k]),
        })
        seenProperties[k] = true
    end

    return body
end

--- @param ctx ammgui.Context
--- @param params { css: ammgui._impl.css.resolved.Resolved }
--- @return ammgui.dom.AnyNode
local function _elementStyle(ctx, params)
    local body = dom.list {}

    local context = params.css.context
    local contextSelectors = params.css.contextSelectors
    local seenProperties = {}
    for i = #context, 1, -1 do
        local cssRule = context[i]
        local keys = resolved.getRuleKeys(cssRule)
        if #keys > 0 then
            table.insert(body, dom.section {
                class = "devtools__rule",
                key = cssRule,
                selectors(cssRule, contextSelectors[i]),
                dom.div { dom.dim { "{" } },
                ruleData(cssRule, keys, seenProperties),
                dom.div { dom.dim { "}" } },
            })
        end
    end

    return body
end
local elementStyle = dom.Memo(dom.Functional(_elementStyle))

--- @param ctx ammgui.Context
--- @param params { name: string, value: any, path: { selector: ammgui.css.selector.Selector?, loc: string?, value: any, origValue: any }[] }
--- @return ammgui.dom.AnyNode
local function _propTrace(ctx, params)
    local clickTime = ctx:useRef(0)
    local expanded, setExpanded = ctx:useState(false)
    local isOrig, setIsOrig = ctx:useState(true)

    return dom.div {
        class = "devtools__computed",
        dom.div {
            class = "devtools__computed-header",
            dom.span {
                expanded and "▼" or "▶",
                onClick = function()
                    setExpanded(not expanded)
                    return false
                end,
            },
            " ",
            dom.em { params.name, " = " },
            pprintValue(params.value),

            onClick = function()
                local now = computer.millis()
                if now - clickTime.current <= 300 then
                    setExpanded(not expanded)
                end
                clickTime.current = now
            end,
        },
        expanded and dom.div {
            class = "devtools__computed-list",
            dom.map(params.path, function(x)
                return dom.div {
                    class = {
                        "devtools__computed-list-element",
                        (x.selector == nil or x.selector.layer < 0) and "devtools__computed-list-element__unused",
                    },
                    x.selector ~= nil and dom.div {
                        x.selector:repr(),
                        dom.small {
                            x.selector.layer < 0 and dom.dim { " theme" },
                            x.selector.layer > 0 and dom.strong { " layer ", tostring(x.selector.layer) },
                            x.loc ~= nil and dom.dim { " @ ", x.loc },
                        },
                    },
                    dom.div {
                        class = "devtools__computed-list-value",
                        dom.em { "→ " },
                        isOrig and (
                            dom.list { pprintValue(x.origValue) }
                        ) or (
                            dom.list { pprintValue(x.value), dom.small { dom.dim { " (computed)" } } }
                        ),
                        onClick = function()
                            setIsOrig(not isOrig)
                        end,
                    },
                }
            end),
        },
    }
end
local propTrace = dom.Memo(dom.Functional(_propTrace))

--- @param ctx ammgui.Context
--- @param params { css: ammgui._impl.css.resolved.Resolved }
--- @return ammgui.dom.AnyNode
local function _elementComputed(ctx, params)
    local body = dom.section {}

    local css = params.css
    local context = params.css.context

    local setProperties = fun.t.copy(resolved.getInheritedProperties())
    for _, cssRule in ipairs(context) do
        fun.a.extend(setProperties, resolved.getRuleKeys(cssRule))
    end
    table.sort(setProperties)

    local seenProperties = {}
    for _, name in ipairs(setProperties) do
        if not seenProperties[name] then
            seenProperties[name] = true

            local value, path = css:getTrace(name)

            if #path > 0 then
                table.insert(body, propTrace {
                    key = name,
                    name = name,
                    value = value,
                    path = path,
                })
            end
        end
    end

    return body
end
local elementComputed = dom.Memo(dom.Functional(_elementComputed))

--- @param root ammgui._impl.devtools.Element
--- @param id ammgui._impl.id.EventListenerId?
--- @param tempExpandedIds table<ammgui._impl.id.EventListenerId, true>
--- @return ammgui._impl.devtools.Element?
local function findSelected(root, id, tempExpandedIds)
    if not id then
        return nil
    end
    if root.id == id then
        return root
    else
        for _, child in ipairs(root.children) do
            local selected = findSelected(child, id, tempExpandedIds)
            if selected then
                tempExpandedIds[root.id] = true
                return selected
            end
        end
    end
    return nil
end

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._PanelParams
--- @return ammgui.dom.AnyNode
local _elementsPage = function(ctx, params)
    local expandedIds, setExpanded = ctx:useReducer(
        setmetatable({}, { __mode = "kv" }),
        function(t, id, set)
            t[id] = set or nil
            return t
        end
    )

    local selectedRoot = findSelected(params.root, params.selectedId, expandedIds)
    local tempExpandedIds = {}
    findSelected(params.root, params.preSelectedId, tempExpandedIds)

    return resize.Split {
        direction = "column",
        {
            dom.div {
                class = "devtools__page",
                elementTree {
                    root = params.root,
                    selectedId = params.selectedId,
                    preSelectedId = params.preSelectedId,
                    expandedIds = expandedIds,
                    tempExpandedIds = tempExpandedIds,
                    setSelectedId = params.setSelectedId,
                    setExpandedId = setExpanded,
                    setHighlightedId = params.setHighlightedId,
                    depth = 0,
                },
            },
        },
        {
            selectedRoot ~= nil and tabs.Tabs {
                fullHeight = true,
                {
                    title = "Styles",
                    key = 1,
                    dom.div {
                        class = "devtools__page",
                        layoutDiagram {
                            root = selectedRoot,
                            setHighlightedId = params.setHighlightedId,
                        },
                        elementStyle { css = selectedRoot.css },
                    },
                },
                {
                    title = "Computed",
                    key = 2,
                    dom.div {
                        class = "devtools__page",
                        layoutDiagram {
                            root = selectedRoot,
                            setHighlightedId = params.setHighlightedId,
                        },
                        elementComputed { css = selectedRoot.css },
                    },
                },
            },
        },
    }
end

ns.elementsPage = dom.Memo(dom.Functional(_elementsPage))

return ns
