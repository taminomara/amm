local stylesheet = require "ammgui.css.stylesheet"
local class = require "ammcore.class"

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
    -- System
    :addRule {
        ":root",
        color = "canvastext",
        backgroundColor = "canvas",
        width = "100vw",
        height = "100vh",
    }
    :addRule {
        "scroll",
        overflow = "hidden",
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
        outlineRadius = "0.5em",
        outlineWidth = 1,
        padding = { 0, "0.2em" },
    }
    -- Block typography
    :addRule {
        "p", "section", "blockquote", "figure", "figcaption",
        margin = { "0.5em", 0 },
    }
    :addRule {
        "h1",
        color = "accentcolortext",
        fontSize = "140%",
        marginTop = "0.7em",
    }
    :addRule {
        "h2",
        color = "accentcolortext",
        fontSize = "130%",
        marginTop = "0.7em",
    }
    :addRule {
        "h3",
        color = "accentcolortext",
        fontSize = "120%",
        marginTop = "0.7em",
    }
    :addRule {
        "figcaption",
        fontSize = "80%",
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
        maxWidth = "100%",
        maxHeight = "100%",
    }
    :addRule {
        ".__amm_resize__split",
        flexWrap = "nowrap",
        alignItems = "stretch",
        width = "100%",
        height = "100%",
    }
    :addRule {
        ".__amm_resize__handle",
        flex = { 0, 0, "5px" },
        backgroundColor = structs.Color { 1, 1, 1, 0.1 },
    }
    :addRule {
        ".__amm_resize__handle:hover",
        ".__amm_resize__handle:drag",
        backgroundColor = structs.Color { 1, 1, 1, 0.3 },
    }

return ns
