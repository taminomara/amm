local class = require "ammcore.class"
local defer = require "ammcore.defer"
local fun = require "ammcore.fun"
local rule = require "ammgui.css.rule"

--- Context for tracking inheritance while calculating CSS values.
---
--- !doctype module
--- @class ammgui._impl.cssContext
local ns = {}

--- Context for tracking inheritance while calculating CSS values.
---
--- @class ammgui._impl.cssContext.CssContext: ammcore.class.Base
ns.CssContext = class.create("CssContext")

--- @param rules { selector: ammgui.css.selector.Selector, rule: ammgui.css.rule.CompiledRule }[]
--- @param theme table<string, Color | string>
--- @param units table<string, number>
--- @param outdated boolean?
---
--- !doctype classmethod
--- @generic T: ammgui._impl.cssContext.CssContext
--- @param self T
--- @return T
function ns.CssContext:New(rules, theme, units, outdated)
    self = class.Base.New(self)

    --- @private
    --- @type table<string, Color | string>
    self._theme = theme

    --- @private
    --- @type table<string, number>
    self._units = units

    --- @private
    --- @type boolean
    self._outdated = outdated or false

    --- @private
    --- @type { selector: ammgui.css.selector.Selector, rule: ammgui.css.rule.CompiledRule }[]
    self._rules = rules

    --- @private
    --- @type { elem: string, classes: table<string, true>, pseudo: table<string, true> }[]
    self._path = {}

    --- @private
    --- @type { parent: ammgui.css.rule.Resolved, cssOutdated: boolean, layoutOutdated: boolean }[]
    self._context = {}

    return self
end

--- @private
--- @return ammgui.css.rule.Resolved? parent
--- @return boolean cssOutdated
--- @return boolean layoutOutdated
function ns.CssContext:_getContext()
    if #self._context > 0 then
        local context = self._context[#self._context]
        return context.parent, context.cssOutdated, context.layoutOutdated
    else
        return nil, self._outdated, self._outdated
    end
end

--- @private
--- @param inline ammgui.css.rule.CompiledRule
--- @param inlineDynamic ammgui.css.rule.CompiledRule
--- @return ammgui.css.rule.CompiledRule[] newRules
--- @return ammgui.css.selector.Selector[] newSelectors
function ns.CssContext:_matchRules(inline, inlineDynamic)
    --- @type ammgui.css.rule.CompiledRule[]
    local matchingRules = {}
    --- @type ammgui.css.selector.Selector[]
    local matchingSelectors = {}
    for _, ruleData in ipairs(self._rules) do
        if ruleData.selector:match(self._path) then
            table.insert(matchingRules, ruleData.rule)
            table.insert(matchingSelectors, ruleData.selector)
        end
    end
    table.insert(matchingRules, inline)
    table.insert(matchingRules, inlineDynamic)

    return matchingRules, matchingSelectors
end

--- Enter a new DOM node and update context accordingly.
---
--- @param css ammgui.css.rule.Resolved previous CSS settings.
--- @param elem string name of the DOM node.
--- @param classes table<string, true> set of CSS classes applied to the DOM node.
--- @param pseudo table<string, true> set of CSS pseudoclasses applied to the DOM node.
--- @param inline ammgui.css.rule.CompiledRule inline CSS settings of a component.
--- @param inlineDynamic ammgui.css.rule.CompiledRule inline dynamic CSS settings of a component.
--- @param cssOutdated boolean indicates that there were changes in component's or child's CSS settings.
--- @param selfCssOutdated boolean indicates that there were changes in component's inline CSS settings or set of classes and pseudoclasses.
--- @return boolean outdated `true` if layout settings were changed.
--- @return boolean shouldPropagate `true` if component should propagate CSS changes to its children.
--- @return ammgui.css.rule.Resolved newCss new CSS settings for component.
function ns.CssContext:enterNode(css, elem, classes, pseudo, inline, inlineDynamic, cssOutdated, selfCssOutdated)
    local parent, cssOutdated, layoutOutdated = self:_getContext()

    table.insert(self._path, { elem = elem, classes = classes, pseudo = pseudo })

    cssOutdated = cssOutdated or not css
    layoutOutdated = layoutOutdated or not css

    if cssOutdated or selfCssOutdated then
        local newRules, newSelectors = self:_matchRules(inline, inlineDynamic)

        if not cssOutdated or not layoutOutdated then
            local oldRules = css and rawget(css, "_context") or {}

            -- Only reset calculated css values if rules actually changed.
            -- I.e. we toggle `:hover` often, but most components don't have
            -- any rules related to `:hover`. And those that do, only update
            -- their layout-safe options.
            cssOutdated = cssOutdated or not fun.t.eq(oldRules, newRules)
            if cssOutdated and not layoutOutdated then
                local i, j, n = 1, 1, math.max(#newRules, #oldRules)
                while i <= n and j <= n do
                    while i <= #newRules and newRules[i].isLayoutSafe do
                        i = i + 1
                    end
                    while j <= #oldRules and oldRules[j].isLayoutSafe do
                        j = j + 1
                    end
                    if newRules[i] ~= oldRules[j] then
                        layoutOutdated = true
                        break
                    end
                    i = i + 1
                    j = j + 1
                end
            end
        end

        if cssOutdated or layoutOutdated then
            css = rule.Resolved:New(newRules, newSelectors, parent, self._theme, self._units)
        else
            rawset(css, "_contextSelectors", newSelectors)
        end
    end

    table.insert(self._context, { parent = css, cssOutdated = cssOutdated, layoutOutdated = layoutOutdated })

    return layoutOutdated, cssOutdated or cssOutdated, css
end

--- Exit a DOM node and update context accordingly.
function ns.CssContext:exitNode()
    if #self._path == 0 or #self._context == 0 then
        error("'exitNode' was called before 'enterNode'")
    else
        table.remove(self._path)
        table.remove(self._context)
    end
end

--- A helper which enters a DOM node and returns a deferred statement to exit it.
---
--- See `ammcore.defer` for more info.
---
--- @param css ammgui.css.rule.Resolved previous CSS settings.
--- @param elem string name of the DOM node.
--- @param classes table<string, true> set of CSS classes applied to the DOM node.
--- @param pseudo table<string, true> set of CSS pseudoclasses applied to the DOM node.
--- @param inline ammgui.css.rule.CompiledRule inline CSS settings of a component.
--- @param inlineDynamic ammgui.css.rule.CompiledRule inline dynamic CSS settings of a component.
--- @param cssOutdated boolean indicates that there were changes in component's or child's CSS settings.
--- @param selfCssOutdated boolean indicates that there were changes in component's inline CSS settings or set of classes and pseudoclasses.
--- @return ammcore.defer._Defer deferred statement. See `ammcore.defer` for more info.
--- @return boolean outdated `true` if layout settings were changed.
--- @return boolean shouldPropagate `true` if component should propagate CSS changes to its children.
--- @return ammgui.css.rule.Resolved newCss new CSS settings for component.
function ns.CssContext:descendNode(css, elem, classes, pseudo, inline, inlineDynamic, cssOutdated, selfCssOutdated)
    return defer.defer(self.exitNode, self),
        self:enterNode(css, elem, classes, pseudo, inline, inlineDynamic, cssOutdated, selfCssOutdated)
end

return ns
