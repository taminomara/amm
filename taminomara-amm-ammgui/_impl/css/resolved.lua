local class = require "ammcore.class"
local log = require "ammcore.log"
local parse = require "ammgui._impl.css.parse"
local u = require "ammgui.css.units"
local selector = require "ammgui._impl.css.selector"
local fun      = require "ammcore.fun"

--- Resolved CSS values.
---
--- !doctype module
--- @class ammgui._impl.css.resolved
local ns = {}

--- Data about allowed values for a CSS property, and how to handle them.
---
--- @class ammgui._impl.css.resolved.Resolver: ammcore.class.Base
local Resolver = class.create("Resolver")

--- @param literalValues table<string, any>
--- @param parser fun(x: unknown, r: ammgui._impl.css.resolved.Resolved, n: string): any
--- @param isLayoutSafe boolean
---
--- !doctype classmethod
--- @generic T: ammgui._impl.css.resolved.Resolver
--- @param self T
--- @return T
function Resolver:New(literalValues, parser, isLayoutSafe)
    self = class.Base.New(self)

    for value, mappedValue in ipairs(literalValues) do
        while mappedValue ~= value and literalValues[mappedValue] do
            mappedValue = literalValues[mappedValue]
        end
        literalValues[value] = mappedValue
    end

    --- Special string values that should stay unchanged or be mapped to other values.
    ---
    --- @type table<string, any>
    self.literalValues = literalValues

    --- Parser for values that don't appear in `literalValues`.
    ---
    --- @type fun(x: unknown, r: ammgui._impl.css.resolved.Resolved, n: string): any
    self.parser = parser

    --- Indicates that this rule does not affect layout.
    ---
    --- @type boolean
    self.isLayoutSafe = isLayoutSafe

    return self
end

--- @type table<string, fun(self: ammgui.css.rule.Rule, value: unknown)>
local ruleSetters = {}

--- @type table<string, ammgui._impl.css.resolved.Resolver>
local resolvers = {}

--- Contains values resolved for a concrete DOM node.
---
--- @class ammgui._impl.css.resolved.Resolved: ammcore.class.Base
ns.Resolved = class.create("Resolved")

--- @param context ammgui._impl.css.resolved.CompiledRule[]
--- @param contextSelectors ammgui.css.selector.Selector[]
--- @param parent ammgui._impl.css.resolved.Resolved?
--- @param theme table<string, Color | string>
--- @param units table<string, number>
---
--- !doctype classmethod
--- @generic T: ammgui._impl.css.resolved.Resolved
--- @param self T
--- @return T
function ns.Resolved:New(context, contextSelectors, parent, theme, units)
    self = class.Base.New(self)

    --- All CSS rules that matches this DOM node.
    ---
    --- .. warning::
    ---
    ---    Modifying this value will break CSS caches.
    ---
    --- !doctype const
    --- @type ammgui._impl.css.resolved.CompiledRule[]
    self.context = context

    --- For each rule from `context`, this array contains a selector that matched
    --- this DOM node.
    ---
    --- This array is used in debug window.
    ---
    --- !doctype const
    --- @type ammgui.css.selector.Selector[]
    self.contextSelectors = contextSelectors

    --- Resolved values for the parent node.
    ---
    --- .. warning::
    ---
    ---    Modifying this value will break CSS caches.
    ---
    --- !doctype const
    --- @type ammgui._impl.css.resolved.Resolved?
    self.parent = parent

    --- Theme colors.
    ---
    --- .. warning::
    ---
    ---    Modifying values from this table will break CSS caches.
    ---
    --- !doctype const
    --- @type table<string, Color | string>
    self.theme = theme

    --- Units calculated for the current screen.
    ---
    --- If you have a value in some unit, then multiplying it by the value from this
    --- table will give you a value in pixels. I.e. ``5 * units["rem"]`` will give you
    --- ``5rem`` in pixels.
    ---
    --- Note that relative units (``em``, ``%``, etc.) are not in this table.
    ---
    --- .. warning::
    ---
    ---    Modifying values from this table will break CSS caches.
    ---
    --- !doctype const
    --- @type table<string, number>
    self.units = units

    --- Cache for `getTrace`.
    --- @type table<string, { selector: ammgui.css.selector.Selector?, value: any}>
    self.trace = {}

    return self
end

function ns.Resolved:__index(name)
    if resolvers[name] then
        return ns.Resolved._get(self, name)
    else
        return ns.Resolved[name]
    end
end

--- @package
--- @param name string
function ns.Resolved:_get(name)
    local context = self.context
    for i = #context, 1, -1 do
        local rule = context[i]
        local value = rule[name] or rule["all"]
        if value then
            value = ns.Resolved._process(self, name, value, self.contextSelectors[i])
            -- XXX: support revert?
            self[name] = value -- cache value
            return value
        end
    end

    -- Value wasn't set by any CSS rule, treat as "unset".
    local value = ns.Resolved._process(self, name, "unset")
    self[name] = value
    return value
end

--- @package
--- @param name string
--- @param value unknown
--- @param selector ammgui.css.selector.Selector?
function ns.Resolved:_process(name, value, selector)
    local resolver = resolvers[name]
    if not resolver then
        error(string.format("unknown CSS property %s", name))
    end
    local canonValue = value
    if type(canonValue) == "string" then canonValue = canonValue:lower() end
    while resolver.literalValues[canonValue] do
        local nextValue = resolver.literalValues[canonValue]
        if nextValue == value then
            ns.Resolved._saveTrace(self, name, nextValue, selector)
            return nextValue
        else
            value = nextValue
            canonValue = value
            if type(canonValue) == "string" then canonValue = canonValue:lower() end
        end
    end
    if value == "inherit" then
        ns.Resolved._saveTrace(self, name, value, selector)
        return ns.Resolved.getInherited(self, name)
    end
    if value == "unset" or value == "initial" then
        error(string.format("no initial value for property %s", name))
    end
    value = resolver.parser(value, self, name)
    ns.Resolved._saveTrace(self, name, value, selector)
    return value
end

--- Get inherited value for property with the given name.
function ns.Resolved:getInherited(name)
    local parent = self.parent
    if parent then
        return parent[name]
    else
        -- Value is "inherit", but we've reached root, treat as "initial".
        return ns.Resolved._process(self, name, "initial")
    end
end

--- @param name string
--- @param value any
--- @param selector ammgui.css.selector.Selector?
--- @return any
function ns.Resolved:_saveTrace(name, value, selector)
    self.trace[name] = { value = value, selector = selector }
end

--- Get value for property with the given name, and track where this value came from.
---
--- This function is used in the debug window.
---
--- @return any, { selector: ammgui.css.selector.Selector?, value: any }[]
function ns.Resolved:getTrace(name)
    local value = self[name]
    local trace = {}

    --- @type ammgui._impl.css.resolved.Resolved?
    local root = self
    while root do
        local traceDatum = assert(root.trace[name])
        if traceDatum.selector or traceDatum.value ~= "inherit" then
            table.insert(trace, traceDatum)
        end
        if traceDatum.value == "inherit" then
            root = self.parent
        else
            break
        end
    end

    return value, trace
end

--- @type ammgui.css.rule.DisplayValue
ns.Resolved.display = nil
resolvers.display = Resolver:New(
    {
        unset = "initial",
        initial = "block",
        ["inline"] = "inline",
        ["inline-block"] = "inline-block",
        ["none"] = "none",
        ["block"] = "block",
        ["flex"] = "flex",
    },
    parse.parseFail,
    false
)

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

--- @type [number, "px"]
ns.Resolved.fontSize = nil
resolvers.fontSize = Resolver:New(
    {
        unset = "inherit",
        initial = u.rem(1),
    },
    parse.parseFontSize,
    false
)

--- @type "normal"|"monospace"
ns.Resolved.fontFamily = nil
resolvers.fontFamily = Resolver:New(
    {
        unset = "inherit",
        initial = "normal",
        ["normal"] = "normal",
        ["monospace"] = "monospace",
    },
    parse.parseFail,
    false
)

--- @type [number, "px"|""]
ns.Resolved.lineHeight = nil
resolvers.lineHeight = Resolver:New(
    {
        unset = "inherit",
        initial = "normal",
        ["normal"] = 1.2,
    },
    parse.parseLineHeight,
    false
)

--- @type Color
ns.Resolved.color = nil
resolvers.color = Resolver:New(
    {
        unset = "inherit",
        initial = "canvastext",
        currentcolor = "inherit",
    },
    parse.parseColor,
    true
)

--- @type "wrap"|"nowrap"
ns.Resolved.textWrapMode = nil
resolvers.textWrapMode = Resolver:New(
    {
        unset = "inherit",
        initial = "wrap",
        ["wrap"] = "wrap",
        ["nowrap"] = "nowrap",
    },
    parse.parseFail,
    false
)

--- @type Color
ns.Resolved.backgroundColor = nil
resolvers.backgroundColor = Resolver:New(
    {
        unset = "initial",
        initial = "transparent",
        currentbackgroundcolor = "inherit",
    },
    parse.parseColor,
    true
)

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

--- @type [number, "px"|"%"]|"auto"
ns.Resolved.marginTop = nil
resolvers.marginTop = Resolver:New(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parse.parseLength,
    false
)

--- @type [number, "px"|"%"]|"auto"
ns.Resolved.marginLeft = nil
resolvers.marginLeft = Resolver:New(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parse.parseLength,
    false
)

--- @type [number, "px"|"%"]|"auto"
ns.Resolved.marginRight = nil
resolvers.marginRight = Resolver:New(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parse.parseLength,
    false
)

--- @type [number, "px"|"%"]|"auto"
ns.Resolved.marginBottom = nil
resolvers.marginBottom = Resolver:New(
    {
        unset = "initial",
        initial = 0,
        ["auto"] = "auto",
    },
    parse.parseLength,
    false
)

--- @type "none"|"block"|"block-start"|"block-end"|"inline"|"inline-start"|"inline-end"
ns.Resolved.marginTrim = nil
resolvers.marginTrim = Resolver:New(
    {
        unset = "initial",
        initial = "none",
        ["none"] = "none",
        ["block"] = "block",
        ["block-start"] = "block-start",
        ["block-end"] = "block-end",
        ["inline"] = "inline",
        ["inline-start"] = "inline-start",
        ["inline-end"] = "inline-end",
    },
    parse.parseFail,
    false
)

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

--- @type [number, "px"|"%"]
ns.Resolved.paddingTop = nil
resolvers.paddingTop = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]
ns.Resolved.paddingLeft = nil
resolvers.paddingLeft = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]
ns.Resolved.paddingRight = nil
resolvers.paddingRight = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]
ns.Resolved.paddingBottom = nil
resolvers.paddingBottom = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]
ns.Resolved.outlineRadius = nil
resolvers.outlineRadius = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    true
)

--- @type [number, "px"|"%"]
ns.Resolved.outlineWidth = nil
resolvers.outlineWidth = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    false
)

--- @type Color
ns.Resolved.outlineTint = nil
resolvers.outlineTint = Resolver:New(
    {
        unset = "initial",
        initial = "currentbackgroundcolor",
    },
    parse.parseColor,
    true
)

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

--- @type [number, "px"|"%"]
ns.Resolved.columnGap = nil
resolvers.columnGap = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]
ns.Resolved.rowGap = nil
resolvers.rowGap = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parsePositiveLength,
    false
)

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
        error(string.format("invalid overflow value: %s", log.pp(value)))
    end
end

--- @return boolean
function ns.Resolved:overflowVisible()
    return self.overflowX == "visible" and self.overflowY == "visible"
end

--- @type "visible"|"hidden"|"scroll"
ns.Resolved.overflowX = nil
resolvers.overflowX = Resolver:New(
    {
        unset = "initial",
        initial = "visible",
        ["visible"] = "visible",
        ["hidden"] = "hidden",
        ["scroll"] = "scroll",
    },
    parse.parseFail,
    false
)

--- @type "visible"|"hidden"|"scroll"
ns.Resolved.overflowY = nil
resolvers.overflowY = Resolver:New(
    {
        unset = "initial",
        initial = "visible",
        ["visible"] = "visible",
        ["hidden"] = "hidden",
        ["scroll"] = "scroll",
    },
    parse.parseFail,
    false
)

--- @type [number, "px"|"%"]|"auto"|"min-content"|"fit-content"|"max-content"
ns.Resolved.width = nil
resolvers.width = Resolver:New(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]|"min-content"|"fit-content"|"max-content"
ns.Resolved.minWidth = nil
resolvers.minWidth = Resolver:New(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = 0,
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]|"min-content"|"fit-content"|"max-content"
ns.Resolved.maxWidth = nil
resolvers.maxWidth = Resolver:New(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = math.huge,
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]|"auto"
ns.Resolved.height = nil
resolvers.height = Resolver:New(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]
ns.Resolved.minHeight = nil
resolvers.minHeight = Resolver:New(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = 0,
    },
    parse.parsePositiveLength,
    false
)

--- @type [number, "px"|"%"]
ns.Resolved.maxHeight = nil
resolvers.maxHeight = Resolver:New(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = math.huge,
    },
    parse.parsePositiveLength,
    false
)

--- @type "row"|"column"
ns.Resolved.flexDirection = nil
resolvers.flexDirection = Resolver:New(
    {
        unset = "initial",
        initial = "row",
        ["row"] = "row",
        ["column"] = "column",
    },
    parse.parseFail,
    false
)

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

--- @type "wrap"|"nowrap"
ns.Resolved.flexWrap = nil
resolvers.flexWrap = Resolver:New(
    {
        unset = "initial",
        initial = "nowrap",
        ["wrap"] = "wrap",
        ["nowrap"] = "nowrap",
    },
    parse.parseFail,
    false
)

--- @type "start"|"center"|"end"|"space-between"|"space-around"|"space-evenly"|"stretch"
ns.Resolved.alignContent = nil
resolvers.alignContent = Resolver:New(
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
    parse.parseFail,
    false
)

--- @type "safe start"|"unsafe start"|"safe center"|"unsafe center"|"safe end"|"unsafe end"|"first baseline"|"last baseline"|"stretch"
ns.Resolved.alignItems = nil
resolvers.alignItems = Resolver:New(
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
    parse.parseFail,
    false
)

--- @type "normal"|"start"|"center"|"end"|"space-between"|"space-around"|"space-evenly"|"stretch"
ns.Resolved.justifyContent = nil
resolvers.justifyContent = Resolver:New(
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
    parse.parseFail,
    false
)

--- @type number
ns.Resolved.flexGrow = nil
resolvers.flexGrow = Resolver:New(
    {
        unset = "initial",
        initial = 0,
    },
    parse.parseFloat,
    false
)

--- @type number
ns.Resolved.flexShrink = nil
resolvers.flexShrink = Resolver:New(
    {
        unset = "initial",
        initial = 1,
    },
    parse.parseFloat,
    false
)

--- @type [number, "px"|"%"]|"auto"|"min-content"|"fit-content"|"max-content"
ns.Resolved.flexBasis = nil
resolvers.flexBasis = Resolver:New(
    {
        unset = "initial",
        initial = "auto",
        ["auto"] = "auto",
        ["min-content"] = "min-content",
        ["fit-content"] = "fit-content",
        ["max-content"] = "max-content",
    },
    parse.parsePositiveLength,
    false
)

--- @type "safe start"|"unsafe start"|"safe center"|"unsafe center"|"safe end"|"unsafe end"|"first baseline"|"last baseline"|"stretch"
ns.Resolved.alignSelf = nil
resolvers.alignSelf = Resolver:New(
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
    parse.parseFail,
    false
)

--- Compiled rule.
---
--- Compound properties like `~Rule.gap` and `~Rule.flex` are assigned
--- to their respective components, and selectors are compiled and sorted.
---
--- @class ammgui._impl.css.resolved.CompiledRule: ammgui.css.rule.Rule
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
--- @return ammgui._impl.css.resolved.CompiledRule
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
        if name == "all" then
            isLayoutSafe = false
            break
        elseif name ~= "loc" then
            local resolver = resolvers[name]
            if not resolver then
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

--- @param rule ammgui._impl.css.resolved.CompiledRule
--- @return string[]
function ns.getRuleKeys(rule)
    local res = {}
    for k, _ in pairs(rule) do
        if k ~= "loc" and k ~= "compiledSelectors" and k  ~= "isLayoutSafe" then
            table.insert(res, k)
        end
    end
    table.sort(res)
    return res
end

return ns
