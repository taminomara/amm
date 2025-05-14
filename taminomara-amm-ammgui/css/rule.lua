--- A CSS rule.
---
--- !doctype module
--- @class ammgui.css.rule
local ns = {}

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

--- A single CSS rule, combines style settings and selectors.
---
--- !doc inherited-members
--- !doc exclude-members: New
--- @class ammgui.css.rule.Rule
--- @field [integer] string Selectors for matching DOM nodes.
ns.Rule = {}

--- Source, indicates file and line where this rule was created.
---
--- @type string?
ns.Rule.loc = nil

--- A catch-all property, allows resetting values for all other properties.
---
--- @type ammgui.css.rule.GlobalValue?
ns.Rule.all = nil

--- @alias ammgui.css.rule.DisplayValue
--- |"inline"
--- |"inline-block"
--- |"none"
--- |"block"
--- |"flex"
--- |ammgui.css.rule.GlobalValue

--- Controls layout algorithm used to render the element.
---
--- @type ammgui.css.rule.DisplayValue?
ns.Rule.display = nil

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
ns.Rule.font = nil

--- Font size for any text in this DOM node.
---
--- @type ammgui.css.rule.LengthValue?
ns.Rule.fontSize = nil

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
ns.Rule.fontFamily = nil

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
ns.Rule.lineHeight = nil

--- @type ammgui.css.rule.ColorValue?
ns.Rule.color = nil

--- Represents values for `~Rule.textWrapMode` property.
---
--- Available options:
---
--- - ``"wrap"``: text is wrapped on whitespaces and after dashes;
--- - ``"nowrap"``: text is not wrapped.

--- @alias ammgui.css.rule.TextWrapModeValue
--- |"wrap"
--- |"nowrap"
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.TextWrapModeValue?
ns.Rule.textWrapMode = nil

--- @type ammgui.css.rule.ColorValue?
ns.Rule.backgroundColor = nil

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
ns.Rule.margin = nil

--- @type ammgui.css.rule.MarginValue?
ns.Rule.marginTop = nil

--- @type ammgui.css.rule.MarginValue?
ns.Rule.marginLeft = nil

--- @type ammgui.css.rule.MarginValue?
ns.Rule.marginRight = nil

--- @type ammgui.css.rule.MarginValue?
ns.Rule.marginBottom = nil

--- @alias ammgui.css.rule.MarginTrimValue
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
--- @type ammgui.css.rule.MarginTrimValue?
ns.Rule.marginTrim = nil

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

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingTop = nil

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingLeft = nil

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingRight = nil

--- @type ammgui.css.rule.LengthValue?
ns.Rule.paddingBottom = nil

--- @type ammgui.css.rule.LengthValue?
ns.Rule.outlineRadius = nil

--- @type ammgui.css.rule.LengthValue?
ns.Rule.outlineWidth = nil

--- @type ammgui.css.rule.ColorValue?
ns.Rule.outlineTint = nil

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
ns.Rule.columnGap = nil

--- @type ammgui.css.rule.GapValue?
ns.Rule.rowGap = nil

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
--- | "scroll"

--- @type
--- | ammgui.css.rule.OverflowValue
--- | [ammgui.css.rule.OverflowValue]
--- | [ammgui.css.rule.OverflowValue, ammgui.css.rule.OverflowValue]
--- | nil
ns.Rule.overflow = nil

--- @type ammgui.css.rule.OverflowValue?
ns.Rule.overflowX = nil

--- @type ammgui.css.rule.OverflowValue?
ns.Rule.overflowY = nil

--- @alias ammgui.css.rule.WidthValue
--- |"auto"
--- |"min-content"
--- |"fit-content"
--- |"max-content"
--- |ammgui.css.rule.LengthValue
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.WidthValue?
ns.Rule.width = nil

--- @type ammgui.css.rule.WidthValue?
ns.Rule.minWidth = nil

--- @type ammgui.css.rule.WidthValue?
ns.Rule.maxWidth = nil

--- @alias ammgui.css.rule.Height
--- |"auto"
--- |ammgui.css.rule.LengthValue
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.Height?
ns.Rule.height = nil

--- @type ammgui.css.rule.Height?
ns.Rule.minHeight = nil

--- @type ammgui.css.rule.Height?
ns.Rule.maxHeight = nil

--- @alias ammgui.css.rule.FlexDirectionValue
--- |"row"
--- |"column"
--- |ammgui.css.rule.GlobalValue

--- @type ammgui.css.rule.FlexDirectionValue?
ns.Rule.flexDirection = nil

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
ns.Rule.flex = nil

--- Shorthand to set `flexWrap` and `flexDirection` at once.
---
--- If given a single value, will set `flexWrap` or `flexDirection` depending
--- on which value was passed.
---
--- If given an array of two values, then the first one should be a `flexWrap` value,
--- and the second one should be a `flexDirection`.
---
--- @type
--- | ammgui.css.rule.FlexWrapValue
--- | ammgui.css.rule.FlexDirectionValue
--- | [ammgui.css.rule.FlexWrapValue | ammgui.css.rule.FlexDirectionValue]
--- | [ammgui.css.rule.FlexWrapValue, ammgui.css.rule.FlexDirectionValue]
--- | nil
ns.Rule.flexFlow = nil

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
ns.Rule.flexWrap = nil

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
ns.Rule.alignContent = nil

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
ns.Rule.alignItems = nil

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
ns.Rule.justifyContent = nil

--- @type ammgui.css.rule.NumberValue?
ns.Rule.flexGrow = nil

--- @type ammgui.css.rule.NumberValue?
ns.Rule.flexShrink = nil

--- @type ammgui.css.rule.WidthValue?
ns.Rule.flexBasis = nil

--- Represents values for `~Rule.alignSelf` property.
---
--- Available options:
---
--- TODO!

--- @alias ammgui.css.rule.AlignSelfValue
--- |"auto"
--- |ammgui.css.rule.AlignItemsValue

--- @type ammgui.css.rule.AlignSelfValue?
ns.Rule.alignSelf = nil

return ns
