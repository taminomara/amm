local stylesheet = require "ammgui.css.stylesheet"
local class = require "ammcore.class"
local u = require "ammgui.css.units"
local fun = require "ammcore.fun"

--- Pre-defined themes.
---
--- !doctype module
--- @class ammgui.css.theme
local ns = {}

local DEFAULT_COLORS = {
    canvas = "#101010",
    canvastext = "#e0e0e0",
    accentcolor = "#1f6dff",
    accentcolortext = "#f0f0f0",

    ok = "#109910",
    oktext = "#e0e0e0",
    stop = "#105099",
    stoptext = "#e0e0e0",
    warning = "#b99910",
    warningtext = "#e0e0e0",
    error = "#991010",
    errortext = "#e0e0e0",
    critical = "#ab0ea0",
    criticaltext = "#e0e0e0",
    nodata = "#707070",
    nodatatext = "#e0e0e0",
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
    self.theme = fun.t.update(fun.t.copy(DEFAULT_COLORS), theme)

    -- Display for basic elements.
    self:addRule {
        "flex",
        display = "flex",
    }
    self:addRule {
        "span", "em", "code",
        display = "inline",
    }
    self:addRule {
        "scroll",
        overflow = "scroll",
    }
    -- Inline typography
    self:addRule {
        "em",
        color = "accentcolor",
    }
    self:addRule {
        "code",
        backgroundColor = "#303030",
        color = "accentcolortext",
        outlineRadius = u.em(0.5),
        outlineWidth = 1,
        padding = { 0, u.em(0.2) },
    }
    -- Block typography
    self:addRule {
        "p", "section", "blockquote", "figure", "figcaption",
        margin = { u.em(0.5), 0 },
    }
    self:addRule {
        "h1",
        color = "accentcolortext",
        fontSize = u.percent(140),
        marginTop = u.em(0.7),
    }
    self:addRule {
        "h2",
        color = "accentcolortext",
        fontSize = u.percent(130),
        marginTop = u.em(0.7),
    }
    self:addRule {
        "h3",
        color = "accentcolortext",
        fontSize = u.percent(120),
        marginTop = u.em(0.7),
    }
    self:addRule {
        "figcaption",
        fontSize = u.percent(80),
    }
    self:addRule {
        "article",
        marginTrim = "block",
    }
    -- Features
    self:addRule {
        ".__amm_resize__container",
        flexWrap = "nowrap",
        alignItems = "stretch",
        maxWidth = u.percent(100),
        maxHeight = u.percent(100),
    }
    self:addRule {
        ".__amm_resize__split",
        flexWrap = "nowrap",
        alignItems = "stretch",
        width = u.percent(100),
        height = u.percent(100),
    }
    self:addRule {
        ".__amm_resize__handle",
        flex = { 0, 0, u.px(5) },
        backgroundColor = structs.Color { 1, 1, 1, 0.1 },
    }
    self:addRule {
        ".__amm_resize__handle:hover",
        ".__amm_resize__handle:drag",
        backgroundColor = structs.Color { 1, 1, 1, 0.3 },
    }
    self:addRule {
        ".__amm_tabs__tabs",
        display = "flex",
        columnGap = u.rem(0.4),
        rowGap = u.rem(0.2),
        paddingTop = u.rem(0.2),
        paddingBottom = 0,
        paddingLeft = u.rem(0.2),
        paddingRight = u.rem(0.2),
        fontSize = u.rem(1),
        alignItems = "baseline",
    }
    self:addRule {
        ".__amm_tabs__tab",
        flex = { 0, 0, "auto" },
        textWrapMode = "nowrap",
        backgroundColor = "#202020",
        padding = { u.rem(0.2), u.rem(0.5) },
    }
    self:addRule {
        ".__amm_tabs__tabs_small .__amm_tabs__tab",
        padding = { 0, u.rem(0.5) },
    }
    self:addRule {
        ".__amm_tabs__tab:hover",
        backgroundColor = "#303030",
    }
    self:addRule {
        ".__amm_tabs__tab_current",
        backgroundColor = "#0e2a9c",
    }
    self:addRule {
        ".__amm_tabs__tab_current:hover",
        backgroundColor = "#1435ba",
    }
    self:addRule {
        ".__amm_tabs__tab_spacer",
        flex = 1,
        marginLeft = u.rem(-0.4),
    }
    self:addRule {
        ".__amm_tabs__tabs_sep",
        height = u.rem(0.2),
        backgroundColor = "#202020",
    }
    self:addRule {
        ".__amm_tabs__content",
        display = "none",
    }
    self:addRule {
        ".__amm_tabs__content_current",
        display = "block",
    }

    return self
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
