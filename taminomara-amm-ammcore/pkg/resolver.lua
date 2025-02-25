local class = require "ammcore/util/class"

--- Resolves dependencies.
local ns = {}

--- A package candidate.
---
--- @class ammcore.pkg.resolver.Candidate: class.Base
local Candidate = class.create("Candidate")

--- @generic T: ammcore.pkg.resolver.Candidate
--- @param self T
--- @return T
function Candidate:New(name, versions)
    self = class.Base.New(self)

    --- Name of this package.
    ---
    --- @type string
    self.name = name

    --- All available versions.
    ---
    --- @type ammcore.pkg.package.PackageVersion[]
    self.versions = versions

    --- Indicates that this package is directly requested by the user, and not
    --- a dependency from another package.
    ---
    --- @type boolean
    self.isRootPackage = false

    --- Number of times this package was requested by other packages.
    ---
    --- @type integer
    self.requested = 0

    --- Number of times this package was requested with an exact version.
    ---
    --- @type integer
    self.requestedExact = 0

    --- Number of version conflicts that happened involving this package.
    ---
    --- @type integer
    self.conflicts = 0

    return self
end

--- @param lhs ammcore.pkg.resolver.Candidate
--- @param rhs ammcore.pkg.resolver.Candidate
function Candidate.__lt(lhs, rhs)
    if lhs.isRootPackage ~= rhs.isRootPackage then
        return rhs.isRootPackage
    elseif (lhs.requestedExact > 0) ~= (rhs.requestedExact > 0) then
        return rhs.requestedExact > 0
    else
        return lhs.conflicts < rhs.conflicts
    end
end

--- @param lhs ammcore.pkg.resolver.Candidate
--- @param rhs ammcore.pkg.resolver.Candidate
function Candidate.__lte(lhs, rhs)
    return not rhs < lhs
end

--- @param lhs ammcore.pkg.resolver.Candidate
--- @param rhs ammcore.pkg.resolver.Candidate
function Candidate.__gt(lhs, rhs)
    return rhs < lhs
end

--- @param lhs ammcore.pkg.resolver.Candidate
--- @param rhs ammcore.pkg.resolver.Candidate
function Candidate.__gte(lhs, rhs)
    return not lhs < rhs
end

return ns
