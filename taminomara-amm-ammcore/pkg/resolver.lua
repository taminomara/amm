--- @namespace ammcore.pkg.resolver

local class = require "ammcore.class"
local log = require "ammcore.log"
local version = require "ammcore.pkg.version"

--- Resolves dependencies.
local ns = {}

local logger = log.getLogger()

--- A package candidate.
---
--- !doc private
--- @class _Candidate: ammcore.class.Base
local Candidate = class.create("Candidate")

--- @param name string
--- @param versions ammcore.pkg.package.PackageVersion[]
--- @param updateAll boolean
function Candidate:__init(name, versions, updateAll)
    --- Name of this package.
    ---
    --- @type string
    self.name = name

    --- All available versions.
    ---
    --- @type ammcore.pkg.package.PackageVersion[]
    self.versions = versions

    if updateAll then
        table.sort(self.versions, function(lhs, rhs) return lhs.version > rhs.version end)
    else
        table.sort(self.versions, function(lhs, rhs)
            if lhs.isInstalled ~= rhs.isInstalled then
                return lhs.isInstalled
            else
                return lhs.version > rhs.version
            end
        end)
    end

    --- Indicates that this candidate has a pinned version.
    ---
    --- @type boolean
    self.isPinned = false

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
end

--- @param lhs _Candidate
--- @param rhs _Candidate
function Candidate.__lt(lhs, rhs)
    if (#lhs.versions > 0) ~= (#rhs.versions > 0) then
        return #rhs.versions == 0
    elseif (lhs.requestedExact > 0) ~= (rhs.requestedExact > 0) then
        return rhs.requestedExact > 0
    elseif lhs.isRootPackage ~= rhs.isRootPackage then
        return rhs.isRootPackage
    else
        return lhs.conflicts < rhs.conflicts
    end
end

--- @param lhs _Candidate
--- @param rhs _Candidate
function Candidate.__gt(lhs, rhs)
    return rhs < lhs
end

--- @param candidates table<string, _Candidate>
--- @return _Candidate?
local function getNextCandidate(candidates)
    local best = nil
    for _, candidate in pairs(candidates) do
        if candidate.requested > 0 and not candidate.isPinned then
            if not best or candidate > best then
                best = candidate
            end
        end
    end
    return best
end

--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec>
--- @param bestAttempt { candidate: _Candidate, versionIndex: integer }[]
--- @return string
local function describeBestAttempt(rootRequirements, bestAttempt)
    if #bestAttempt == 0 then
        return "Can't find appropriate package versions"
    end

    local failedPkg = assert(bestAttempt[#bestAttempt])
    local name = failedPkg.candidate.name
    local res = string.format("Can't find appropriate version for package %s.\n", name)

    if #failedPkg.candidate.versions == 0 then
        res = res .. "Package not found.\n"
    else
        res = res .. "Available versions: "
        local sep = ""
        for _, ver in ipairs(failedPkg.candidate.versions) do
            res = res .. sep .. tostring(ver.version)
            sep = ", "
        end
        res = res .. "\n"
    end

    local combinedSpec = version.VersionSpec()

    if rootRequirements[name] then
        res = res .. string.format("config.packages requires %s %s\n", name, rootRequirements[name])
        combinedSpec = combinedSpec:concat(rootRequirements[name])
    end

    for _, pinnedVersion in ipairs(bestAttempt) do
        local candidate = pinnedVersion.candidate.versions[pinnedVersion.versionIndex]
        if candidate and not candidate.isBroken then
            local requirements = candidate:getAllRequirements()
            if requirements[name] then
                res = res .. string.format(
                    "Package %s == %s requires %s %s\n",
                    candidate.name,
                    candidate.version,
                    name,
                    requirements[name]
                )
                combinedSpec = combinedSpec:concat(requirements[name])
            end
        end
    end

    for _, ver in ipairs(failedPkg.candidate.versions) do
        if combinedSpec:matches(ver.version) then
            if ver.isBroken then
                res = res .. string.format(
                    "Version %s == %s can'be used because it was skipped\n", name, ver.version
                )
            else
                res = res .. string.format(
                    "Version %s == %s can'be used because it requires ", name, ver.version
                )
                local sep = ""
                local requirements = ver:getAllRequirements()
                for _, pinnedVersion in ipairs(bestAttempt) do
                    local candidate = pinnedVersion.candidate.versions[pinnedVersion.versionIndex]
                    if
                        candidate
                        and requirements[candidate.name]
                        and not requirements[candidate.name]:matches(candidate.version)
                    then
                        res = res .. sep .. string.format("%s %s", candidate.name, requirements[candidate.name])
                        sep = ", "
                    end
                end
                res = res .. "\n"
            end
        end
    end

    return res:sub(1, res:len() - 1)
end

--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec>
--- @param provider ammcore.pkg.provider.Provider
--- @param updateAll boolean
--- @param includeRemotePackages boolean
--- @return { candidate: _Candidate, versionIndex: integer }[]
local function resolve(rootRequirements, provider, updateAll, includeRemotePackages)
    --- @type table<string, _Candidate>
    local candidates = {}

    for name, spec in pairs(rootRequirements) do
        local candidate = Candidate(name, provider:findPackageVersions(name, includeRemotePackages), updateAll)

        candidate.isRootPackage = true
        candidate.requested = 1
        candidate.requestedExact = spec:isExact() and 1 or 0

        candidates[name] = candidate
    end

    --- @type { candidate: _Candidate, versionIndex: integer }[]
    local pinned = {}
    --- @type table<string, ammcore.pkg.package.PackageVersion>
    local pinnedByName = {}
    --- @type { candidate: _Candidate, versionIndex: integer }[]
    local bestAttempt = {}

    do
        local nextCandidate = getNextCandidate(candidates)

        if not nextCandidate then
            return pinned
        end

        nextCandidate.isPinned = true
        table.insert(pinned, { candidate = nextCandidate, versionIndex = 0 })
    end

    while #pinned > 0 do
        local pinnedCandidate = pinned[#pinned]

        if pinnedCandidate.versionIndex >= 1 then
            -- Unpin previous candidate version.

            -- Process previous candidate version's requirements.
            local pinnedVersion = pinnedCandidate.candidate.versions[pinnedCandidate.versionIndex]

            for name, spec in pairs(pinnedVersion:getAllRequirements()) do
                candidates[name].requested = candidates[name].requested - 1
                if spec:isExact() then
                    candidates[name].requestedExact = candidates[name].requestedExact - 1
                end
            end

            pinnedByName[pinnedVersion.name] = nil
        end

        pinnedCandidate.versionIndex = pinnedCandidate.versionIndex + 1
        while pinnedCandidate.versionIndex <= #pinnedCandidate.candidate.versions do
            -- Try pinning this candidate version.
            local pinnedVersion = pinnedCandidate.candidate.versions[pinnedCandidate.versionIndex]
            local requirements
            local isViable = true

            if pinnedVersion.isBroken then
                goto continue
            end

            -- Check if root requirements allow using this version.
            if
                rootRequirements[pinnedVersion.name]
                and not rootRequirements[pinnedVersion.name]:matches(pinnedVersion.version)
            then
                pinnedCandidate.candidate.conflicts = pinnedCandidate.candidate.conflicts + 1
                goto continue
            end

            -- Check if requirements of previously pinned candidate versions
            -- allow using this version.
            for name, prevPinnedVersion in pairs(pinnedByName) do
                local prevRequirements = prevPinnedVersion:getAllRequirements()
                if
                    prevRequirements[pinnedVersion.name]
                    and not prevRequirements[pinnedVersion.name]:matches(pinnedVersion.version)
                then
                    pinnedCandidate.candidate.conflicts = pinnedCandidate.candidate.conflicts + 1
                    candidates[name].conflicts = candidates[name].conflicts + 1
                    isViable = false
                    break
                end
            end
            if not isViable then
                goto continue
            end

            -- Fetch candidate requirements.
            do
                local ok, err = pcall(function() requirements = pinnedVersion:getAllRequirements() end)
                if not ok then
                    pinnedVersion.isBroken = true
                    logger:warning("Skipping %s == %s: %s", pinnedVersion.name, pinnedVersion.version, err)
                    goto continue
                end
            end

            -- Check that new requirements are compatible
            -- with previously pinned candidate versions
            for name, spec in pairs(requirements) do
                if pinnedByName[name] and not spec:matches(pinnedByName[name].version) then
                    pinnedCandidate.candidate.conflicts = pinnedCandidate.candidate.conflicts + 1
                    candidates[name].conflicts = candidates[name].conflicts + 1
                    isViable = false
                    break
                end
            end

            if isViable then
                break
            end

            ::continue::

            pinnedCandidate.versionIndex = pinnedCandidate.versionIndex + 1
        end

        if pinnedCandidate.versionIndex <= #pinnedCandidate.candidate.versions then
            -- Pinned a candidate version.

            -- Process this candidate version's requirements.
            local pinnedVersion = pinnedCandidate.candidate.versions[pinnedCandidate.versionIndex]

            for name, spec in pairs(pinnedVersion:getAllRequirements()) do
                if not candidates[name] then
                    -- Haven't seen this package before.
                    candidates[name] = Candidate(name, provider:findPackageVersions(name, includeRemotePackages),
                        updateAll)
                end

                candidates[name].requested = candidates[name].requested + 1
                if spec:isExact() then
                    candidates[name].requestedExact = candidates[name].requestedExact + 1
                end
            end

            pinnedByName[pinnedVersion.name] = pinnedVersion

            -- Move on to the next candidate.
            local nextCandidate = getNextCandidate(candidates)

            if not nextCandidate then
                return pinned
            end

            nextCandidate.isPinned = true
            table.insert(pinned, { candidate = nextCandidate, versionIndex = 0 })
        else
            -- Didn't find a suitable candidate version, backtrack.
            if #pinned > #bestAttempt then
                -- Save best attempt for error reporting.
                bestAttempt = {}
                for _, prevPinnedCandidate in ipairs(pinned) do
                    table.insert(
                        bestAttempt,
                        {
                            candidate = prevPinnedCandidate.candidate,
                            versionIndex = prevPinnedCandidate.versionIndex,
                        }
                    )
                end
            end

            pinnedCandidate.candidate.isPinned = false
            table.remove(pinned)
        end
    end

    error(describeBestAttempt(rootRequirements, bestAttempt), 0)
end

--- Find suitable package versions to satisfy the given requirements.
---
--- Resolving package versions is an NP-complete task. This implementation is inspired
--- by the `NuGet package manager`_.
---
--- Essentially, this algorithm performs a full search using DFS-like approach,
--- with some heuristics to speed it up.
---
--- On every step of an algorithm, we have a stack of package candidates that we will
--- install, each candidate has a specific version pinned.
---
--- To make a step, we select the next package candidate that needs to be installed,
--- and try pinning one of its versions.
---
--- If new pinned version doesn't conflict with other pinned candidates,
--- we descend and try selecting the next candidate, and so on.
---
--- If no version could be pinned without creating a conflict with other pinned
--- candidates, it means we can't find a solution with current pins. In this case,
--- we backtrack to the previously selected package candidate, unpin its version
--- and pin the next one.
---
--- We continue until either there is no more candidates to install, or we've
--- backtracked to the end of the stack.
---
--- Heuristics to speed up this process include selecting a candidate that will narrow
--- down our search the most, and selecting order in which to try versions
--- of a candidate.
---
--- When selecting an uninstalled candidate, we consider the following factors:
---
--- - we prefer packages that are included in ``rootRequirements``;
--- - we prefer packages that have an exact version required (version range narrowed by a ``==`` spec);
--- - we track how many conflicts we've discovered while attempting to pin a candidate
---   during previous iterations, and prefer ones that produce higher number of conflicts.
---
--- .. _NuGet package manager: https://fsprojects.github.io/Paket/resolver.html
---
--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec> initial requirements to be considered.
--- @param provider ammcore.pkg.provider.Provider where to find packages.
--- @param updateAll boolean update local packages even if current versions don't conflict with requirements.
--- @param includeRemotePackages boolean allow package to fetch packages from github or other remote source.
--- @return ammcore.pkg.package.PackageVersion[] solution package versions that satisfy requirements.
function ns.resolve(rootRequirements, provider, updateAll, includeRemotePackages)
    local res = {}
    for _, candidate in ipairs(resolve(rootRequirements, provider, updateAll, includeRemotePackages)) do
        table.insert(res, candidate.candidate.versions[candidate.versionIndex])
    end
    return res
end

return ns
