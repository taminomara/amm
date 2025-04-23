local stylesheet = require "ammgui.css.stylesheet"
local class = require "ammcore.class"
local u = require "ammgui.css.units"

--- Pre-defined themes.
---
--- !doctype module
--- @class ammgui.css.theme
local ns = {}

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
    self.theme = theme

    return self
end

--- System styles.
ns.SYSTEM = stylesheet.Stylesheet:New(1000)
    :addRule {
        ":root",
        color = "canvastext",
        backgroundColor = "canvas",
        width = u.vw(100),
        height = u.vh(100),
        overflow = "hidden",
    }
    :addRule {
        "scroll",
        overflow = "hidden",
    }

--- Default theme.
ns.DEFAULT = ns.Theme
    :New {
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
    -- Inline typography
    :addRule {
        "em",
        color = "accentcolor",
    }
    :addRule {
        "code",
        backgroundColor = "#303030",
        color = "accentcolortext",
        outlineRadius = u.em(0.5),
        outlineWidth = 1,
        padding = { 0, u.em(0.2) },
    }
    -- Block typography
    :addRule {
        "p", "section", "blockquote", "figure", "figcaption",
        margin = { u.em(0.5), 0 },
    }
    :addRule {
        "h1",
        color = "accentcolortext",
        fontSize = u.percent(140),
        marginTop = u.em(0.7),
    }
    :addRule {
        "h2",
        color = "accentcolortext",
        fontSize = u.percent(130),
        marginTop = u.em(0.7),
    }
    :addRule {
        "h3",
        color = "accentcolortext",
        fontSize = u.percent(120),
        marginTop = u.em(0.7),
    }
    :addRule {
        "figcaption",
        fontSize = u.percent(80),
    }
    :addRule {
        "article",
        marginTrim = "block",
    }
    -- Features
    :addRule {
        ".__amm_resize__container",
        flexWrap = "nowrap",
        alignItems = "stretch",
        maxWidth = u.percent(100),
        maxHeight = u.percent(100),
    }
    :addRule {
        ".__amm_resize__split",
        flexWrap = "nowrap",
        alignItems = "stretch",
        width = u.percent(100),
        height = u.percent(100),
    }
    :addRule {
        ".__amm_resize__handle",
        flex = { 0, 0, u.px(5) },
        backgroundColor = structs.Color { 1, 1, 1, 0.1 },
    }
    :addRule {
        ".__amm_resize__handle:hover",
        ".__amm_resize__handle:drag",
        backgroundColor = structs.Color { 1, 1, 1, 0.3 },
    }

return ns
