local class = require "ammcore.class"
local log = require "ammcore.log"

--- A CSS rule.
---
--- !doctype module
--- @class ammgui.css.rule
local ns = {}

--- @generic T
--- @generic U
--- @param prop T
--- @param literalValues table<T, T>
--- @param functionalValues table<T, fun(x: T, resolved: ammgui.css.rule.Resolved): U>
--- @param parser fun(x: unknown, r: ammgui.css.rule.Resolved): U
--- @return T|U
local function resolver(
    prop, literalValues, functionalValues, parser
)
    for value, mappedValue in ipairs(literalValues) do
        while mappedValue ~= value and literalValues[mappedValue] do
            mappedValue = literalValues[mappedValue]
        end
        literalValues[value] = mappedValue
    end
    return { literalValues = literalValues, functionalValues = functionalValues, parser = parser } --[[ @as any ]]
end

--- @param ... string
--- @return fun(x: unknown, defaultUnit?: string): number, string
local function numValueParser(...)
    local units = {}
    local unitDesc, sep = "", ""
    for _, unit in ipairs({ ... }) do
        units[unit] = true
        unitDesc = unitDesc .. sep .. (unit:len() > 0 and unit or "<number>")
        sep = ", "
    end

    return function(x, defaultUnit)
        local n, unit
        if type(x) == "number" then
            n, unit = x, defaultUnit or ""
        elseif type(x) == "string" then
            local parsedN, parsedUnit = x:match("^([%d.+-]+)(.*)$")
            n = tonumber(parsedN)
            unit = parsedUnit
        else
            error(string.format("invalid value %s", log.p(x)), 0)
        end
        if not n then
            error(string.format("invalid value %s: can't parse a number", log.p(x)), 0)
        end
        if not units[unit] then
            unit = unit:len() > 0 and unit or "<number>"
            error(string.format("invalid value %s: expected one of %s, got %s", log.p(x), unitDesc, log.p(unit)), 0)
        end
        return n, unit
    end
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @return nil
local function parseFail(x, r)
    error(string.format("invalid value %s", log.p(x)), 0)
end

local lengthParser = numValueParser("px", "pt", "em", "%")

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @return [number, "px"|"pt"|"%"]
local function parseLength(x, r)
    if tonumber(x) == 0 then
        x = 0 -- specifying unit is optional when value is 0
    end
    local n, u = lengthParser(x, "px")
    if u == "em" then
        local nn, nu = table.unpack(r.fontSize)
        n = n * nn
        u = nu
    end
    return { n, u }
end

local fontSizeUnitParser = numValueParser("px", "pt", "%")

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @return [number, "px"|"pt"]
local function parseFontSize(x, r)
    local n, u = fontSizeUnitParser(x, "px")
    if n < 0 then
        error("fontSize can't be negative")
    end
    if u == "%" then
        local nn, nu = table.unpack(ns.Resolved._getInherited(r, "fontSize")[1])
        n = n * nn / 100
        u = nu
    end
    return { n, u }
end

local lineHeightUnitParser = numValueParser("", "px", "pt", "em", "%")

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @return [number, "px"|"pt"|""]
local function parseLineHeight(x, r)
    local n, u = lineHeightUnitParser(x)
    if n < 0 then
        error("lineHeight can't be negative")
    end
    if u == "%" then
        local nn, nu = table.unpack(r.fontSize)
        n = n * nn / 100
        u = nu
    elseif u == "em" then
        local nn, nu = table.unpack(r.fontSize)
        n = n * nn
        u = nu
    end
    return { n, u }
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @return Color
local function parseColor(x, r)
    if type(x) == "string" then
        local r, g, b, a
        for _, m in ipairs({
            "^#(%x)(%x)(%x)$",
            "^#(%x)(%x)(%x)(%x)$",
            "^#(%x%x)(%x%x)(%x%x)$",
            "^#(%x%x)(%x%x)(%x%x)(%x%x)$",
        }) do
            r, g, b, a = x:match(m)
            if r and g and b then
                if not a then
                    a = "ff"
                end
                break
            end
        end
        if not r or not g or not b or not a then
            error(string.format("invalid color %s", log.p(x)), 0)
        end

        return structs.Color {
            r = tonumber(r, 16) / (2 ^ (4 * r:len()) - 1),
            g = tonumber(g, 16) / (2 ^ (4 * g:len()) - 1),
            b = tonumber(b, 16) / (2 ^ (4 * b:len()) - 1),
            a = tonumber(a, 16) / (2 ^ (4 * a:len()) - 1),
        }
    elseif type(x) == "userdata" or (type(x) == "table" and x.__amm_is_color) then
        return x
    else
        error(string.format("invalid color %s", log.p(x)), 0)
    end
end

--- @param x unknown
--- @return number
local function parseFloat(x)
    if type(x) == "number" then
        return x
    elseif type(x) == "string" then
        local n = tonumber(x)
        if not n then
            error(string.format("invalid number %s", log.p(x)), 0)
        end
        return n
    else
        error(string.format("invalid number %s", log.p(x)), 0)
    end
end

--- Common values that can be assigned to any CSS property.
---
--- Available options:
---
--- - ``"unset"``: use inherited value if property inherits, or initial value if not;
--- - ``"inherit"``: use the value from the parent DOM node;
--- - ``"initial"``, use initial value;
--- - ``"revert"``, use value provided by theme stylesheet.
---
--- @alias ammgui.css.rule.GlobalValue
--- |"unset"
--- |"inherit"
--- |"initial"
--- |"revert"

--- Represents a color value.
---
--- Available options:
---
--- - `Color`: an arbitrary color;
--- - `string`: a color in a hexidecimal format;
--- - ``"transparent"``: no color at all;
--- - ``"currentcolor"``: use value from `~Rule.color`.
---
--- @alias ammgui.css.rule.ColorValue
--- |ammgui.css.rule.GlobalValue
--- |Color
--- |string
--- |"transparent"
--- |"currentcolor"
--- |ammgui.css.rule.SystemColorValue

--- Represents a color variable set by a theme.
---
--- Note that the set of these colors is not the same as in CSS.
---
--- Available options:
---
--- - ``"accentcolor"``: accent color for backgrounds;
--- - ``"accentcolortext"``: accent color for foregrounds;
--- - ``"buttonborder"``: normal button border color;
--- - ``"buttonface"``: normal button background color;
--- - ``"buttontext"``: normal button text color;
--- - ``"buttonhoverborder"``: hover button border color;
--- - ``"buttonhoverface"``: hover button background color;
--- - ``"buttonhovertext"``: hover button text color;
--- - ``"buttondisabledborder"``: disabled button border color;
--- - ``"buttondisabledface"``: disabled button background color;
--- - ``"buttondisabledtext"``: disabled button text color;
--- - ``"fieldborder"``: normal field border color;
--- - ``"fieldface"``: normal field background color;
--- - ``"fieldtext"``: normal field text color;
--- - ``"fieldhoverborder"``: hover field border color;
--- - ``"fieldhoverface"``: hover field background color;
--- - ``"fieldhovertext"``: hover field text color;
--- - ``"fielddisabledborder"``: disabled field border color;
--- - ``"fielddisabledface"``: disabled field background color;
--- - ``"fielddisabledtext"``: disabled field text color;
--- - ``"canvas"``: screen background color;
--- - ``"canvastext"``: screen foreground color.
---
--- @alias ammgui.css.rule.SystemColorValue
--- |"accentcolor"
--- |"accentcolortext"
--- |"buttonborder"
--- |"buttonface"
--- |"buttontext"
--- |"buttonhoverborder"
--- |"buttonhoverface"
--- |"buttonhovertext"
--- |"buttondisabledborder"
--- |"buttondisabledface"
--- |"buttondisabledtext"
--- |"fieldborder"
--- |"fieldface"
--- |"fieldtext"
--- |"fieldhoverborder"
--- |"fieldhoverface"
--- |"fieldhovertext"
--- |"fielddisabledborder"
--- |"fielddisabledface"
--- |"fielddisabledtext"
--- |"canvas"
--- |"canvastext"

local colorFunctionalValue = function(x, resolved) return rawget(resolved, "_theme")[x] end
local colorFunctionalValues = {
    transparent = function(x, resolved) return structs.Color { r = 0, g = 0, b = 0, a = 0 } end,
    currentcolor = function(x, resolved) return resolved.color end,
    accentcolor = colorFunctionalValue,
    accentcolortext = colorFunctionalValue,
    buttonborder = colorFunctionalValue,
    buttonface = colorFunctionalValue,
    buttontext = colorFunctionalValue,
    buttonhoverborder = colorFunctionalValue,
    buttonhoverface = colorFunctionalValue,
    buttonhovertext = colorFunctionalValue,
    buttondisabledborder = colorFunctionalValue,
    buttondisabledface = colorFunctionalValue,
    buttondisabledtext = colorFunctionalValue,
    fieldborder = colorFunctionalValue,
    fieldface = colorFunctionalValue,
    fieldtext = colorFunctionalValue,
    fieldhoverborder = colorFunctionalValue,
    fieldhoverface = colorFunctionalValue,
    fieldhovertext = colorFunctionalValue,
    fielddisabledborder = colorFunctionalValue,
    fielddisabledface = colorFunctionalValue,
    fielddisabledtext = colorFunctionalValue,
    canvas = colorFunctionalValue,
    canvastext = colorFunctionalValue,
}

--- A single CSS rule, combines style settings and selectors.
---
--- @class ammgui.css.rule.Rule
--- @field [integer] string Selectors for matching DOM nodes.
ns.Rule = {}

--- @private
--- @type table<string, fun(self: ammgui.css.rule.Rule, value: unknown)>
local ruleSetters = {}

--- Contains values resolved for a concrete DOM node.
---
--- @class ammgui.css.rule.Resolved: ammcore.class.Base
ns.Resolved = class.create("Resolved")

--- A catch-all property, allows resetting values for all other properties.
---
--- @type ammgui.css.rule.GlobalValue?
ns.Rule.all = nil

--- Represents a value for ~`Rule.display` property.
---
--- Available options:
---
--- - ``"block"``: usual block layout,
--- - ``"flex"``: flex layout.
---
--- Since `ammgui` does not allow mixing inline and block elements,
--- ~`Rule.display` does not affect inline elements.
---
--- Also, since `ammgui` does not implement margins,
--- ~`Rule.gap` affects elements with ~`Rule.display` ``block`` as well.
---
--- @alias ammgui.css.rule.DisplayValue
--- |ammgui.css.rule.GlobalValue
--- | "block"
--- | "flex"

--- @type ammgui.css.rule.DisplayValue?
ns.Rule.display = nil
ns.Resolved.display = resolver(
    ns.Rule.display,
    {
        unset = "initial",
        initial = "block",
        ["block"] = "block",
        ["flex"] = "flex",
    },
    {},
    parseFail
)

--- Represents a width value.
---
--- Available options:
---
--- - ``"auto"``: calculate width based on dimensions and settings
---   of the parent container;
--- - ``"min-content"``: use minimal width possible, wrapping all text and flexboxes;
--- - ``"fit-content"``: use all available width, but clamp it between ``min-content``
---   and ``max-content``;
--- - ``"max-content"``: use maximal width possible, avoid any wrapping;
--- - `string`: number with one of the following units: ``px``, ``pt``, ``em``, ``%``;
--- - `integer`: treated as ``px``.
---
--- @alias ammgui.css.rule.WidthValue
--- |ammgui.css.rule.GlobalValue
--- |"auto"
--- |"min-content"
--- |"fit-content"
--- |"max-content"
--- |string
--- |integer

--- @type ammgui.css.rule.WidthValue?
ns.Rule.width = nil
ns.Resolved.width = resolver(
    ns.Rule.width,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-contentp",
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.WidthValue?
ns.Rule.minWidth = nil
ns.Resolved.minWidth = resolver(
    ns.Rule.minWidth,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-contentp",
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.WidthValue?
ns.Rule.maxWidth = nil
ns.Resolved.maxWidth = resolver(
    ns.Rule.maxWidth,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-contentp",
    },
    {},
    parseLength
)

--- Represents a height value.
---
--- Available options:
---
--- - ``"auto"``: calculate height based on dimensions and settings
---   of the parent container;
--- - `string`: number with one of the following units: ``px``, ``pt``, ``em``, ``%``;
--- - `integer`: treated as ``px``.
---
--- @alias ammgui.css.rule.Height
--- |ammgui.css.rule.GlobalValue
--- |"auto"
--- |string
--- |integer

--- @type ammgui.css.rule.Height?
ns.Rule.height = nil
ns.Resolved.height = resolver(
    ns.Rule.height,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.Height?
ns.Rule.minHeight = nil
ns.Resolved.minHeight = resolver(
    ns.Rule.minHeight,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.Height?
ns.Rule.maxHeight = nil
ns.Resolved.maxHeight = resolver(
    ns.Rule.maxHeight,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
    },
    {},
    parseLength
)

--- Shorthand to set `fontSize`, `lineHeight`, and `fontFamily` at once.
---
--- If given an array of two values, first is assigned to `fontSize`
--- and second to `fontFamily`.
---
--- If given an array of three values, first is assigned to `fontSize`,
--- second to `lineHeight`, and third to `fontFamily`.
---
--- @type
--- | [ammgui.css.rule.FontSize, ammgui.css.rule.FontFamily]
--- | [ammgui.css.rule.FontSize, ammgui.css.rule.LineHeight, ammgui.css.rule.FontFamily]
--- | nil
ns.Rule.font = nil
ruleSetters.font = function(rule, value)
    if type(value) ~= "table" then
        error(string.format("invalid value for font: %s", log.p(value)))
    end
    if #value == 2 then
        rule.fontSize, rule.fontFamily = table.unpack(value)
    elseif #value == 3 then
        rule.fontSize, rule.lineHeight, rule.fontFamily = table.unpack(value)
    else
        error(string.format("invalid value for font: %s", log.p(value)))
    end
end

--- Represents a font size value.
---
--- Available options:
---
--- - `string`: number with one of the following units: ``px``, ``pt``, ``%``;
--- - `number`: treated as ``px``.
---
--- @alias ammgui.css.rule.FontSize
--- |ammgui.css.rule.GlobalValue
--- |string
--- |number

--- @type ammgui.css.rule.FontSize?
ns.Rule.fontSize = nil
ns.Resolved.fontSize = resolver(
    ns.Rule.fontSize,
    {
        unset = "inherit",
        initial = "12pt",
    },
    {},
    parseFontSize
) --[[ @as [number, "px"|"pt"] ]]

--- Represents a font family value.
---
--- Available options:
---
--- - ``"normal"``: use default font;
--- - ``"monospace"``: use monospace font.
---
--- @alias ammgui.css.rule.FontFamily
--- |ammgui.css.rule.GlobalValue
--- |"normal"
--- |"monospace"

--- @type ammgui.css.rule.FontFamily?
ns.Rule.fontFamily = nil
ns.Resolved.fontFamily = resolver(
    ns.Rule.fontFamily,
    {
        unset = "inherit",
        initial = "normal",
        ["normal"] = "normal",
        ["monospace"] = "monospace",
    },
    {},
    parseFail
)

--- Represents a height of a line in a paragraph.
---
--- Available options:
---
--- - ``"normal"``: use default line height, ``1.2``;
--- - `string`: number with one of the following units: ``px``, ``pt``,
---   or without a unit;
--- - `number`: scaling factor for `~Rule.fontSize`, i.e. line height is calculated
---   as ``lineHeight * fontSize``.
---
--- @alias ammgui.css.rule.LineHeight
--- |ammgui.css.rule.GlobalValue
--- |"normal"
--- |string
--- |number

--- @type ammgui.css.rule.LineHeight?
ns.Rule.lineHeight = nil
ns.Resolved.lineHeight = resolver(
    ns.Rule.lineHeight,
    {
        unset = "inherit",
        initial = "normal",
        ["normal"] = 1.2,
    },
    {},
    parseLineHeight
) --[[ @as [number, "px"|"pt"|""] ]]

--- @type ammgui.css.rule.ColorValue?
ns.Rule.color = nil
ns.Resolved.color = resolver(
    ns.Rule.color,
    {
        unset = "inherit",
        initial = "canvastext",
        currentcolor = "inherit",
    },
    colorFunctionalValues,
    parseColor
)

--- @type ammgui.css.rule.ColorValue?
ns.Rule.backgroundColor = nil
ns.Resolved.backgroundColor = resolver(
    ns.Rule.backgroundColor,
    {
        unset = "initial",
        initial = "transparent",
    },
    colorFunctionalValues,
    parseColor
)

--- Represents a length value.
---
--- Available options:
---
--- - `string`: number with one of the following units: ``px``, ``pt``, ``em``, ``%``;
--- - `integer`: treated as ``px``.
---
--- @alias ammgui.css.rule.LengthValue
--- |ammgui.css.rule.GlobalValue
--- |string
--- |integer

--- Shorthand to set `paddingTop`, `paddingRight`, `paddingBottom`, and `paddingLeft`
--- at once.
---
--- If given a single value, sets all paddings to this value.
---
--- If given an array of two values, sets `paddingTop` and `paddingBottom` to the
--- first value, `paddingRight` and `paddingLeft` to the second.
---
--- If given an array of three values, sets `paddingTop` to the
--- first value, `paddingRight` and `paddingLeft` to the second,
--- `paddingBottom` to the third.
---
--- If given an array of four values, sets `paddingTop`, `paddingRight`,
--- `paddingBottom`, and `paddingLeft` respectively.
---
--- @type
--- | ammgui.css.rule.LengthValue
--- | [ammgui.css.rule.LengthValue]
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue]
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue]
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue]
--- | nil
ns.Rule.padding = nil
ruleSetters.padding = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        rule.paddingTop = value[1]
        rule.paddingRight = value[1]
        rule.paddingBottom = value[1]
        rule.paddingLeft = value[1]
    elseif #value == 2 then
        rule.paddingTop = value[1]
        rule.paddingRight = value[2]
        rule.paddingBottom = value[1]
        rule.paddingLeft = value[2]
    elseif #value == 3 then
        rule.paddingTop = value[1]
        rule.paddingRight = value[2]
        rule.paddingBottom = value[3]
        rule.paddingLeft = value[2]
    elseif #value == 4 then
        rule.paddingTop = value[1]
        rule.paddingRight = value[2]
        rule.paddingBottom = value[3]
        rule.paddingLeft = value[4]
    else
        error(string.format("invalid value for padding: %s", log.p(value)))
    end
end

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingTop = nil
ns.Resolved.paddingTop = resolver(
    ns.Rule.paddingTop,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingLeft = nil
ns.Resolved.paddingLeft = resolver(
    ns.Rule.paddingLeft,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingRight = nil
ns.Resolved.paddingRight = resolver(
    ns.Rule.paddingRight,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingBottom = nil
ns.Resolved.paddingBottom = resolver(
    ns.Rule.paddingBottom,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- Shorthand to set `borderWidthTop`, `borderWidthRight`, `borderWidthBottom`, and `borderWidthLeft`
--- at once.
---
--- If given a single value, sets all border widths to this value.
---
--- If given an array of two values, sets `borderWidthTop` and `borderWidthBottom` to the
--- first value, `borderWidthRight` and `borderWidthLeft` to the second.
---
--- If given an array of three values, sets `borderWidthTop` to the
--- first value, `borderWidthRight` and `borderWidthLeft` to the second,
--- `borderWidthBottom` to the third.
---
--- If given an array of four values, sets `borderWidthTop`, `borderWidthRight`,
--- `borderWidthBottom`, and `borderWidthLeft` in order.
---
--- @type
--- | ammgui.css.rule.LengthValue
--- | [ammgui.css.rule.LengthValue]
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue]
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue]
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue, ammgui.css.rule.LengthValue]
--- | nil
ns.Rule.borderWidth = nil
ruleSetters.borderWidth = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        rule.borderWidthTop = value[1]
        rule.borderWidthRight = value[1]
        rule.borderWidthBottom = value[1]
        rule.borderWidthLeft = value[1]
    elseif #value == 2 then
        rule.borderWidthTop = value[1]
        rule.borderWidthRight = value[2]
        rule.borderWidthBottom = value[1]
        rule.borderWidthLeft = value[2]
    elseif #value == 3 then
        rule.borderWidthTop = value[1]
        rule.borderWidthRight = value[2]
        rule.borderWidthBottom = value[3]
        rule.borderWidthLeft = value[2]
    elseif #value == 4 then
        rule.borderWidthTop = value[1]
        rule.borderWidthRight = value[2]
        rule.borderWidthBottom = value[3]
        rule.borderWidthLeft = value[4]
    else
        error(string.format("invalid value for borderWidth: %s", log.p(value)))
    end
end

--- @type ammgui.css.rule.LengthValue?
ns.Rule.borderWidthTop = nil
ns.Resolved.borderWidthTop = resolver(
    ns.Rule.borderWidthTop,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.LengthValue?
ns.Rule.borderWidthLeft = nil
ns.Resolved.borderWidthLeft = resolver(
    ns.Rule.borderWidthLeft,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.LengthValue?
ns.Rule.borderWidthRight = nil
ns.Resolved.borderWidthRight = resolver(
    ns.Rule.borderWidthRight,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.LengthValue?
ns.Rule.borderWidthBottom = nil
ns.Resolved.borderWidthBottom = resolver(
    ns.Rule.borderWidthBottom,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseLength
)

--- @type ammgui.css.rule.ColorValue?
ns.Rule.borderColorTop = nil
ns.Resolved.borderColorTop = resolver(
    ns.Rule.borderColorTop,
    {
        unset = "initial",
        initial = "currentcolor",
    },
    colorFunctionalValues,
    parseColor
)

--- @type ammgui.css.rule.ColorValue?
ns.Rule.borderColorLeft = nil
ns.Resolved.borderColorLeft = resolver(
    ns.Rule.borderColorLeft,
    {
        unset = "initial",
        initial = "currentcolor",
    },
    colorFunctionalValues,
    parseColor
)

--- @type ammgui.css.rule.ColorValue?
ns.Rule.borderColorRight = nil
ns.Resolved.borderColorRight = resolver(
    ns.Rule.borderColorRight,
    {
        unset = "initial",
        initial = "currentcolor",
    },
    colorFunctionalValues,
    parseColor
)

--- @type ammgui.css.rule.ColorValue?
ns.Rule.borderColorBottom = nil
ns.Resolved.borderColorBottom = resolver(
    ns.Rule.borderColorBottom,
    {
        unset = "initial",
        initial = "currentcolor",
    },
    colorFunctionalValues,
    parseColor
)

--- Shorthand to set `flexGrow`, `flexShrink`, and `flexBasis` at once.
---
--- If given one value, it can be either a `flexGrow` value (then `flexShrink`
--- is set to ``1`` and `flexBasis` is set to ``0``), or a `flexBasis` value
--- (then `flexGrow` and `flexShrink` are set to ``1``).
---
--- If given an array of two values, then the first one should be a `flexGrow` value,
--- and the second is either `flexShrink` (then `flexBasis` set to ``0``),
--- or `flexBasis` (then `flexShrink` set to ``1``).
---
--- If given an array of three values, they should be `flexGrow`, `flexShrink`,
--- and `flexBasis`, accordingly.
---
--- In the first two cases, a value of type `number` is treated
--- as `flexGrow`/`flexShrink`, and a value of type `string` is treated as `flexBasis`.
---
--- @type
--- | "none"
--- | ammgui.css.rule.NumberValue
--- | ammgui.css.rule.WidthValue
--- | [ammgui.css.rule.NumberValue]
--- | [ammgui.css.rule.WidthValue]
--- | [ammgui.css.rule.NumberValue, ammgui.css.rule.NumberValue]
--- | [ammgui.css.rule.NumberValue, ammgui.css.rule.WidthValue]
--- | [ammgui.css.rule.NumberValue, ammgui.css.rule.NumberValue, ammgui.css.rule.WidthValue]
--- | nil
ns.Rule.flex = nil
ruleSetters.flex = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        if type(value[1]) == "string" then
            rule.flexGrow = 1
            rule.flexShrink = 1
            rule.flexBasis = value[1]
        else
            rule.flexGrow = value[1]
            rule.flexShrink = 1
            rule.flexBasis = 0
        end
    elseif #value == 2 then
        rule.flexGrow = value[1]
        if type(value[2]) == "string" then
            rule.flexShrink = 1
            rule.flexBasis = value[2]
        else
            rule.flexShrink = value[2]
            rule.flexBasis = 0
        end
    elseif #value == 3 then
        rule.flexGrow = value[1]
        rule.flexShrink = value[2]
        rule.flexBasis = value[3]
    else
        error(string.format("invalid value for flex: %s", log.p(value)))
    end
end

--- Shorthand to set `flexDirection` and `flexWrap` at once.
---
--- If given one value, sets `flexDirection` or `flexWrap` depending on value.
---
--- If given two values, sets `flexDirection` and `flexWrap` respectively.
---
--- @type
--- | ammgui.css.rule.FlexDirectionValue
--- | ammgui.css.rule.FlexWrapValue
--- | [ammgui.css.rule.FlexDirectionValue]
--- | [ammgui.css.rule.FlexWrapValue]
--- | [ammgui.css.rule.FlexDirectionValue, ammgui.css.rule.FlexWrapValue]
--- | nil
ns.Rule.flexFlow = nil
ruleSetters.flexFlow = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        if value[1] == "wrap" or value[1] == "nowrap" then
            rule.flexWrap = value[1]
        else
            rule.flexDirection = value[1]
        end
    elseif #value == 2 then
        rule.flexDirection = value[1]
        rule.flexWrap = value[2]
    else
        error(string.format("invalid value for flexFlow: %s", log.p(value)))
    end
end

--- Represents a flex direction value.
---
--- Available options:
---
--- - ``"row"``: flex positions items horizontally;
--- - ``"column"``: flex positions items vertically.
---
--- @alias ammgui.css.rule.FlexDirectionValue
--- |ammgui.css.rule.GlobalValue
--- |"row"
--- |"column"

--- @type ammgui.css.rule.FlexDirectionValue?
ns.Rule.flexDirection = nil
ns.Resolved.flexDirection = resolver(
    ns.Rule.flexDirection,
    {
        unset = "initial",
        initial = "row",
        ["row"] = "row",
        ["column"] = "column",
    },
    {},
    parseFail
)

--- Represents a unitless number value.
---
--- @alias ammgui.css.rule.NumberValue
--- |ammgui.css.rule.GlobalValue
--- |number

--- @type ammgui.css.rule.NumberValue?
ns.Rule.flexGrow = nil
ns.Resolved.flexGrow = resolver(
    ns.Rule.flexGrow,
    {
        unset = "initial",
        initial = 0,
    },
    {},
    parseFloat
)

--- @type ammgui.css.rule.NumberValue?
ns.Rule.flexShrink = nil
ns.Resolved.flexShrink = resolver(
    ns.Rule.flexShrink,
    {
        unset = "initial",
        initial = 1,
    },
    {},
    parseFloat
)

--- @type ammgui.css.rule.WidthValue?
ns.Rule.flexBasis = nil
ns.Resolved.flexBasis = resolver(
    ns.Rule.flexBasis,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-contentp",
    },
    {},
    parseLength
)

--- Represents a flex wrapping value.
---
--- Available options:
---
--- - ``"wrap"``: flex will wrap items if they don't fit the containing container's
---   dimensions;
--- - ``"nowrap"``: flex will not wrap items, and will attempt to stretch or shrink
---   them according to their `flexGrow` and `flexShrink`.
---
--- @alias ammgui.css.rule.FlexWrapValue
--- |ammgui.css.rule.GlobalValue
--- |"wrap"
--- |"nowrap"

--- @type ammgui.css.rule.FlexWrapValue?
ns.Rule.flexWrap = nil
ns.Resolved.flexWrap = resolver(
    ns.Rule.flexWrap,
    {
        unset = "initial",
        initial = "nowrap",
        ["wrap"] = "wrap",
        ["nowrap"] = "nowrap",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.alignContent` property.
---
--- Available options:
---
--- TODO!
---
--- @alias ammgui.css.rule.AlignContentValue
--- |ammgui.css.rule.GlobalValue
--- |"normal"
--- |"start"
--- |"center"
--- |"end"
--- |"flex-start"
--- |"flex-end"
--- |"baseline"
--- |"first baseline"
--- |"last baseline"
--- |"space-between"
--- |"space-around"
--- |"space-evenly"
--- |"stretch"

--- @type ammgui.css.rule.AlignContentValue?
ns.Rule.alignContent = nil
ns.Resolved.alignContent = resolver(
    ns.Rule.alignContent,
    {
        unset = "initial",
        initial = "normal",
        ["normal"] = "normal",
        ["start"] = "start",
        ["center"] = "center",
        ["end"] = "end",
        ["flex-start"] = "start",
        ["flex-end"] = "end",
        ["baseline"] = "first baseline",
        ["first baseline"] = "first baseline",
        ["last baseline"] = "last baseline",
        ["space-between"] = "space-between",
        ["space-around"] = "space-around",
        ["space-evenly"] = "space-evenly",
        ["stretch"] = "stretch",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.alignItems` property.
---
--- Available options:
---
--- TODO!
---
--- @alias ammgui.css.rule.AlignItemsValue
--- |ammgui.css.rule.GlobalValue
--- |"normal"
--- |"start"
--- |"center"
--- |"end"
--- |"self-start"
--- |"self-end"
--- |"flex-start"
--- |"flex-end"
--- |"baseline"
--- |"first baseline"
--- |"last baseline"
--- |"stretch"

--- @type ammgui.css.rule.AlignItemsValue?
ns.Rule.alignItems = nil
ns.Resolved.alignItems = resolver(
    ns.Rule.alignItems,
    {
        unset = "initial",
        initial = "normal",
        ["normal"] = "normal",
        ["start"] = "start",
        ["center"] = "center",
        ["end"] = "end",
        ["self-start"] = "start",
        ["self-end"] = "end",
        ["flex-start"] = "start",
        ["flex-end"] = "end",
        ["baseline"] = "first baseline",
        ["first baseline"] = "first baseline",
        ["last baseline"] = "last baseline",
        ["stretch"] = "stretch",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.alignSelf` property.
---
--- Available options:
---
--- TODO!
---
--- @alias ammgui.css.rule.AlignSelfValue
--- |ammgui.css.rule.AlignItemsValue
--- |"auto"

--- @type ammgui.css.rule.AlignSelfValue?
ns.Rule.alignSelf = nil
ns.Resolved.alignSelf = resolver(
    ns.Rule.alignSelf,
    {
        unset = "initial",
        initial = "auto",
        ["normal"] = "normal",
        ["auto"] = "auto",
        ["start"] = "start",
        ["center"] = "center",
        ["self-start"] = "start",
        ["self-end"] = "end",
        ["flex-start"] = "start",
        ["flex-end"] = "end",
        ["baseline"] = "first baseline",
        ["first baseline"] = "first baseline",
        ["last baseline"] = "last baseline",
        ["stretch"] = "stretch",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.justifyContent` property.
---
--- Available options:
---
--- TODO!
---
--- @alias ammgui.css.rule.JustifyContentValue
--- |ammgui.css.rule.GlobalValue
--- |"normal"
--- |"start"
--- |"center"
--- |"end"
--- |"left"
--- |"right"
--- |"flex-start"
--- |"flex-end"
--- |"space-between"
--- |"space-around"
--- |"space-evenly"
--- |"stretch"

--- @type ammgui.css.rule.JustifyContentValue?
ns.Rule.justifyContent = nil
ns.Resolved.justifyContent = resolver(
    ns.Rule.justifyContent,
    {
        unset = "initial",
        initial = "normal",
        ["normal"] = "normal",
        ["start"] = "start",
        ["center"] = "center",
        ["end"] = "end",
        ["left"] = "start",
        ["right"] = "end",
        ["flex-start"] = "start",
        ["flex-end"] = "end",
        ["space-between"] = "space-between",
        ["space-around"] = "space-around",
        ["space-evenly"] = "space-evenly",
        ["stretch"] = "stretch",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.justifyItems` property.
---
--- Available options:
---
--- TODO!
---
--- @alias ammgui.css.rule.JustifyItemsValue
--- |ammgui.css.rule.GlobalValue
--- |"normal"
--- |"start"
--- |"center"
--- |"end"
--- |"left"
--- |"right"
--- |"self-start"
--- |"self-end"
--- |"flex-start"
--- |"flex-end"
--- |"baseline"
--- |"first baseline"
--- |"last baseline"
--- |"stretch"

--- @type ammgui.css.rule.JustifyItemsValue?
ns.Rule.justifyItems = nil
ns.Resolved.justifyItems = resolver(
    ns.Rule.justifyItems,
    {
        unset = "initial",
        initial = "normal",
        ["normal"] = "normal",
        ["start"] = "start",
        ["center"] = "center",
        ["end"] = "end",
        ["left"] = "start",
        ["right"] = "end",
        ["self-start"] = "start",
        ["self-end"] = "end",
        ["flex-start"] = "start",
        ["flex-end"] = "end",
        ["baseline"] = "first baseline",
        ["first baseline"] = "first baseline",
        ["last baseline"] = "last baseline",
        ["stretch"] = "stretch",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.justifyItems` property.
---
--- Available options:
---
--- TODO!
---
--- @alias ammgui.css.rule.JustifySelfValue
--- |ammgui.css.rule.JustifyItemsValue
--- |"auto"

--- @type ammgui.css.rule.JustifySelfValue?
ns.Rule.justifySelf = nil
ns.Resolved.justifySelf = resolver(
    ns.Rule.justifySelf,
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["normal"] = "normal",
        ["start"] = "start",
        ["center"] = "center",
        ["end"] = "end",
        ["left"] = "start",
        ["right"] = "end",
        ["self-start"] = "start",
        ["self-end"] = "end",
        ["flex-start"] = "start",
        ["flex-end"] = "end",
        ["baseline"] = "first baseline",
        ["first baseline"] = "first baseline",
        ["last baseline"] = "last baseline",
        ["stretch"] = "stretch",
    },
    {},
    parseFail
)

--- Shorthand to set `rowGap` and `columnGap` at once.
---
--- If given one value, sets both `rowGap` and `columnGap`.
---
--- If given an array of two values, sets them to `rowGap` and `columnGap` respectively.
---
--- @type
--- | ammgui.css.rule.GapValue
--- | [ammgui.css.rule.GapValue]
--- | [ammgui.css.rule.GapValue, ammgui.css.rule.GapValue]
--- | nil
ns.Rule.gap = nil
ruleSetters.gap = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        rule.rowGap = value[1]
        rule.columnGap = value[1]
    elseif #value == 2 then
        rule.rowGap = value[1]
        rule.columnGap = value[2]
    else
        error(string.format("invalid value for gap: %s", log.p(value)))
    end
end

--- Represents a value for `~Rule.rowGap` and `~Rule.columnGap` properties.
---
--- This value sets gap sizes between child elements. Since `ammgui` does not implement
--- margins, `~Rule.rowGap` and `~Rule.columnGap` affects elements
--- with ~`Rule.display` ``block`` as well.
---
--- Available options:
---
--- - ``"normal"``: ``0`` for ~`Rule.display` ``block`` elements,
---   ``1em`` for ~`Rule.display` ``flex``;
--- - `string`: number with one of the following units: ``px``, ``pt``, ``em``, ``%``;
--- - `integer`: treated as ``px``.
---
--- @alias ammgui.css.rule.GapValue
--- | ammgui.css.rule.GlobalValue
--- | ammgui.css.rule.LengthValue
--- | "normal"

--- @type ammgui.css.rule.GapValue?
ns.Rule.columnGap = nil
ns.Resolved.columnGap = resolver(
    ns.Rule.columnGap,
    {
        unset = "initial",
        initial = "normal",
    },
    {
        normal = function(x, resolved)
            if resolved.display == "block" then
                return {0, "px"}
            else
                return parseLength("1em", resolved)
            end
        end
    },
    parseLength
)

--- @type ammgui.css.rule.GapValue?
ns.Rule.rowGap = nil
ns.Resolved.rowGap = resolver(
    ns.Rule.rowGap,
    {
        unset = "initial",
        initial = "normal",
    },
    {
        normal = function(x, resolved)
            if resolved.display == "block" then
                return {0, "px"}
            else
                return parseLength("1em", resolved)
            end
        end
    },
    parseLength
)

--- Shorthand to set `overflowX` and `overflowY` at once.
---
--- If given one value, sets both `overflowX` and `overflowY`.
---
--- If given an array of two values, sets them to `overflowX` and `overflowY` respectively.
---
--- @type
--- | ammgui.css.rule.OverflowValue
--- | [ammgui.css.rule.OverflowValue]
--- | [ammgui.css.rule.OverflowValue, ammgui.css.rule.OverflowValue]
--- | nil
ns.Rule.overflow = nil
ruleSetters.overflow = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        rule.overflowX = value[1]
        rule.overflowY = value[1]
    elseif #value == 2 then
        rule.overflowX = value[1]
        rule.overflowY = value[2]
    else
        error(string.format("invalid value for overflow: %s", log.p(value)))
    end
end

--- Represents a value for `~Rule.overflowX` and `~Rule.overflowY` properties.
---
--- Available options:
---
--- - ``"visible"``: overflowing elements are not clipped;
--- - ``"hidden"``: overflowing elements are clipped at borders of their parent node;
--- - ``"scroll"``: overflowing elements become scrollable;
--- - ``"sticky"``: custom value, same as ``scroll``, but if the element is scrolled
---   to the bottom, the scroll position sticks when new elements are added
---   to the container. This is useful for displaying logs and other streams
---   of information that appears at the bottom.
---
--- @alias ammgui.css.rule.OverflowValue
--- | ammgui.css.rule.GlobalValue
--- | "visible"
--- | "hidden"
--- | "scroll"
--- | "sticky"

--- @type ammgui.css.rule.OverflowValue?
ns.Rule.overflowX = nil
ns.Resolved.overflowX = resolver(
    ns.Rule.overflowX,
    {
        unset = "initial",
        initial = "visible",
        ["visible"] = "visible",
        ["hidden"] = "hidden",
        ["scroll"] = "scroll",
        ["sticky"] = "sticky",
    },
    {},
    parseFail
)

--- @type ammgui.css.rule.OverflowValue?
ns.Rule.overflowY = nil
ns.Resolved.overflowY = resolver(
    ns.Rule.overflowY,
    {
        unset = "initial",
        initial = "visible",
        ["visible"] = "visible",
        ["hidden"] = "hidden",
        ["scroll"] = "scroll",
        ["sticky"] = "sticky",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.textAlign` property.
---
--- Available options:
---
--- - ``"start"``: text is flushed to left. Since `ammgui` doesn't support
---   right-to-left scripts, this value is equivalent to ``"left"``;
--- - ``"end"``: text is flushed to right. Since `ammgui` doesn't support
---   right-to-left scripts, this value is equivalent to ``"right"``;
--- - ``"left"``: text is flushed to left;
--- - ``"right"``: text is flushed to right;
--- - ``"center"``: text is centered;
--- - ``"match-parent"``: text is flushed the same way as in the parent DOM node.
---    Since `ammgui` doesn't support right-to-left scripts,
---    this value is equivalent to ``"inherit"``;
---
--- @alias ammgui.css.rule.TextAlignValue
--- |ammgui.css.rule.GlobalValue
--- |"start"
--- |"end"
--- |"left"
--- |"right"
--- |"center"
--- |"match-parent"

--- @type ammgui.css.rule.TextAlignValue?
ns.Rule.textAlign = nil
ns.Resolved.textAlign = resolver(
    ns.Rule.textAlign,
    {
        unset = "inherit",
        initial = "start",
        ["start"] = "left",
        ["end"] = "right",
        ["left"] = "left",
        ["right"] = "right",
        ["center"] = "center",
        ["match-parent"] = "inherit",
    },
    {},
    parseFail
)

--- Represents values for `~Rule.textWrapMode` property.
---
--- Available options:
---
--- - ``"wrap"``: text is wrapped on whitespaces and after dashes;
--- - ``"nowrap"``: text is not wrapped.
---
--- @alias ammgui.css.rule.TextWrapModeValue?
--- |ammgui.css.rule.GlobalValue
--- |"wrap"
--- |"nowrap"

--- @type ammgui.css.rule.TextWrapModeValue
ns.Rule.textWrapMode = nil
ns.Resolved.textWrapMode = resolver(
    ns.Rule.textWrapMode,
    {
        unset = "inherit",
        initial = "wrap",
        ["wrap"] = "wrap",
        ["nowrap"] = "nowrap",
    },
    {},
    parseFail
)

--- @param context ammgui.css.rule.Rule[]
--- @param parent ammgui.css.rule.Resolved?
--- @param theme table<string, Color>
---
--- @generic T: ammgui.css.rule.Resolved
--- @param self T
--- @return T
function ns.Resolved:New(context, parent, theme)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui.css.rule.Rule[]
    self._context = context

    --- @private
    --- @type ammgui.css.rule.Resolved?
    self._parent = parent

    --- @private
    --- @type table<string, Color>
    self._theme = theme

    return self
end

function ns.Resolved:__index(name)
    return ns.Resolved._get(self, name, "unset")
end

--- @package
--- @param name string
--- @param unset string
function ns.Resolved:_get(name, unset)
    for _, rule in ipairs(rawget(self, "_context")) do
        local value = rule[name] or rule["all"]
        if value then
            value = ns.Resolved._process(self, name, value)
            if value ~= "revert" then
                self[name] = value -- cache value
                return value
            else
                error("TODO: support revert")
            end
        end
    end

    -- Value wasn't set by any CSS rule, treat as "unset".
    local value = ns.Resolved._process(self, name, unset)
    self[name] = value
    return value
end

--- @package
--- @param name string
--- @param value unknown
function ns.Resolved:_process(name, value)
    --- @type { literalValues: table<string, unknown>, functionalValues: table<string, fun(x: string, r: ammgui.css.rule.Resolved): unknown>, parser: fun(x: unknown, r: ammgui.css.rule.Resolved): unknown }?
    local resolver = ns.Resolved[name]
    if not resolver then
        error(string.format("unknown CSS property %s", name))
    end
    while resolver.literalValues[value] do
        local nextValue = resolver.literalValues[value]
        if nextValue == value then
            return nextValue
        else
            value = nextValue
        end
    end
    if resolver.functionalValues[value] then
        local nextValue = resolver.functionalValues[value](value, self)
        if nextValue then
            return nextValue
        else
            error(string.format("functional mapper for %s=%s didn't return a value", name, value))
        end
    end
    if value == "inherit" then
        return ns.Resolved._getInherited(self, name)
    end
    if value == "unset" or value == "initial" then
        error(string.format("no initial value for property %s", name))
    end
    return resolver.parser(value, self)
end

--- @package
function ns.Resolved:_getInherited(name)
    local parent = rawget(self, "_parent")
    if parent then
        return ns.Resolved._get(parent, name, "inherit")
    else
        -- Value is "inherit", but we've reached root, treat as "initial"
        return ns.Resolved._process(self, name, "initial")
    end
end

--- Process all compound properties like `~Rule.gap` and `~Rule.flex`
--- and assign them to their components.
---
--- @param data ammgui.css.rule.Rule
function ns.makeRule(data)
    local rule = {}
    for name, value in pairs(data) do
        if ruleSetters[name] then
            ruleSetters[name](rule, value)
        else
            rule[name] = value
        end
    end
    return rule
end

return ns
