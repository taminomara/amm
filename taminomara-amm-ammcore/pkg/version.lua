local class = require "ammcore/util/class"
local array = require "ammcore/util/array"

local ns = {}

--- Represents a package version.
---
--- @class ammcore.pkg.version.Version: class.Base
--- @operator concat(integer|"*"): ammcore.pkg.version.Version
ns.Version = class.create("Version")

--- @param ... integer|"*"
function ns.Version:New(...)
    self = class.Base.New(self)

    --- @private
    --- @type (integer|"*")[]
    self._components = { ... }

    --- @private
    --- @type string?
    self._canonicalString = nil

    return self
end

--- Return version without its last component.
---
--- @return ammcore.pkg.version.Version
function ns.Version:up()
    return ns.Version:New(table.unpack(self._components, 1, #self._components - 1))
end

--- @return string
function ns.Version:__tostring()
    return table.concat(self._components, ".")
end

--- @return string
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

--- Check that versions are compatible (i.e. `x~=1.0.5` means `x>=1.0.5 and x==1.0.*`).
---
--- @param lhs ammcore.pkg.version.Version
--- @param rhs ammcore.pkg.version.Version
--- @return boolean
function ns.Version.compat(lhs, rhs)
    local len = #rhs._components
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("Star is not allowed here") end
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
--- @param lhs ammcore.pkg.version.Version
--- @param rhs ammcore.pkg.version.Version
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
--- @param lhs ammcore.pkg.version.Version
--- @param rhs ammcore.pkg.version.Version
--- @return boolean
function ns.Version.__le(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("Star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent <= rhsComponent
        end
    end
    return true
end

--- Check that version comes before another.
---
--- @param lhs ammcore.pkg.version.Version
--- @param rhs ammcore.pkg.version.Version
--- @return boolean
function ns.Version.__lt(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("Star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent < rhsComponent
        end
    end
    return false
end

--- Check that versions are equal or one comes after another.
---
--- @param lhs ammcore.pkg.version.Version
--- @param rhs ammcore.pkg.version.Version
--- @return boolean
function ns.Version.__ge(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("Star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent >= rhsComponent
        end
    end
    return true
end

--- Check that version comes after another.
---
--- @param lhs ammcore.pkg.version.Version
--- @param rhs ammcore.pkg.version.Version
--- @return boolean
function ns.Version.__gt(lhs, rhs)
    local len = math.max(#lhs._components, #rhs._components)
    for i = 1, len do
        local lhsComponent = lhs._components[i] or 0
        local rhsComponent = rhs._components[i] or 0
        if lhsComponent == "*" or rhsComponent == "*" then error("Star is not allowed here") end
        if lhsComponent ~= rhsComponent then
            return lhsComponent > rhsComponent
        end
    end
    return false
end

--- Append component to a version.
---
--- @param lhs ammcore.pkg.version.Version
--- @param rhs integer|"*"
--- @return ammcore.pkg.version.Version
function ns.Version.__concat(lhs, rhs)
    if not (type(rhs) == "number" or rhs == "*") then error("invalid version component") end
    local result = ns.Version:New(table.unpack(lhs._components))
    table.insert(result._components, rhs)
    return result
end

--- Parse a version string.
---
--- @param s string
--- @param allowStar boolean?
--- @return ammcore.pkg.version.Version
function ns.parse(s, allowStar)
    local components = {}
    local seenStar = false
    for component in (s .. "."):gmatch("(.-)%.") do
        if seenStar then
            error("star is only allowed in the last version component")
        end
        if allowStar and component == "*" then
            table.insert(components, "*")
            seenStar = true
        elseif component == "*" then
            error("star is not allowed here")
        else
            local n = math.tointeger(component)
            if not n then
                error("version component is not an integer: " .. component)
            end
            table.insert(components, n)
        end
    end

    if #components == 0 then
        error("empty version")
    end

    return ns.Version:New(table.unpack(components))
end

--- @type table<string, fun(a: ammcore.pkg.version.Version, b: ammcore.pkg.version.Version): boolean>
local ops = {
    ["~="] = function(a, b) return a:compat(b) end,
    ["=="] = function(a, b) return a == b end,
    ["!="] = function(a, b) return a ~= b end,
    [">="] = function(a, b) return a >= b end,
    [">"] = function(a, b) return a > b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"] = function(a, b) return a < b end,
}

--- Represents a version specification, i.e. a parsed requirement version.
---
--- @class ammcore.pkg.version.VersionSpec: class.Base
--- @operator add(ammcore.pkg.version.VersionSpec): ammcore.pkg.version.VersionSpec
ns.VersionSpec = class.create("VersionSpec")

--- @param version ammcore.pkg.version.Version?
---
--- @generic T: ammcore.pkg.version.VersionSpec
--- @param self T
--- @return T
function ns.VersionSpec:New(version)
    self = class.Base.New(self)

    --- @package
    --- @type { version: ammcore.pkg.version.Version, op: string, cmp: fun(a: ammcore.pkg.version.Version, b: ammcore.pkg.version.Version): boolean }[]
    self._specs = {}

    if version then
        table.insert(self._specs, { version = version, op = "==", cmp = ops["=="] })
    end

    return self
end

--- @return string
function ns.VersionSpec:__tostring()
    local res, sep = "", ""
    for _, spec in ipairs(self._specs) do
        res = res .. sep .. spec.op .. tostring(spec.version)
        sep = ", "
    end
    return res
end

--- @param lhs ammcore.pkg.version.VersionSpec
--- @param rhs any ammcore.pkg.version.VersionSpec
--- @return ammcore.pkg.version.VersionSpec
function ns.VersionSpec.__concat(lhs, rhs)
    if not class.isChildOf(rhs, ns.VersionSpec) then
        error(string.format("Can't append %s to a version spec", rhs))
    end

    local res = ns.VersionSpec:New()
    array.insertMany(res._specs, lhs._specs)
    array.insertMany(res._specs, rhs._specs)
    return res
end

--- Return `true` if this spec matches the given version.
---
--- @param ver ammcore.pkg.version.Version
--- @return boolean
function ns.VersionSpec:matches(ver)
    for _, spec in ipairs(self._specs) do
        if not spec.cmp(ver, spec.version) then
            return false
        end
    end
    return true
end

--- Parse a version string.
---
--- @param specs string
--- @return ammcore.pkg.version.VersionSpec
function ns.parseSpec(specs)
    local res = ns.VersionSpec:New()

    for spec in (specs .. ","):gmatch("%s*(.-),%s*") do
        if spec:len() > 0 then
            local op, s = spec:match("^%s*([<>=~]*)%s*(.*)%s*$")
            if op == "" then
                op = "=="
            end
            if not ops[op] then
                error("unknown version comparator " .. op)
            end
            table.insert(res._specs, {
                version = ns.parse(s, op == "" or op == "==" or op == "!="),
                op = op,
                cmp = ops[op],
            })
        end
    end

    return res
end

-- --- @class Version

-- --- @class VersionSpec
-- --- @field satisfies fun(self: VersionSpec, v: Version): boolean

-- --- @class Package
-- --- @field name string
-- --- @field versions PackageVersion[]
-- --- @field nRequired integer
-- --- @field resolutionPriorityBoost integer

-- --- @class PackageVersion
-- --- @field version Version
-- --- @field requirements table<string, VersionSpec>

-- --- Package resolution algorithm is, in worst case, NP-hard. We use a backtracking
-- --- algotithm with heuristics to solve this problem.
-- function version.resolve()
--     --- @type table<string, Package>
--     local packages = {}
--     --- @type Package[]
--     local unpinnedVersions = {}

--     --- Stack of packages for which we've pinned a version.
--     ---
--     --- Top of the stack is the current package, for which we're trying to find
--     --- an acceptable version.
--     ---
--     --- @type [Package, integer][]
--     local backtrackStack = {}
--     --- @type table<string, PackageVersion>
--     local pinnedVersions = {}

--     do
--         local nextPackage = table.remove(unpinnedVersions)
--         if not nextPackage then
--             -- No more packages to pin, success!
--             return pinnedVersions
--         end

--         table.insert(
--             backtrackStack,
--             {
--                 package = nextPackage,
--                 versionIndex = 0,
--             }
--         )
--     end

--     while true do
--         -- Get current package. We're iterating through its versions, and seeing
--         -- if there is one that's able to satisfy all constraints.
--         local currentPackage, currentVersionIndex = table.unpack(backtrackStack[#backtrackStack])

--         -- On a previous iteration of the `while` loop we've checked this version
--         -- and determined that it is not eligible. Thus, we'll not be including
--         -- requirements for this version to the solution.
--         if currentVersionIndex >= 1 then
--             for requirementName, _ in pairs(currentPackage.versions[currentVersionIndex].requirements) do
--                     if not packages[requirementName] then
--                         -- We haven't seen this package before, fetch its metadata.
--                         local requirementPackage = fetchPackageMetadata(requirementName)
--                         if not requirementPackage then
--                             computer.log(2, "Unable to find metadata for package " .. requirementName)
--                             eligible = false
--                             break
--                         end
--                         packages[requirementName] = requirementPackagecandidateVersion
--                     end
--                 packages[requirementName].nRequired = packages[requirementName].nRequired - 1
--             end
--         end

--         -- Continue iterating over potential version candidates.
--         local foundEligibleCandidate = false
--         for i = currentVersionIndex + 1, #currentPackage.versions do
--             currentVersionIndex = i
--             local candidateVersion = currentPackage.versions[currentVersionIndex]

--             -- Check that this candidate doesn't conflict with already pinned versions.
--             local eligible = true
--             if eligible then
--                 -- Check that requirements of other pinned packages don't conflict with this package.
--                 for pinnedName, pinnedVersion in pairs(pinnedVersions) do
--                     if (
--                             pinnedVersion.requirements[currentPackage.name]
--                             and not pinnedVersion.requirements[currentPackage.name]:satisfies(candidateVersion.version)
--                         ) then
--                         currentPackage.resolutionPriorityBoost = currentPackage.resolutionPriorityBoost + 1
--                         packages[pinnedName].resolutionPriorityBoost = packages[pinnedName].resolutionPriorityBoost + 1
--                         eligible = false
--                         break
--                     end
--                 end
--             end
--             if eligible then
--                 -- Check that requirements of this package don't conflict with previously pinned packages.
--                 for requirementName, requirementVersionSpec in pairs(.requirements) do
--                     if (
--                             pinnedVersions[requirementName]
--                             and not requirementVersionSpec:satisfies(pinnedVersions[requirementName].version)
--                         ) then
--                         currentPackage.resolutionPriorityBoost = currentPackage.resolutionPriorityBoost + 1
--                         packages[requirementName].resolutionPriorityBoost = packages[requirementName]
--                         .resolutionPriorityBoost + 1
--                         eligible = false
--                         break
--                     end
--                 end
--             end
--
--             if eligible then
--                 foundEligibleCandidate = true
--                 break
--             end
--         end

--         if foundEligibleCandidate then
--             -- We were able to find a next candidate version.
--             backtrackStack[#backtrackStack][2] = currentVersionIndex
--             pinnedVersions[currentPackage.name] = currentPackage.versions[currentVersionIndex]

--             -- We will include requirements from this version to the solution.
--             for requirementName, _ in pairs(currentPackage.versions[currentVersionIndex]) do
--                 packages[requirementName].nRequired = packages[requirementName].nRequired + 1
--             end

--             local nextPackage = table.remove(unpinnedVersions)
--             if not nextPackage then
--                 -- No more packages to pin, success!
--                 return pinnedVersions
--             end

--             table.insert(
--                 backtrackStack,
--                 {
--                     package = nextPackage,
--                     versionIndex = 0,
--                 }
--             )
--         else
--             -- Backtrack.
--             table.remove(backtrackStack, #backtrackStack)
--             pinnedVersions[currentPackage.name] = nil
--             table.insert(unpinnedVersions, currentPackage)

--             if #backtrackStack == 0 then
--                 -- Checked all candidates, failure =(
--                 return nil
--             end
--         end
--     end
-- end

return ns
