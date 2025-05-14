local stylesheet = require "ammgui.css.stylesheet"
local dom = require "ammgui.dom"
local u = require "ammgui.css.units"
local tabs = require "ammgui.dom.tabs"
local elements = require "ammgui._impl.devtools.elements"

--- Developer panel.
---
--- !doctype module
--- @class ammgui._impl.devtools
local ns = {}

ns.style = stylesheet.Stylesheet:New()
    :addRule {
        ".devtools__page",
        minWidth = "max-content",
    }
    :addRule {
        ".devtools__layout-diagram",
        margin = "auto",
        width = u.percent(100),
        height = u.px(220),
    }
    :addRule {
        ".devtools__element-title",
        fontFamily = "monospace",
        textWrapMode = "nowrap",
        margin = { u.rem(0.2), 0 },
        padding = { 0, u.rem(0.5) },
        outlineRadius = u.em(0.3),
    }
    :addRule {
        ".devtools__element-title:hover",
        backgroundColor = "ButtonBgHover",
        color = "ButtonText",
    }
    :addRule {
        ".devtools__element-title__selected",
        backgroundColor = "AccentBg",
        color = "AccentText",
    }
    :addRule {
        ".devtools__element-title__selected:hover",
        backgroundColor = "AccentBgHover",
        color = "AccentText",
    }
    :addRule {
        ".devtools__element-title__pre-selected",
        backgroundColor = "ButtonBgHover",
        color = "ButtonText",
    }
    :addRule {
        ".devtools__property-list",
        paddingLeft = u.rem(1),
    }
    :addRule {
        ".devtools__selector-list-element__unused",
        ".devtools__selector-list-element__unused *",
        ".devtools__property-list-element__unused",
        ".devtools__property-list-element__unused *",
        backgroundColor = "DimBg",
        color = "DimText",
    }
    :addRule {
        ".devtools__rule",
        fontFamily = "monospace",
        textWrapMode = "nowrap",
    }
    :addRule {
        ".devtools__computed",
        fontFamily = "monospace",
        textWrapMode = "nowrap",
        margin = { u.rem(0.2), 0 },
    }
    :addRule {
        ".devtools__computed-header",
        padding = { 0, u.rem(0.5) },
        outlineRadius = u.em(0.3),
    }
    :addRule {
        ".devtools__computed-header:hover",
        backgroundColor = "ButtonBgHover",
        color = "ButtonText",
    }
    :addRule {
        ".devtools__computed-list",
        marginLeft = u.rem(0.5),
        paddingLeft = u.rem(0.5),
    }
    :addRule {
        ".devtools__computed-list-element__unused",
        ".devtools__computed-list-element__unused *",
        backgroundColor = "DimBg",
        color = "DimText",
    }
    :addRule {
        ".devtools__computed-list-value",
        marginLeft = u.rem(0.5),
        padding = { 0, u.rem(0.5) },
        outlineRadius = u.em(0.3),
    }
    :addRule {
        ".devtools__computed-list-value:hover",
        backgroundColor = "ButtonBgHover",
        color = "ButtonText",
    }

--- @class ammgui._impl.devtools._PanelParams
--- @field root ammgui._impl.devtools.Element
--- @field selectedId ammgui._impl.id.EventListenerId?
--- @field preSelectedId ammgui._impl.id.EventListenerId?
--- @field selectionEnabled boolean
--- @field setSelectionEnabled fun(enabled: boolean)
--- @field setSelectedId fun(id: ammgui._impl.id.EventListenerId?)
--- @field setHighlightedId fun(id: ammgui._impl.id.EventListenerId?, c: boolean?, p: boolean?, o: boolean?, m: boolean?)

--- @param ctx ammgui.Context
--- @param params ammgui._impl.devtools._PanelParams
--- @return ammgui.dom.AnyNode
local function _devtools(ctx, params)
    local currentTab, setCurrentTab = ctx:useState(1)

    return tabs.TabsManual {
        currentTab = currentTab,
        setCurrentTab = setCurrentTab,
        fullHeight = true,
        {
            title = "Elements",
            key = 1,
            elements.elementsPage(params),
        },
        {
            title = "Components",
            key = 2,
        },
        {
            title = "Log",
            key = 3,
        },
        additionalTabs = dom.list {
            dom.button {
                class = { "small", params.selectionEnabled and "accent" },
                "Pick",
                onClick = function()
                    if not params.selectionEnabled then
                        setCurrentTab(1)
                    end
                    params.setSelectionEnabled(not params.selectionEnabled)
                    return false
                end,
            },
        },
    }
end
ns.panel = dom.Functional(_devtools)

return ns
