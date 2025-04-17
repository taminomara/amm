local stylesheet = require "ammgui.css.stylesheet"
local dom = require "ammgui.dom"
local resize = require "ammgui.dom.resize"
local log = require "ammcore.log"

--- Developer panel.
---
--- !doctype module
--- @class ammgui.devtools
local ns = {}

ns.style = stylesheet.Stylesheet:New()
    :addRule {
        "._amm__devtool__section",
        flex = { 1, 1, 0 },
        flexDirection = "column",
        minHeight = "3.8rem",
    }
    :addRule {
        "._amm__devtool__section._amm__devtool__section-collapsed",
        flex = { 0, 0, 0 },
        flexDirection = "column",
        maxHeight = "1.9rem",
        minHeight = "1.9rem",
    }
    :addRule {
        "._amm__devtool__section-heading",
        margin = 0,
        padding = { "0.2rem", "0.5rem" },
        fontSize = "1.2rem",
        backgroundColor = "#202020",
        flex = { 0, 0, "auto" },
    }
    :addRule {
        "._amm__devtool__section-content",
        flex = { 1, 1, "auto" },
    }
    :addRule {
        "._amm__devtool__section-content-inner",
        minWidth = "max-content",
    }
    :addRule {
        "._amm__devtool__element",
        fontFamily = "monospace",
    }
    :addRule {
        "._amm__devtool__element-title",
        outlineRadius = "0.3em",
        margin = { "0.2rem", "0.5rem" },
        padding = { 0, "0.5rem" },
        textWrapMode = "nowrap",
    }
    :addRule {
        "._amm__devtool__element-title:hover",
        backgroundColor = "#303030",
    }
    :addRule {
        "._amm__devtool__element__selected._amm__devtool__element-title",
        backgroundColor = "#0e2a9c",
    }
    :addRule {
        "._amm__devtool__element__selected._amm__devtool__element-title:hover",
        backgroundColor = "#1435ba",
    }
    :addRule {
        "._amm__devtool__element-tag",
        "._amm__devtool__element-param",
        "._amm__devtool__element-pseudoclasses",
        color = "#617ce6",
    }

--- @class ammgui.devtools.Element
--- @field id table
--- @field name string
--- @field classes string[]
--- @field pseudoclasses string[]
--- @field cssRules ammgui.css.rule.CompiledRule[]
--- @field children ammgui.devtools.Element[]

--- @param root ammgui.devtools.Element
local function _annotations(root)
    local sep = root.name:len() > 0 and " " or ""
    local list = dom.ilist({})
    if #root.classes > 0 then
        table.insert(list.nodes, sep)
        sep = " "
        table.insert(list.nodes, dom.span {
            class = "_amm__devtool__element-param", "class=\"",
        })
        table.insert(list.nodes, dom.span {
            class = "_amm__devtool__element-classes",
            table.concat(root.classes, " "),
        })
        table.insert(list.nodes, dom.span {
            class = "_amm__devtool__element-param", "\"",
        })
    end
    if #root.pseudoclasses > 0 then
        table.insert(list.nodes, sep)
        sep = " "
        table.insert(list.nodes, dom.span {
            class = "_amm__devtool__element-pseudoclasses",
            table.concat(root.pseudoclasses, " "),
        })
    end
    return list
end

local element
--- @param ctx ammgui.dom.Context
--- @param params { root: ammgui.devtools.Element, selected: table?, expanded: table<table, true>, setSelected: fun(if: table?), setExpanded: fun(id: table, e: boolean), highlight: fun(id: table, hl: boolean), depth: integer }
--- @return ammgui.dom.block.Node
local function _element(ctx, params)
    local lastClickTime = ctx:useRef(0)

    local selected = params.root.id == params.selected
    local expanded = params.expanded[params.root.id] or false

    local div = dom.div {
        class = "_amm__devtool__element",
        dom.div {
            class = {
                "_amm__devtool__element-title",
                expanded and "_amm__devtool__element__expanded",
                selected and "_amm__devtool__element__selected",
            },
            dom.text {
                style = { paddingLeft = params.depth * 10 },
                dom.span {
                    class = "_amm__devtool__element-arrow",
                    #params.root.children > 0 and
                    (expanded and "▼" or "▶")
                    or "-",
                },
                " ",
                dom.span { class = "_amm__devtool__element-tag", "<" },
                dom.span { class = "_amm__devtool__element-name", params.root.name },
                _annotations(params.root),
                dom.span { class = "_amm__devtool__element-tag", ">" },
            },
            onMouseEnter = function ()
                params.highlight(params.root.id, true)
            end,
            onMouseExit = function ()
                params.highlight(params.root.id, false)
            end,
            onClick = function()
                if not selected then
                    params.setSelected(params.root.id)
                end

                local now = computer.millis()
                if now - lastClickTime.current < 300 then
                    params.setExpanded(params.root.id, not expanded)
                end

                lastClickTime.current = now
            end,
        },
    }

    if expanded then
        for _, child in ipairs(params.root.children) do
            table.insert(
                div,
                dom.withKey(
                    child.id,
                    element(
                        {
                            root = child,
                            selected = params.selected,
                            expanded = params.expanded,
                            setSelected = params.setSelected,
                            setExpanded = params.setExpanded,
                            highlight = params.highlight,
                            depth = params.depth + 1,
                        }
                    )
                )
            )
        end
    end

    return div
end
element = dom.functional(_element)

--- @param ctx ammgui.dom.Context
--- @param params { heading: ammgui.dom.inline.Node, content: ammgui.dom.block.Node }
--- @return ammgui.dom.block.Node
local function _section(ctx, params)
    local collapsed, setCollapsed = ctx:useState(false)
    local lastClickTime = ctx:useRef(0)

    local body = dom.flex {
        class = {
            "_amm__devtool__section",
            collapsed and "_amm__devtool__section-collapsed",
        },
        dom.h1 {
            class = "_amm__devtool__section-heading",
            params.heading,
            onClick = function ()
                local now = computer.millis()
                if now - lastClickTime.current < 300 then
                    setCollapsed(not collapsed)
                end
                lastClickTime.current = now
            end
        },
    }

    if not collapsed then
        table.insert(body, dom.scroll {
            class = "_amm__devtool__section-content",
            dom.div {
                class = "_amm__devtool__section-content-inner",
                params.content,
            }
        })
    end

    return body
end
local section = dom.functional(_section)

--- @param ctx ammgui.dom.Context
--- @param params { root: ammgui.devtools.Element }
--- @return ammgui.dom.block.Node
local function panel(ctx, params)
    local selected, setSelected = ctx:useState(nil)
    local expanded, setExpanded = ctx:useReducer(
        setmetatable({}, { __mode = "kv" }),
        function (t, id, set)
            t[id] = set or nil
            return t
        end
    )
    local function highlight(id, highlighted)
    end

    return resize.Split {
        class = "_amm__devtool",
        direction = "column",
        section {
            heading = dom.span { "Elements" },
            content = element {
                root = params.root,
                selected = selected,
                expanded = expanded,
                setSelected = setSelected,
                setExpanded = setExpanded,
                highlight = highlight,
                depth = 0,
            }
        },
        section {
            heading = dom.span { "Style" },
            content = dom.p { "Foo bar baz!" },
        },
    }
end
ns.panel = dom.functional(panel)

return ns
