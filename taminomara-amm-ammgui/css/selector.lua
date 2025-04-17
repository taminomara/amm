local class = require "ammcore.class"

--- CSS-like selectors.
---
--- AmmGui implements very basic CSS selectors. Only element types and classes
--- are supported, no combinators, no pseudo-classes except ``:hover``, ``:focus``,
--- ``:enabled`` and ``:disabled``, and there are only two layers: user-agent and user.
---
--- !doctype module
--- @class ammgui.css.selector
local ns = {}

--- A CSS selector.
---
--- @class ammgui.css.selector.Selector: ammcore.class.Base
ns.Selector = class.create("Selector")

--- @param elemSpecificity integer
--- @param classSpecificity integer
--- @param layer integer
--- @param appeared integer
--- @param repr string
--- @param matchers (fun (elem: string, classes: table<string, true>, pseudo: table<string, true>): integer?)[]
---
--- !doctype classmethod
--- @generic T: ammgui.css.selector.Selector
--- @param self T
--- @return T
function ns.Selector:New(elemSpecificity, classSpecificity, layer, appeared, repr, matchers)
    self = class.Base.New(self)

    --- Element specificity number.
    ---
    --- !doctype const
    --- @type integer
    self.elemSpecificity = elemSpecificity

    --- Class specificity number.
    ---
    --- !doctype const
    --- @type integer
    self.classSpecificity = classSpecificity

    --- CSS layer this selector appeared in.
    ---
    --- !doctype const
    --- @type integer
    self.layer = layer

    --- Index at which this rule was added to an app.
    ---
    --- !doctype const
    --- @type integer
    self.appeared = appeared

    --- @type string
    --- @private
    self._repr = repr

    --- @type (fun (elem: string, classes: table<string, true>, pseudo: table<string, true>): integer?)[]
    --- @private
    self._matchers = matchers

    return self
end

function ns.Selector:__tostring()
    return string.format(
        "%s(%q, specificity=%s-%s level=%s, appeared=%s)",
        self.__name, self._repr, self.classSpecificity, self.elemSpecificity, self.layer, self.appeared
    )
end

--- @param lhs ammgui.css.selector.Selector
--- @param rhs ammgui.css.selector.Selector
function ns.Selector.__lt(lhs, rhs)
    if lhs.layer ~= rhs.layer then
        return lhs.layer < rhs.layer
    end
    if lhs.classSpecificity ~= rhs.classSpecificity then
        return lhs.classSpecificity < rhs.classSpecificity
    end
    if lhs.elemSpecificity ~= rhs.elemSpecificity then
        return lhs.elemSpecificity < rhs.elemSpecificity
    end
    if lhs.appeared ~= rhs.appeared then
        return lhs.appeared < rhs.appeared
    end
    return false
end

--- @param lhs ammgui.css.selector.Selector
--- @param rhs ammgui.css.selector.Selector
function ns.Selector.__gt(lhs, rhs)
    return rhs < lhs
end

--- Check whether this selector matches a DOM node with the given path.
---
--- @param path { elem: string, classes: table<string, true>, pseudo: table<string, true> }[]
--- @return boolean
function ns.Selector:match(path)
    local i = 1
    for depth, data in ipairs(path) do
        if not self._matchers[i] then
            return false
        end

        if
            (i < #self._matchers or depth == #path)
            and self._matchers[i](data.elem, data.classes, data.pseudo)
        then
            i = i + 1
            if i > #self._matchers then
                return true
            end
        end
    end

    return false
end

--- Parse a CSS selector from string.
---
--- @param selector string string representing a CSS selector.
--- @param layer integer CSS layer, used to calculate selector's priority. User-agent layer is ``-1``.
--- @param appeared integer index of this selector in a stylesheet, used to calculate selector's priority.
--- @return ammgui.css.selector.Selector compiledSelector parsed and compiled selector.
function ns.parse(selector, layer, appeared)
    local elemSpecificity = 0
    local classSpecificity = 0

    local matchers = {}
    local repr = ""

    for group in selector:gmatch("%S+") do
        local classes = {}
        local pseudo = {}

        local code = "return function (elem, classes, pseudo)\n"
        repr = repr .. " "

        for op, name in group:gmatch("([^%w*_-]*)([%w*_-]*)") do
            if name:len() == 0 then
                error(string.format("Invalid selector %q: expected a name after %q", selector, op))
            end

            if op == "" then
                if name ~= "*" then
                    elemSpecificity = elemSpecificity + 1
                    code = code .. string.format("  if elem ~= %q then return false end\n", name)
                end
                repr = repr .. name
            elseif op == "." then
                if not classes[name] then
                    classes[name] = true
                    code = code .. string.format("  if not classes[%q] then return false end\n", name)
                end
                repr = repr .. "." .. name
                classSpecificity = classSpecificity + 1
            elseif op == ":" then
                if not pseudo[name] then
                    pseudo[name] = true
                    code = code .. string.format("  if not pseudo[%q] then return false end\n", name)
                end
                repr = repr .. ":" .. name
                classSpecificity = classSpecificity + 1
            else
                error(string.format("Invalid selector %q: unknown operator %q", selector, op))
            end
        end

        code = code .. "  return true\nend"
        table.insert(matchers, load(code, "<selector>", "bt", {})())
    end

    return ns.Selector:New(elemSpecificity, classSpecificity, layer, appeared, repr:sub(2), matchers)
end

return ns
