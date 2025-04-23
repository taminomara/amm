local class = require "ammcore.class"
local bootloader = require "ammcore.bootloader"

--- A collection of CSS rules.
---
--- !doctype module
--- @class ammgui.css.stylesheet
local ns = {}

--- A collection of CSS rules.
---
--- @class ammgui.css.stylesheet.Stylesheet: ammcore.class.Base
ns.Stylesheet = class.create("Stylesheet")

--- @param layer integer?
---
--- !doctype classmethod
--- @generic T: ammgui.css.stylesheet.Stylesheet
--- @param self T
--- @return T
function ns.Stylesheet:New(layer)
    self = class.Base.New(self)

    --- Layer at which these CSS rules are applied.
    ---
    --- Rules from higher levels have priority over rules form lower levels.
    --- Default layer is ``0``, and theme rules are level ``-1``.
    ---
    --- @type integer
    self.layer = layer or 0

    --- List of all rules in this stylesheet.
    ---
    --- Order of definition matters, as it works as a tie breaker for rules with
    --- same level and specificity: last rule wins.
    ---
    --- @type ammgui.css.rule.Rule[]
    self.rules = {}

    return self
end

--- Add a new rule to this stylesheet.
---
--- This method returns the stylesheet itself to enable method chaining.
---
--- @generic T: ammgui.css.stylesheet.Stylesheet
--- @param self T
--- @param rule ammgui.css.rule.Rule
--- @return T
function ns.Stylesheet:addRule(rule)
    rule.loc = rule.loc or bootloader.getLoc(2)
    ---@diagnostic disable-next-line: undefined-field
    table.insert(self.rules, rule)
    return self
end

return ns
