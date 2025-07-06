--- @namespace ammcore.pkg.version

local class = require "ammcore.class"
local fun = require "ammcore.fun"

--- Version specifications.
local ns = {}

--- Represents a package version.
---
--- @class Version: ammcore.class.Base
--- @operator concat(integer|"*"): Version
ns.Version = class.create("Version")

--- @param ... integer|"*" components of the version. If given, ``"*"`` must be the last component.
function ns.Version:__init(...)
    --- @package
    --- @type (integer|"*")[]
    self._components = { ... }

    --- @private
    --- @type string?
    self._canonicalString = nil
end

--- Return version without its last component.
---
--- @return Version upVersion version without its last component.
function ns.Version:up()
    return ns.Version(table.unpack(self._components, 1, #self._components - 1) --[[@as any]])
end

--- Return version with its last component replaced by wildcard.
---
--- @return Version wildVersion version with its last component replaced by wildcard.
function ns.Version:makeWild()
    local res = ns.Version(table.unpack(self._components, 1, #self._components - 1) --[[@as any]])
    table.insert(res._components, "*")
    return res
end

--- @return string
function ns.Version:__tostring()
    return table.concat(self._components, ".")
end

--- Make a string that can be used to compare versions for strict equality,
--- i.e. a version with trailing zeros remover.
---
--- @return string canonicalString
function ns.Version:canonicalString()
    if not self._canonicalString then
        local n = #self._components
        while n > 0 and not self._components[n] or self._components[n] == 0 do
            n = n - 1
        end
        if n < 1 then
            n = 1
        end

        self._canonicalString = ""
        local sep = ""

        for i = 1, n do
            self._canonicalString = self._canonicalString .. sep .. tostring(self._components[i] or 0)
            sep = "."
        end
    end

    return self._canonicalString
end

--- Check that versions are compatible (i.e. `x~1.0.5` means `x>=1.0.5 and x==1.0.*`).
---
--- @param lhs Version
--- @param rhs Version
--- @return boolean
function ns.Version.compat(lhs, rhs)
    local len = #rhs._components
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("star is not allowed here") end
        if i == len then
            return lhsComponent >= rhsComponent
        elseif lhsComponent ~= rhsComponent then
            return false
        end
    end
    return false
end

--- Check that versions are equal.
---
--- @param lhs Version
--- @param rhs Version
--- @return boolean
function ns.Version.__eq(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then return true end
        if lhsComponent ~= rhsComponent then
            return false
        end
    end
    return true
end

--- Check that versions are equal or one comes before another.
---
--- @param lhs Version
--- @param rhs Version
--- @return boolean
function ns.Version.__le(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent <= rhsComponent
        end
    end
    return true
end

--- Check that version comes before another.
---
--- @param lhs Version
--- @param rhs Version
--- @return boolean
function ns.Version.__lt(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent < rhsComponent
        end
    end
    return false
end

--- Check that versions are equal or one comes after another.
---
--- @param lhs Version
--- @param rhs Version
--- @return boolean
function ns.Version.__ge(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent >= rhsComponent
        end
    end
    return true
end

--- Check that version comes after another.
---
--- @param lhs Version
--- @param rhs Version
--- @return boolean
function ns.Version.__gt(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent > rhsComponent
        end
    end
    return false
end

--- Parse a version string.
---
--- @param verTxt string text representation of a version.
--- @param allowStar boolean? allow last component of a version to be a wild card.
--- @return Version version parsed version.
function ns.parse(verTxt, allowStar)
    local components = {}
    local seenStar = false
    for verComponentTxt in (verTxt .. "."):gmatch("(.-)%.") do
        if seenStar then
            error("star is only allowed in the last version component", 0)
        end
        if allowStar and verComponentTxt == "*" then
            table.insert(components, "*")
            seenStar = true
        elseif verComponentTxt == "*" then
            error("star is only allowed with '==' and '!=' operators", 0)
        else
            local n = math.tointeger(verComponentTxt)
            if not n then
                error(string.format("version component is not an integer: %s", verComponentTxt), 0)
            end
            table.insert(components, n)
        end
    end

    if #components == 0 then
        error("empty version", 0)
    end

    return ns.Version(table.unpack(components))
end

--- @alias VersionSpecOp "~"|"=="|"!="|">="|">"|"<="|"<"

--- @private
--- @class VersionSpecCompiler: ammcore.class.Base
VersionSpecCompiler = class.create("VersionSpecCompiler")

--- @package
VersionSpecCompiler._ops = {
    ["~"] = function(self, ver) self:addCompat(ver) end,
    ["=="] = function(self, ver) self:addEq(ver) end,
    ["!="] = function(self, ver) self:addNe(ver) end,
    [">="] = function(self, ver) self:addGe(ver) end,
    [">"] = function(self, ver) self:addGt(ver) end,
    ["<="] = function(self, ver) self:addLe(ver) end,
    ["<"] = function(self, ver) self:addLt(ver) end,
}

function VersionSpecCompiler:__init()
    --- @private
    --- @type Version?
    self._upperLimit = nil

    --- @private
    --- @type boolean?
    self._upperLimitInclusive = nil

    --- @private
    --- @type Version?
    self._lowerLimit = nil

    --- @private
    --- @type boolean?
    self._lowerLimitInclusive = nil

    --- @private
    --- @type Version?
    self._exactLimit = nil

    --- @private
    --- @type Version[]
    self._exclusions = {}

    --- @private
    --- @type boolean
    self._isNa = false
end

--- @param op VersionSpecOp
--- @param ver Version
function VersionSpecCompiler:add(op, ver)
    if not self._isNa then
        VersionSpecCompiler._ops[op](self, ver)
    end
end

--- @param ver Version
function VersionSpecCompiler:addCompat(ver)
    self:addGe(ver)
    self:addEq(ver:makeWild())
end

--- @param ver Version
function VersionSpecCompiler:addEq(ver)
    local cur = self._exactLimit
    if not cur then
        self._exactLimit = ver
    else
        for i = 1, math.max(#ver._components, #cur._components) do
            local v = ver._components[i] or 0
            local c = cur._components[i] or 0

            if v == c then
                -- Prefixes are equal so far, do nothing
            elseif v == "*" then
                -- New version is more relaxed, keep current version.
                return
            elseif c == "*" then
                -- Current version is more relaxed, keep new version.
                self._exactLimit = ver
                return
            else
                -- Prefixes are not equal, versions are incompatible.
                self._isNa = true
                return
            end
        end
    end
end

--- @param ver Version
function VersionSpecCompiler:addNe(ver)
    table.insert(self._exclusions, ver)
end

--- @param ver Version
function VersionSpecCompiler:addGe(ver)
    if not self._lowerLimit or self._lowerLimit < ver then
        self._lowerLimit = ver
        self._lowerLimitInclusive = true
    end
end

--- @param ver Version
function VersionSpecCompiler:addGt(ver)
    if not self._lowerLimit or self._lowerLimit <= ver then
        self._lowerLimit = ver
        self._lowerLimitInclusive = false
    end
end

--- @param ver Version
function VersionSpecCompiler:addLe(ver)
    if not self._upperLimit or self._upperLimit > ver then
        self._upperLimit = ver
        self._upperLimitInclusive = true
    end
end

--- @param ver Version
function VersionSpecCompiler:addLt(ver)
    if not self._upperLimit or self._upperLimit >= ver then
        self._upperLimit = ver
        self._upperLimitInclusive = false
    end
end

--- @return (fun(v: Version): boolean), boolean
function VersionSpecCompiler:compile()
    if self._isNa then
        return function() return false end, true
    end

    local isExact = (
        self._exactLimit
        and self._exactLimit._components[#self._exactLimit._components] ~= "*"
        or false
    )

    local pa = {}
    local cmp = {}
    local env = { ipairs = ipairs }
    if self._exactLimit then
        env.exactLimit = self._exactLimit
        table.insert(pa, "local exactLimit = exactLimit")
        table.insert(cmp, "if not (x == exactLimit) then return false end")
    end
    if self._lowerLimit then
        if self._lowerLimitInclusive then
            if isExact and not (self._exactLimit >= self._lowerLimit) then
                return function() return false end, true
            elseif not isExact then
                env.lowerLimit = self._lowerLimit
                table.insert(pa, "local lowerLimit = lowerLimit")
                table.insert(cmp, "if not (x >= lowerLimit) then return false end")
            end
        else
            if isExact and not (self._exactLimit > self._lowerLimit) then
                return function() return false end, true
            elseif not isExact then
                env.lowerLimit = self._lowerLimit
                table.insert(pa, "local lowerLimit = lowerLimit")
                table.insert(cmp, "if not (x > lowerLimit) then return false end")
            end
        end
    end
    if self._upperLimit then
        if self._upperLimitInclusive then
            if isExact and not (self._exactLimit <= self._upperLimit) then
                return function() return false end, true
            elseif not isExact then
                env.upperLimit = self._upperLimit
                table.insert(pa, "local upperLimit = upperLimit")
                table.insert(cmp, "if not (x <= upperLimit) then return false end")
            end
        else
            if isExact and not (self._exactLimit < self._upperLimit) then
                return function() return false end, true
            elseif not isExact then
                env.upperLimit = self._upperLimit
                table.insert(pa, "local upperLimit = upperLimit")
                table.insert(cmp, "if not (x < upperLimit) then return false end")
            end
        end
    end
    if #self._exclusions > 0 then
        if isExact then
            for _, exclusion in ipairs(self._exclusions) do
                if self._exactLimit == exclusion then
                    return function() return false end, true
                end
            end
        else
            env.exclusions = self._exclusions
            table.insert(pa, "local exclusions = exclusions")
            table.insert(cmp, "for _, exclusion in ipairs(exclusions) do if x == exclusion then return false end end")
        end
    end
    table.insert(cmp, "return true")

    local code = string.format(
        "%s; return function(x) %s end",
        table.concat(pa, ";"), table.concat(cmp, ";")
    )

    return assert(load(code, "<version comparator>", "bt", env))(), isExact
end

--- Represents a version specification, i.e. a parsed requirement version.
---
--- @class VersionSpec: ammcore.class.Base
--- @operator add(VersionSpec): VersionSpec
ns.VersionSpec = class.create("VersionSpec")

--- @param version Version? if given, produces a version spec with an exact version pinned.
function ns.VersionSpec:__init(version)
    --- @package
    --- @type { version: Version, op: VersionSpecOp }[]
    self._components = {}

    if version then
        table.insert(self._components, { version = version, op = "==" })
    end

    --- @private
    --- @type (fun(x: Version): boolean) | nil
    self._cmp = nil

    --- @private
    --- @type boolean?
    self._isExact = nil
end

--- @return string
function ns.VersionSpec:__tostring()
    local res, sep, opSep = "", "", #self._components == 1 and " " or ""
    for _, component in ipairs(self._components) do
        res = res .. sep .. component.op .. opSep .. tostring(component.version)
        sep = ", "
    end
    return res
end

--- Combine requirements from two version specs.
---
--- @param lhs VersionSpec
--- @param rhs VersionSpec
--- @return VersionSpec
function ns.VersionSpec.concat(lhs, rhs)
    if not class.isChildOf(rhs, ns.VersionSpec) then
        error(string.format("can't append %s to a version spec", rhs))
    end

    local res = ns.VersionSpec()
    fun.a.extend(res._components, lhs._components)
    fun.a.extend(res._components, rhs._components)
    return res
end

--- @private
function ns.VersionSpec:_compile()
    local c = VersionSpecCompiler()
    for _, component in ipairs(self._components) do
        c:add(component.op, component.version)
    end
    self._cmp, self._isExact = c:compile()
end

--- Return `true` if this spec matches the given version.
---
--- @param ver Version version to check.
--- @return boolean match `true` if version spec allows this version.
function ns.VersionSpec:matches(ver)
    if not self._cmp then
        self:_compile()
    end
    return self._cmp --[[@as fun(x: Version): boolean]](ver)
end

--- Return `true` if this spec pins an exact version of a package.
---
--- @return boolean isExact true` if this spec allows exactly one version of a package.
function ns.VersionSpec:isExact()
    if self._isExact == nil then
        self:_compile()
    end
    return self._isExact --[[@as boolean]]
end

--- Parse a specification string.
---
--- Specification consists of components separated by comas. Each component has
--- an operator and a version, for example ``>=1.0.0, <2.0.0, !=1.5.*``.
---
--- Allowed operators include:
---
--- - ``==``, strict version equality. Version specifications used with this
---   operator can have wildcard at the end, in which case the operator only
---   compares prefixes;
--- - ``!=``, strict version inequality.Version specifications used with this
---   operator can have wildcard at the end, in which case the operator only
---   compares prefixes;
--- - ``>``, greater than the given version;
--- - ``>=``, greater than or equal to the given version;
--- - ``<``, lesser than the given version;
--- - ``<=``, lesser than or equal to the given version;
--- - ``~``, compatible with the given version. Using this operator allows the last
---   component of the version to be greater than or equal to the specified one.
---   That is, ``~1.0.5`` is equivalent to ``==1.0.*, >=1.0.5``.
---
--- If operator is absent, it is implied to be ``==``.
---
--- @param specTxt string
--- @return VersionSpec spec parsed version spec.
function ns.parseSpec(specTxt)
    local res = ns.VersionSpec()

    for specComponentTxt in (specTxt .. ","):gmatch("(.-),") do
        if specComponentTxt:len() > 0 then
            local op, verTxt = specComponentTxt:match("^%s*([!<>=~]*)%s*(.-)%s*$")
            if not op or not verTxt then
                error(string.format("can't parse version spec %s", specComponentTxt), 0)
            end
            if op == "" then
                op = "=="
            end
            if VersionSpecCompiler._ops[op] then
                --- @cast op VersionSpecOp
                table.insert(res._components, {
                    version = ns.parse(verTxt, op == "" or op == "==" or op == "!="),
                    op = op,
                })
            else
                error(string.format("unknown operator %s", op), 0)
            end
        end
    end

    return res
end

return ns
