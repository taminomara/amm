local class = require "ammcore.class"
local log = require "ammcore.log"
local selector = require "ammgui.css.selector"
local u = require "ammgui.css.units"

--- A CSS rule.
---
--- !doctype module
--- @class ammgui.css.rule
local ns = {}

--- @param literalValues table<string, any>
--- @param parser fun(x: unknown, r: ammgui.css.rule.Resolved, n: string): any
--- @param isLayoutSafe boolean
--- @return unknown
local function resolver(
    literalValues, parser, isLayoutSafe
)
    for value, mappedValue in ipairs(literalValues) do
        while mappedValue ~= value and literalValues[mappedValue] do
            mappedValue = literalValues[mappedValue]
        end
        literalValues[value] = mappedValue
    end
    return {
        literalValues = literalValues,
        parser = parser,
        isLayoutSafe = isLayoutSafe,
        __isResolver = true,
    } --[[ @as any ]]
end

--- @private
--- @type table<string, fun(self: ammgui.css.rule.Rule, value: unknown)>
local ruleSetters = {}

--- Contains values resolved for a concrete DOM node.
---
--- @class ammgui.css.rule.Resolved: ammcore.class.Base
ns.Resolved = class.create("Resolved")

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @return nil
local function parseFail(x, r, n)
    error(string.format("invalid %s value %s", n, log.pp(x)), 0)
end

--- @param x unknown
--- @param u string
--- @param n string
--- @return number value
--- @return string unit
local function parseUnit(x, u, n)
    if type(x) == "number" then
        return x, u
    elseif
        type(x) == "table"
        and #x == 2
        and type(x[1]) == "number"
        and type(x[2]) == "string"
    then
        ---@diagnostic disable-next-line: redundant-return-value
        return table.unpack(x)
    else
        error(string.format("invalid %s value %s", n, log.pp(x)))
    end
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @param n string
--- @return [number, "px"|"%"]
local function parseLength(x, r, n)
    local n, u = parseUnit(x, "px", n)
    if u == "em" then
        local nn, nu = table.unpack(r.fontSize)
        n = n * nn
        u = nu
    end
    if u ~= "px" and u ~= "%" then
        local units = r._units
        if not units[u] then
            error(string.format("unknown %s unit %s", n, log.pp(u)), 0)
        end
        n = n * units[u]
        u = "px"
    end
    return { n, u }
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @return [number, "px"|"%"]
local function parsePositiveLength(x, r, n)
    local val = parseLength(x, r, n)
    if val[1] < 0 then
        error(string.format("%s can't be negative", n), 0)
    end
    return val
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @param n string
--- @return [number, "px"]
local function parseFontSize(x, r, n)
    local n, u = parseUnit(x, "px", n)
    if n < 0 then
        error(string.format("%s can't be negative", n), 0)
    end
    if u == "%" then
        local nn, nu = table.unpack(ns.Resolved._getInherited(r, "fontSize"))
        n = n * nn / 100
        u = nu
    elseif u == "em" then
        local nn, nu = table.unpack(ns.Resolved._getInherited(r, "fontSize"))
        n = n * nn
        u = nu
    end
    if u ~= "px" then
        local units = r._units
        if not units[u] then
            error(string.format("unknown %s unit %s", n, log.pp(u)), 0)
        end
        n = n * units[u]
        u = "px"
    end
    return { n, u }
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @param n string
--- @return [number, "px"|""]
local function parseLineHeight(x, r, n)
    local n, u = parseUnit(x, "", n)
    if n < 0 then
        error(string.format("%s can't be negative", n), 0)
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
    if u ~= "px" and u ~= "" then
        local units = r._units
        if not units[u] then
            error(string.format("unknown %s unit %s", n, log.pp(u)), 0)
        end
        n = n * units[u]
        u = "px"
    end
    return { n, u }
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @param n string
--- @return Color
local function parseColor(x, r, n)
    local theme = r._theme

    if type(x) == "string" then x = x:lower() end
    while theme[x] do
        x = theme[x]
        if type(x) == "string" then x = x:lower() end
    end

    if type(x) == "string" then
        if x == "transparent" then
            return structs.Color { 0, 0, 0, 0 }
        elseif x == "currentcolor" then
            if n == "color" then
                return r:_getInherited(n)
            else
                return r.color
            end
        elseif x == "currentbackgroundcolor" then
            if n == "backgroundColor" then
                return r:_getInherited(n)
            else
                return r.backgroundColor
            end
        end

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
            error(string.format("invalid %s value %s", n, log.pp(x)), 0)
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
        error(string.format("invalid %s value %s", n, log.pp(x)), 0)
    end
end

--- @param x unknown
--- @param r ammgui.css.rule.Resolved
--- @param n string
--- @return number
local function parseFloat(x, r, n)
    if type(x) == "number" then
        return x
    else
        error(string.format("invalid %s value %s", n, log.pp(x)), 0)
    end
end

--- .. dropdown:: Common CSS values
---
---    .. list-table::
---
---       * - ``"unset"``
---         - Use inherited value if property inherits, or initial value if not.
---       * - ``"inherit"``
---         - Use the value from the parent DOM node.
---       * - ``"initial"``
---         - Use initial value.

--- @alias ammgui.css.rule.GlobalValue
--- |"unset"
--- |"inherit"
--- |"initial"

--- .. dropdown:: Color values
---
---    .. list-table::
---
---       * - `Color`
---         - An arbitrary color.
---       * - `string`
---         - A color in a hexadecimal format.
---       * - ``"transparent"``
---         - No color at all.
---       * - ``"currentColor"``
---         - Use value from `~Rule.color`.
---       * - ``"currentBackgroundColor"``
---         - Use value from `~Rule.backgroundColor`.

--- @alias ammgui.css.rule.ColorValue
--- |Color
--- |string
--- |"transparent"
--- |"currentcolor"
--- |"currentbackgroundcolor"
--- |ammgui.css.rule.GlobalValue

--- @alias ammgui.css.rule.Unit
--- |"px"
--- |"pt"
--- |"pc"
--- |"Q"
--- |"mm"
--- |"cm"
--- |"m"
--- |"in"
--- |"em"
--- |"rem"
--- |"vw"
--- |"vh"
--- |"vmin"
--- |"vmax"
--- |"%"

--- .. dropdown:: Units
---
---    **Absolute units:**
---
---    .. list-table::
---
---       * - ``"px"``
---         - A pixel. A single block of a Large Display is ``300x300`` pixels.
---       * - ``"pt"``
---         - A point, used for font sizes. This is the unit that GPU T2 accepts
---           as font size in all of its APIs. One point approximately equals ``1.8`` px.
---       * - ``"pc"``
---         - A pica, equals ``12`` points.
---       * - ``"Q"``
---         - A quarter of a millimeter when rendered on the Large Display.
---       * - ``"mm"``
---         - A millimeter when rendered on the Large Display.
---       * - ``"cm"``
---         - A centimeter when rendered on the Large Display.
---       * - ``"m"``
---         - A meter when rendered on the Large Display, equals to one Large Display block.
---       * - ``"in"``
---         - An inch when rendered on the Large Display.
---
---    **Relative units:**
---
---    .. list-table::
---
---       * - ``"em"``
---         - Equals to the `fontSize` value of the DOM node. That is, if a DOM node's
---           `fontSize` is set to ``12px``, then ``1em`` is ``12px``,
---           ``2em`` is ``24px``, and so on.
---       * - ``"rem"``
---         - Equals to the `fontSize` value of the root node, a.k.a. the default
---           font size. You can change this value using `ammgui.App.setRootFontSize`.
---       * - ``"vw"``
---         - Equals to ``1%`` of the width of the attached screen. That is, ``100vw``
---           is exactly the width of the screen. VW means "Viewport Width".
---       * - ``"vh"``
---         - Equals to ``1%`` of the height of the attached screen. That is, ``100vh``
---           is exactly the height of the screen. VH means "Viewport Height".
---       * - ``"vmin"``
---         - Equals to ``min(1vh, 1vw)``.
---       * - ``"vmax"``
---         - Equals to ``max(1vh, 1vw)``.
---       * - ``"%"``
---         - Depending on CSS property, relative ``%`` value may mean different things.
---           For length properties, percentages usually refer to the parent node's
---           width or height; for `lineHeight`, percentages refer to `fontSize`,
---           and for `fontSize` itself, percentages refer to the parent's node `fontSize`.

--- @alias ammgui.css.rule.LengthValueWithUnit
--- |[number, ammgui.css.rule.Unit]

--- .. dropdown:: Length values
---
---    .. list-table::
---
---       * - `[number, string]`
---         - Number with one of the units described below.
---       * - `number`
---         - Treated as ``px``.

--- @alias ammgui.css.rule.LengthValue
--- |number
--- |ammgui.css.rule.LengthValueWithUnit
--- |ammgui.css.rule.GlobalValue

--- @alias ammgui.css.rule.NumberValue
--- |number
--- |ammgui.css.rule.GlobalValue

--- Base class for a CSS rule, contains auxiliary values.
---
--- !doc members: !
--- @class ammgui.css.rule.RuleBase
local RuleBase = {}

--- Source, indicates file and line where this rule was created.
---
--- @type string?
RuleBase.loc = nil

--- Common CSS properties.
---
--- !doc members: !
--- @class ammgui.css.rule.CommonProperties
local CommonProperties = {}

--- A catch-all property, allows resetting values for all other properties.
---
--- @type ammgui.css.rule.GlobalValue?
CommonProperties.all = nil

--- CSS properties that affect text rendering.
---
--- !doc members: !
--- @class ammgui.css.rule.TextProperties: ammgui.css.rule.CommonProperties
local TextProperties = {}

--- Shorthand to set `fontSize`, `lineHeight`, and `fontFamily` at once.
---
--- If given an array of two values, first is assigned to `fontSize`
--- and second to `fontFamily`.
---
--- If given an array of three values, first is assigned to `fontSize`,
--- second to `lineHeight`, and third to `fontFamily`.
---
--- @type
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.FontFamily]
--- | [ammgui.css.rule.LengthValue, ammgui.css.rule.LineHeight, ammgui.css.rule.FontFamily]
--- | nil
TextProperties.font = nil
ruleSetters.font = function(rule, value)
    if type(value) ~= "table" then
        error(string.format("invalid font value: %s", log.pp(value)))
    end
    if #value == 2 then
        rule.fontSize, rule.fontFamily = table.unpack(value)
    elseif #value == 3 then
        rule.fontSize, rule.lineHeight, rule.fontFamily = table.unpack(value)
    else
        error(string.format("invalid font value: %s", log.pp(value)))
    end
end

--- Font size for any text in this DOM node.
---
--- @type ammgui.css.rule.LengthValue?
TextProperties.fontSize = nil
ns.Resolved.fontSize = resolver(
    {
        unset = "inherit",
        initial = u.rem(1),
    },
    parseFontSize,
    false
) --[[ @as [number, "px"] ]]

--- @alias ammgui.css.rule.FontFamily
--- |"normal"
--- |"monospace"
--- |ammgui.css.rule.GlobalValue

--- Font that is used for any text in this DOM node.
---
--- .. dropdown:: Font Family values
---
---    .. list-table::
---
---       * - ``"normal"``
---         - Corresponds to the default sans-serif font.
---       * - ``"monospace"``
---         - Corresponds to the default monospace font.
---
---    Custom fonts are not supported.
---
--- @type ammgui.css.rule.FontFamily?
TextProperties.fontFamily = nil
ns.Resolved.fontFamily = resolver(
    {
        unset = "inherit",
        initial = "normal",
        ["normal"] = "normal",
        ["monospace"] = "monospace",
    },
    parseFail,
    false
) --[[ @as "normal"|"monospace" ]]

--- @alias ammgui.css.rule.LineHeight
--- |"normal"
--- |number
--- |ammgui.css.rule.LengthValueWithUnit
--- |ammgui.css.rule.GlobalValue

--- Height of a single line of text.
---
--- .. raw:: html
---    :file: ../../docs/_embeds/FontMetrics.html
---
--- .. dropdown:: Line Height values
---
---    .. list-table::
---
---       * - ``"normal"``
---         - Default line height, equals to the value of ``1.2``.
---       * - `[number, string]`
---         - Number with one of the units described below.
---       * - `number`
---         - Scaling factor for `fontSize`, i.e. line height is calculated
---           as ``lineHeight * fontSize``.
---
--- @type ammgui.css.rule.LineHeight?
TextProperties.lineHeight = nil
ns.Resolved.lineHeight = resolver(
    {
        unset = "inherit",
        initial = "normal",
        ["normal"] = 1.2,
    },
    parseLineHeight,
    false
) --[[ @as [number, "px"|""] ]]

--- @type ammgui.css.rule.ColorValue?
TextProperties.color = nil
ns.Resolved.color = resolver(
    {
        unset = "inherit",
        initial = "canvastext",
        currentcolor = "inherit",
    },
    parseColor,
    true
) --[[ @as Color ]]

--- Represents values for `~Rule.textWrapMode` property.
---
--- Available options:
---
--- - ``"wrap"``: text is wrapped on whitespaces and after dashes;
--- - ``"nowrap"``: text is not wrapped.

--- @alias ammgui.css.rule.TextWrapModeValue?
--- |"wrap"
--- |"nowrap"
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.TextWrapModeValue
TextProperties.textWrapMode = nil
ns.Resolved.textWrapMode = resolver(
    {
        unset = "inherit",
        initial = "wrap",
        ["wrap"] = "wrap",
        ["nowrap"] = "nowrap",
    },
    parseFail,
    false
) --[[ @as "wrap"|"nowrap" ]]

--- CSS properties that affect rendering of block elements.
---
--- !doc members: !
--- @class ammgui.css.rule.BlockProperties: ammgui.css.rule.TextProperties
local BlockProperties = {}

--- @type ammgui.css.rule.ColorValue?
BlockProperties.backgroundColor = nil
ns.Resolved.backgroundColor = resolver(
    {
        unset = "initial",
        initial = "transparent",
        currentbackgroundcolor = "inherit",
    },
    parseColor,
    true
) --[[ @as Color ]]

--- @alias ammgui.css.rule.MarginValue
--- |ammgui.css.rule.LengthValue
--- |"auto"
--- |ammgui.css.rule.GlobalValue

--- Shorthand to set `marginTop`, `marginRight`, `marginBottom`, and `marginLeft`
--- at once.
---
--- If given a single value, sets all margins to this value.
---
--- If given an array of two values, sets `marginTop` and `marginBottom` to the
--- first value, `marginRight` and `marginLeft` to the second.
---
--- If given an array of three values, sets `marginTop` to the
--- first value, `marginRight` and `marginLeft` to the second,
--- `marginBottom` to the third.
---
--- If given an array of four values, sets `marginTop`, `marginRight`,
--- `marginBottom`, and `marginLeft` respectively.
---
--- @type
--- | ammgui.css.rule.MarginValue
--- | [ammgui.css.rule.MarginValue]
--- | [ammgui.css.rule.MarginValue, ammgui.css.rule.MarginValue]
--- | [ammgui.css.rule.MarginValue, ammgui.css.rule.MarginValue, ammgui.css.rule.MarginValue]
--- | [ammgui.css.rule.MarginValue, ammgui.css.rule.MarginValue, ammgui.css.rule.MarginValue, ammgui.css.rule.MarginValue]
--- | nil
BlockProperties.margin = nil
ruleSetters.margin = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        rule.marginTop = value[1]
        rule.marginRight = value[1]
        rule.marginBottom = value[1]
        rule.marginLeft = value[1]
    elseif #value == 2 then
        rule.marginTop = value[1]
        rule.marginRight = value[2]
        rule.marginBottom = value[1]
        rule.marginLeft = value[2]
    elseif #value == 3 then
        rule.marginTop = value[1]
        rule.marginRight = value[2]
        rule.marginBottom = value[3]
        rule.marginLeft = value[2]
    elseif #value == 4 then
        rule.marginTop = value[1]
        rule.marginRight = value[2]
        rule.marginBottom = value[3]
        rule.marginLeft = value[4]
    else
        error(string.format("invalid margin value: %s", log.pp(value)))
    end
end

--- @type ammgui.css.rule.MarginValue?
BlockProperties.marginTop = nil
ns.Resolved.marginTop = resolver(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parseLength,
    false
) --[[ @as [number, "px"|"%"]|"auto" ]]

--- @type ammgui.css.rule.MarginValue?
BlockProperties.marginLeft = nil
ns.Resolved.marginLeft = resolver(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parseLength,
    false
) --[[ @as [number, "px"|"%"]|"auto" ]]

--- @type ammgui.css.rule.MarginValue?
BlockProperties.marginRight = nil
ns.Resolved.marginRight = resolver(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parseLength,
    false
) --[[ @as [number, "px"|"%"]|"auto" ]]

--- @type ammgui.css.rule.MarginValue?
BlockProperties.marginBottom = nil
ns.Resolved.marginBottom = resolver(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parseLength,
    false
) --[[ @as [number, "px"|"%"]|"auto" ]]

--- @alias ammgui.css.rule.MarginTrimValue?
--- |"none"
--- |"block"
--- |"block-start"
--- |"block-end"
--- |"inline"
--- |"inline-start"
--- |"inline-end"
--- |ammgui.css.rule.GlobalValue

--- Controls trimming of margins of child elements.
---
--- Available options:
---
--- - ``"none"``: margins are not trimmed;
--- - ``"block"``: block-start (top) margin of the first child and block-end (bottom)
---   margin of the last child are trimmed to zero;
--- - ``"block-start"``: block-start (top) margin of the first child is trimmed to zero;
--- - ``"block-end"``: block-end (bottom) margin of the last child is trimmed to zero;
--- - ``"inline"``: inline-start (left) margin of the first inline element
---   and inline-end (right) margin of the last inline element are trimmed to zero;
--- - ``"inline-start"``: inline-start (left) margin of the first inline element
---   is trimmed to zero;
--- - ``"inline-end"``: inline-end (right) margin of the last inline element
---   is trimmed to zero;
---
--- @type ammgui.css.rule.MarginTrimValue
TextProperties.marginTrim = nil
ns.Resolved.marginTrim = resolver(
    {
        unset = "inherit",
        initial = "none",
        ["none"] = "none",
        ["block"] = "block",
        ["block-start"] = "block-start",
        ["block-end"] = "block-end",
        ["inline"] = "inline",
        ["inline-start"] = "inline-start",
        ["inline-end"] = "inline-end",
    },
    parseFail,
    false
) --[[ @as "none"|"block"|"block-start"|"block-end"|"inline"|"inline-start"|"inline-end" ]]

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
BlockProperties.padding = nil
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
        error(string.format("invalid padding value: %s", log.pp(value)))
    end
end

--- @type ammgui.css.rule.LengthValue?
BlockProperties.paddingTop = nil
ns.Resolved.paddingTop = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.LengthValue?
BlockProperties.paddingLeft = nil
ns.Resolved.paddingLeft = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.LengthValue?
BlockProperties.paddingRight = nil
ns.Resolved.paddingRight = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.LengthValue?
BlockProperties.paddingBottom = nil
ns.Resolved.paddingBottom = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.LengthValue?
BlockProperties.outlineRadius = nil
ns.Resolved.outlineRadius = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    true
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.LengthValue?
BlockProperties.outlineWidth = nil
ns.Resolved.outlineWidth = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.ColorValue?
BlockProperties.outlineTint = nil
ns.Resolved.outlineTint = resolver(
    {
        unset = "initial",
        initial = "currentbackgroundcolor",
    },
    parseColor,
    true
) --[[ @as Color ]]

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
BlockProperties.gap = nil
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
        error(string.format("invalid gap value: %s", log.pp(value)))
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
--- - `string`: number with one of the following units: ``px``, ``pt``, ``em``, ``%``;
--- - `integer`: treated as ``px``.

--- @alias ammgui.css.rule.GapValue
--- | ammgui.css.rule.GlobalValue
--- | ammgui.css.rule.LengthValue
--- | "normal"

--- @type ammgui.css.rule.GapValue?
BlockProperties.columnGap = nil
ns.Resolved.columnGap = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.GapValue?
BlockProperties.rowGap = nil
ns.Resolved.rowGap = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- Represents a value for `~Rule.overflow`.
---
--- Available options:
---
--- - ``"visible"``: overflowing elements are not clipped;
--- - ``"hidden"``: overflowing elements are clipped at borders of their parent node;

--- @alias ammgui.css.rule.OverflowValue
--- | ammgui.css.rule.GlobalValue
--- | "visible"
--- | "hidden"

--- @type ammgui.css.rule.OverflowValue?
BlockProperties.overflow = nil
ns.Resolved.overflow = resolver(
    {
        unset = "initial",
        initial = "visible",
        ["visible"] = "visible",
        ["hidden"] = "hidden",
    },
    parseFail,
    false
) --[[ @as "visible"|"hidden" ]]

--- @alias ammgui.css.rule.WidthValue
--- |"auto"
--- |"min-content"
--- |"fit-content"
--- |"max-content"
--- |ammgui.css.rule.LengthValue
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.WidthValue?
BlockProperties.width = nil
ns.Resolved.width = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"]|"auto"|"min-content"|"fit-content"|"max-content" ]]

--- @type ammgui.css.rule.WidthValue?
BlockProperties.minWidth = nil
ns.Resolved.minWidth = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = 0,
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"]|"min-content"|"fit-content"|"max-content" ]]

--- @type ammgui.css.rule.WidthValue?
BlockProperties.maxWidth = nil
ns.Resolved.maxWidth = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = math.huge,
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"]|"min-content"|"fit-content"|"max-content" ]]

--- @alias ammgui.css.rule.Height
--- |"auto"
--- |ammgui.css.rule.LengthValue
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.Height?
BlockProperties.height = nil
ns.Resolved.height = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"]|"auto" ]]

--- @type ammgui.css.rule.Height?
BlockProperties.minHeight = nil
ns.Resolved.minHeight = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = 0,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- @type ammgui.css.rule.Height?
BlockProperties.maxHeight = nil
ns.Resolved.maxHeight = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = math.huge,
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"] ]]

--- Properties for flex elements.
---
--- !doc members: !
--- @class ammgui.css.rule.FlexProperties: ammgui.css.rule.BlockProperties
local FlexProperties = {}

--- @alias ammgui.css.rule.FlexDirectionValue
--- |"row"
--- |"column"
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.FlexDirectionValue?
FlexProperties.flexDirection = nil
ns.Resolved.flexDirection = resolver(
    {
        unset = "initial",
        initial = "row",
        ["row"] = "row",
        ["column"] = "column",
    },
    parseFail,
    false
) --[[ @as "row"|"column" ]]

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
--- as `flexGrow`/`flexShrink`, and other values are treated as `flexBasis`.
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
FlexProperties.flex = nil
ruleSetters.flex = function(rule, value)
    if type(value) ~= "table" then
        value = { value }
    end
    if #value == 1 then
        if type(value[1]) == "number" then
            rule.flexGrow = value[1]
            rule.flexShrink = 1
            rule.flexBasis = 0
        else
            rule.flexGrow = 1
            rule.flexShrink = 1
            rule.flexBasis = value[1]
        end
    elseif #value == 2 then
        rule.flexGrow = value[1]
        if type(value[2]) == "number" then
            rule.flexShrink = value[2]
            rule.flexBasis = 0
        else
            rule.flexShrink = 1
            rule.flexBasis = value[2]
        end
    elseif #value == 3 then
        rule.flexGrow = value[1]
        rule.flexShrink = value[2]
        rule.flexBasis = value[3]
    else
        error(string.format("invalid flex value: %s", log.pp(value)))
    end
end

--- Represents a `flexWrap` value.
---
--- Available options:
---
--- - ``"wrap"``: flex will wrap items if they don't fit the containing container's
---   dimensions;
--- - ``"nowrap"``: flex will not wrap items, and will attempt to stretch or shrink
---   them according to their `flexGrow` and `flexShrink`.

--- @alias ammgui.css.rule.FlexWrapValue
--- |"wrap"
--- |"nowrap"
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.FlexWrapValue?
FlexProperties.flexWrap = nil
ns.Resolved.flexWrap = resolver(
    {
        unset = "initial",
        initial = "nowrap",
        ["wrap"] = "wrap",
        ["nowrap"] = "nowrap",
    },
    parseFail,
    false
) --[[ @as "wrap"|"nowrap" ]]

--- Represents values for `~Rule.alignContent` property.
---
--- Available options:
---
--- TODO!

--- @alias ammgui.css.rule.AlignContentValue
--- |"normal"
--- |"start"
--- |"center"
--- |"end"
--- |"flex-start"
--- |"flex-end"
--- |"space-between"
--- |"space-around"
--- |"space-evenly"
--- |"stretch"
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.AlignContentValue?
FlexProperties.alignContent = nil
ns.Resolved.alignContent = resolver(
    {
        unset = "initial",
        initial = "normal",
        ["normal"] = "start",
        ["start"] = "start",
        ["center"] = "center",
        ["end"] = "end",
        ["flex-start"] = "start",
        ["flex-end"] = "end",
        ["space-between"] = "space-between",
        ["space-around"] = "space-around",
        ["space-evenly"] = "space-evenly",
        ["stretch"] = "stretch",
    },
    parseFail,
    false
) --[[ @as "start"|"center"|"end"|"space-between"|"space-around"|"space-evenly"|"stretch" ]]

--- Represents values for `~Rule.alignItems` property.
---
--- Available options:
---
--- TODO!

--- @alias ammgui.css.rule.AlignItemsValue
--- |"normal"
--- |"start"
--- |"center"
--- |"end"
--- |"self-start"
--- |"self-end"
--- |"flex-start"
--- |"flex-end"
--- |"safe start"
--- |"safe center"
--- |"safe end"
--- |"safe self-start"
--- |"safe self-end"
--- |"safe flex-start"
--- |"safe flex-end"
--- |"unsafe start"
--- |"unsafe center"
--- |"unsafe end"
--- |"unsafe self-start"
--- |"unsafe self-end"
--- |"unsafe flex-start"
--- |"unsafe flex-end"
--- |"baseline"
--- |"first baseline"
--- |"last baseline"
--- |"stretch"
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.AlignItemsValue?
FlexProperties.alignItems = nil
ns.Resolved.alignItems = resolver(
    {
        unset = "initial",
        initial = "normal",
        ["normal"] = "stretch",
        ["center"] = "safe center",
        ["safe center"] = "safe center",
        ["unsafe center"] = "unsafe center",
        ["start"] = "safe start",
        ["safe start"] = "safe start",
        ["unsafe start"] = "unsafe start",
        ["end"] = "safe end",
        ["safe end"] = "safe end",
        ["unsafe end"] = "unsafe end",
        ["self-start"] = "safe start",
        ["safe self-start"] = "safe start",
        ["unsafe self-start"] = "unsafe start",
        ["self-end"] = "safe end",
        ["safe self-end"] = "safe end",
        ["unsafe self-end"] = "unsafe end",
        ["flex-start"] = "safe start",
        ["safe flex-start"] = "safe start",
        ["unsafe flex-start"] = "unsafe start",
        ["flex-end"] = "safe end",
        ["safe flex-end"] = "safe end",
        ["unsafe flex-end"] = "unsafe end",
        ["baseline"] = "first baseline",
        ["first baseline"] = "first baseline",
        ["last baseline"] = "last baseline",
        ["stretch"] = "stretch",
    },
    parseFail,
    false
) --[[ @as "safe start"|"unsafe start"|"safe center"|"unsafe center"|"safe end"|"unsafe end"|"first baseline"|"last baseline"|"stretch" ]]

--- Represents values for `~Rule.justifyContent` property.
---
--- Available options:
---
--- TODO!

--- @alias ammgui.css.rule.JustifyContentValue
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
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.JustifyContentValue?
FlexProperties.justifyContent = nil
ns.Resolved.justifyContent = resolver(
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
    parseFail,
    false
) --[[ @as "normal"|"start"|"center"|"end"|"space-between"|"space-around"|"space-evenly"|"stretch" ]]

--- @type ammgui.css.rule.NumberValue?
BlockProperties.flexGrow = nil
ns.Resolved.flexGrow = resolver(
    {
        unset = "initial",
        initial = 0,
    },
    parseFloat,
    false
) --[[ @as number ]]

--- @type ammgui.css.rule.NumberValue?
BlockProperties.flexShrink = nil
ns.Resolved.flexShrink = resolver(
    {
        unset = "initial",
        initial = 1,
    },
    parseFloat,
    false
) --[[ @as number ]]

--- @type ammgui.css.rule.WidthValue?
BlockProperties.flexBasis = nil
ns.Resolved.flexBasis = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parsePositiveLength,
    false
) --[[ @as [number, "px"|"%"]|"auto"|"min-content"|"fit-content"|"max-content" ]]

--- Represents values for `~Rule.alignSelf` property.
---
--- Available options:
---
--- TODO!

--- @alias ammgui.css.rule.AlignSelfValue
--- |"auto"
--- |ammgui.css.rule.AlignItemsValue

--- @type ammgui.css.rule.AlignSelfValue?
BlockProperties.alignSelf = nil
ns.Resolved.alignSelf = resolver(
    {
        unset = "initial",
        initial = "auto",
        ["normal"] = "stretch",
        ["auto"] = "auto",
        ["center"] = "safe center",
        ["safe center"] = "safe center",
        ["unsafe center"] = "unsafe center",
        ["start"] = "safe start",
        ["safe start"] = "safe start",
        ["unsafe start"] = "unsafe start",
        ["end"] = "safe end",
        ["safe end"] = "safe end",
        ["unsafe end"] = "unsafe end",
        ["self-start"] = "safe start",
        ["safe self-start"] = "safe start",
        ["unsafe self-start"] = "unsafe start",
        ["self-end"] = "safe end",
        ["safe self-end"] = "safe end",
        ["unsafe self-end"] = "unsafe end",
        ["flex-start"] = "safe start",
        ["safe flex-start"] = "safe start",
        ["unsafe flex-start"] = "unsafe start",
        ["flex-end"] = "safe end",
        ["safe flex-end"] = "safe end",
        ["unsafe flex-end"] = "unsafe end",
        ["baseline"] = "first baseline",
        ["first baseline"] = "first baseline",
        ["last baseline"] = "last baseline",
        ["stretch"] = "stretch",
    },
    parseFail,
    false
) --[[ @as "safe start"|"unsafe start"|"safe center"|"unsafe center"|"safe end"|"unsafe end"|"first baseline"|"last baseline"|"stretch" ]]

--- A single CSS rule, combines style settings and selectors.
---
--- !doc inherited-members
--- !doc exclude-members: New
--- @class ammgui.css.rule.Rule: ammgui.css.rule.RuleBase, ammgui.css.rule.CommonProperties, ammgui.css.rule.TextProperties, ammgui.css.rule.BlockProperties, ammgui.css.rule.FlexProperties
--- @field [integer] string Selectors for matching DOM nodes.
ns.Rule = {}

--- @param context ammgui.css.rule.CompiledRule[]
--- @param contextSelectors ammgui.css.selector.Selector[]
--- @param parent ammgui.css.rule.Resolved?
--- @param theme table<string, Color | string>
--- @param units table<string, number>
---
--- !doctype classmethod
--- @generic T: ammgui.css.rule.Resolved
--- @param self T
--- @return T
function ns.Resolved:New(context, contextSelectors, parent, theme, units)
    self = class.Base.New(self)

    --- @private
    --- @type ammgui.css.rule.CompiledRule[]
    self._context = context

    --- @private
    --- @type ammgui.css.selector.Selector[]
    self._contextSelectors = contextSelectors

    --- @private
    --- @type ammgui.css.rule.Resolved?
    self._parent = parent

    --- @package
    --- @type table<string, Color | string>
    self._theme = theme

    --- @package
    --- @type table<string, number>
    self._units = units

    return self
end

function ns.Resolved:__index(name)
    local value = ns.Resolved[name]
    if value and value.__isResolver then
        return ns.Resolved._get(self, name, "unset")
    else
        return value
    end
end

--- @package
--- @param name string
--- @param unset string
function ns.Resolved:_get(name, unset)
    local context = self._context
    for i = #context, 1, -1 do
        local rule = context[i]
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
    --- @type { literalValues: table<string, unknown>, parser: fun(x: unknown, r: ammgui.css.rule.Resolved, n: string): unknown }?
    local resolver = ns.Resolved[name]
    if not resolver then
        error(string.format("unknown CSS property %s", name))
    end
    local canonValue = value
    if type(canonValue) == "string" then canonValue = canonValue:lower() end
    while resolver.literalValues[canonValue] do
        local nextValue = resolver.literalValues[canonValue]
        if nextValue == value then
            return nextValue
        else
            value = nextValue
            canonValue = value
            if type(canonValue) == "string" then canonValue = canonValue:lower() end
        end
    end
    if value == "inherit" then
        return ns.Resolved._getInherited(self, name)
    end
    if value == "unset" or value == "initial" then
        error(string.format("no initial value for property %s", name))
    end
    return resolver.parser(value, self, name)
end

--- @package
function ns.Resolved:_getInherited(name)
    local parent = self._parent
    if parent then
        return ns.Resolved._get(parent, name, "inherit")
    else
        -- Value is "inherit", but we've reached root, treat as "initial"
        return ns.Resolved._process(self, name, "initial")
    end
end

--- Compiled rule.
---
--- Compound properties like `~Rule.gap` and `~Rule.flex` are assigned
--- to their respective components, and selectors are compiled and sorted.
---
--- @class ammgui.css.rule.CompiledRule: ammgui.css.rule.Rule
ns.CompiledRule = {}

--- List of compiled selectors sorted by their specificity and order of appearance.
---
--- @type ammgui.css.selector.Selector[]
ns.CompiledRule.compiledSelectors = nil

--- Indicates that this rule doesn't contain properties that affect layout.
---
--- @type boolean
ns.CompiledRule.isLayoutSafe = false

--- Process all compound properties like `~Rule.gap` and `~Rule.flex`
--- and assign them to their components.
---
--- @param data ammgui.css.rule.Rule
--- @param layer integer CSS layer, used to calculate selector's priority. User-agent layer is ``-1``.
--- @param appeared integer index of this rule in a stylesheet, used to calculate selector priorities.
--- @return ammgui.css.rule.CompiledRule
function ns.compile(data, layer, appeared)
    local rule = { loc = data.loc }

    for name, value in pairs(data) do
        if ruleSetters[name] then
            ruleSetters[name](rule, value)
        elseif type(name) ~= "number" then
            rule[name] = value
        end
    end

    local isLayoutSafe = true
    for name, value in pairs(rule) do
        if name ~= "loc" then
            local resolver = ns.Resolved[name]
            if type(resolver) ~= "table" then
                error(string.format("rule at %s: unknown CSS property %s = %s", rule.loc, log.pp(name), log.pp(value)))
            end
            if not resolver.isLayoutSafe then
                isLayoutSafe = false
                break
            end
        end
    end
    rule.isLayoutSafe = isLayoutSafe

    --- @type ammgui.css.selector.Selector[]
    local compiledSelectors = {}
    if #data > 100 then
        error(string.format("rule at %s: a single rule can't have more than 100 selectors", rule.loc))
    end
    for i, selectorTxt in ipairs(data) do
        table.insert(compiledSelectors, selector.parse(selectorTxt, layer, appeared * 1000 + i))
    end
    table.sort(compiledSelectors, function(lhs, rhs) return lhs > rhs end)
    rule.compiledSelectors = compiledSelectors

    return rule
end

--- Get all rule keys in alphabetical order.
---
--- @param rule ammgui.css.rule.CompiledRule
--- @return string[]
function ns.getRuleKeys(rule)
    local res = {}
    for k, _ in pairs(rule) do
        if k ~= "isLayoutSafe" and k ~= "compiledSelectors" and k ~= "loc" then
            table.insert(res, k)
        end
    end
    table.sort(res)
    return res
end

return ns
