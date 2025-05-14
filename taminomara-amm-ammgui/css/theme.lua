local stylesheet = require "ammgui.css.stylesheet"
local class = require "ammcore.class"
local u = require "ammgui.css.units"

--- Pre-defined themes.
---
--- !doctype module
--- @class ammgui.css.theme
local ns = {}

local DEFAULT_COLORS = {
    Canvas = "#101010",
    CanvasText = "#e0e0e0",

    AccentBg = "#0e2a9c",
    AccentBgHover = "#1435ba",
    AccentText = "#f0f0f0",

    ButtonBg = "#202020",
    ButtonBgHover = "#303030",
    ButtonText = "#f0f0f0",

    EmBg = "transparent",
    EmText = "#617ce6",
    DimBg = "transparent",
    DimText = "#737272",
    StrongBg = "transparent",
    StrongText = "#e66161",
    CodeBg = "#303030",
    CodeText = "#f0f0f0",

    OkBg = "#109910",
    OkYext = "#e0e0e0",
    StopBg = "#105099",
    StopText = "#e0e0e0",
    WarningBg = "#b99910",
    WarningText = "#e0e0e0",
    ErrorBg = "#991010",
    ErrorText = "#e0e0e0",
    CriticalBg = "#ab0ea0",
    CriticalText = "#e0e0e0",
    NoDataBg = "#707070",
    NoDataText = "#e0e0e0",
}

--- Theme stylesheet.
---
--- @class ammgui.css.theme.Theme: ammgui.css.stylesheet.Stylesheet
ns.Theme = class.create("Theme", stylesheet.Stylesheet)

--- @param theme table<string, Color | string>
---
--- !doctype classmethod
--- @generic T: ammgui.css.theme.Theme
--- @param self T
--- @return T
function ns.Theme:New(theme)
    self = stylesheet.Stylesheet.New(self, -1)

    --- Theme colors.
    ---
    --- See list of all colors in `ammgui.css.rule.SystemColorValue`.
    ---
    --- @type table<string, Color | string>
    self.theme = {}
    for k, v in pairs(DEFAULT_COLORS) do self.theme[k:lower()] = v end
    for k, v in pairs(theme) do self.theme[k:lower()] = v end

    self:_setupDefaultRules()

    return self
end

function ns.Theme:_setupDefaultRules()
    -- Display for basic elements.
    self:addRule {
        "flex",
        display = "flex",
    }
    self:addRule {
        "span", "em", "dim", "strong", "code", "small",
        display = "inline",
    }
    self:addRule {
        "scroll",
        overflow = "scroll",
    }
    -- Inline typography
    self:addRule {
        "small",
        fontSize = u.percent(80),
    }
    self:addRule {
        "em",
        backgroundColor = "EmBg",
        color = "EmText",
    }
    self:addRule {
        "dim",
        backgroundColor = "DimBg",
        color = "DimText",
    }
    self:addRule {
        "strong",
        backgroundColor = "StrongBg",
        color = "StrongText",
    }
    self:addRule {
        "code",
        backgroundColor = "CodeBg",
        color = "CodeText",
        outlineRadius = u.em(0.3),
        outlineWidth = 1,
        padding = { 0, u.em(0.2) },
    }
    -- Block typography
    self:addRule {
        "p", "section", "blockquote", "figure", "figcaption",
        margin = { u.rem(0.5), u.rem(0.5) },
    }
    self:addRule {
        "h1",
        color = "AccentText",
        fontSize = u.percent(140),
        margin = { u.em(0.7), u.rem(0.5), u.rem(0.5) },
    }
    self:addRule {
        "h2",
        color = "AccentText",
        fontSize = u.percent(130),
        margin = { u.em(0.7), u.rem(0.5), u.rem(0.5) },
    }
    self:addRule {
        "h3",
        color = "AccentText",
        fontSize = u.percent(120),
        margin = { u.em(0.7), u.rem(0.5), u.rem(0.5) },
    }
    self:addRule {
        "figcaption",
        fontSize = u.percent(80),
    }
    self:addRule {
        "article",
        marginTrim = "block",
    }
    -- Controls
    self:addRule {
        "button",
        backgroundColor = "ButtonBg",
        color = "ButtonText",
        padding = { u.rem(0.2), u.rem(0.5) },
        outlineWidth = 1,
        textWrapMode = "nowrap",
    }
    self:addRule {
        "button:hover",
        backgroundColor = "ButtonBgHover",
    }
    self:addRule {
        "button.accent",
        backgroundColor = "AccentBg",
        color = "AccentText",
    }
    self:addRule {
        "button.accent:hover",
        backgroundColor = "AccentBgHover",
    }
    self:addRule {
        "button.small",
        ".small button",
        fontSize = u.percent(80),
        outlineRadius = u.em(0.3),
        padding = { 0, u.rem(0.5) },
    }
    -- Features
    self:addRule {
        ".__amm_resize__split",
        display = "flex",
        flexWrap = "nowrap",
        width = u.percent(100),
        height = u.percent(100),
    }
    self:addRule {
        ".__amm_resize__split-panel",
        overflow = "scroll",
    }
    self:addRule {
        ".__amm_resize__handle",
        flex = { 0, 0, u.px(5) },
        backgroundColor = "ButtonBg",
    }
    self:addRule {
        ".__amm_resize__handle:hover",
        ".__amm_resize__handle:drag",
        backgroundColor = "ButtonBgHover",
    }
    self:addRule {
        ".__amm_tabs",
        display = "flex",
        flexDirection = "column",
    }
    self:addRule {
        ".__amm_tabs__tabs",
        flex = { 0, 0, "auto" },
        display = "flex",
        gap = { u.rem(0.2), u.rem(0.5) },
        padding = { u.rem(0.2), u.rem(0.5) },
        alignItems = "baseline",
        backgroundColor = "ButtonBg",
    }
    self:addRule {
        ".__amm_tabs__tab",
        flex = { 0, 0, "auto" },
        padding = { u.rem(0.2), u.rem(0.5) },
        textWrapMode = "nowrap",
        backgroundColor = "ButtonBg",
        color = "ButtonText",
    }
    self:addRule {
        ".small .__amm_tabs__tab",
        padding = { 0, u.rem(0.5) },
    }
    self:addRule {
        ".__amm_tabs__tab:hover",
        backgroundColor = "ButtonBgHover",
    }
    self:addRule {
        ".__amm_tabs__tab__current",
        backgroundColor = "AccentBg",
        color = "AccentText",
    }
    self:addRule {
        ".__amm_tabs__tab__current:hover",
        backgroundColor = "AccentBgHover",
    }
    self:addRule {
        ".__amm_tabs__tab_spacer",
        flex = 1,
        marginLeft = u.rem(-0.5),
    }
    self:addRule {
        ".__amm_tabs__tabs_sep",
        flex = { 0, 0, u.rem(0.2) },
        backgroundColor = "ButtonBg",
    }
    self:addRule {
        ".__amm_tabs__content",
        display = "none",
        flex = { 1, 1, "auto" },
    }
    self:addRule {
        ".__amm_tabs__content__current",
        display = "block",
    }
    self:addRule {
        ".__amm_tabs__full",
        height = u.percent(100),
    }
    self:addRule {
        ".__amm_tabs__content__full",
        overflow = "scroll",
    }
end

--- System styles.
---
--- These styles are always present in the system. They can't be disabled or changed.
ns.SYSTEM = stylesheet.Stylesheet:New(1000)
    :addRule {
        ":root",
        color = "canvastext",
        backgroundColor = "canvas",
        width = u.vw(100),
        height = u.vh(100),
        overflow = "scroll",
    }

--- Default theme.
ns.DEFAULT = ns.Theme:New({})

return ns
