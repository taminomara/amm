local ns                = {}

--- Check if all requirements can be satisfied by the given provider.
---
--- This function is intended to work with local and dev providers,
--- which return one version per package.
---
--- @param rootRequirements table<string, ammcore.pkg.version.VersionSpec>
--- @param provider ammcore.pkg.provider.Provider
--- @return boolean
function ns.verify(rootRequirements, provider)
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    local allRequirements = {}
    --- @type table<string, ammcore.pkg.package.PackageVersion>
    local allPkgs = {}

    do
        local packages = {}
        for name, versionSpec in pairs(rootRequirements) do
            table.insert(packages, name)
            allRequirements[name] = versionSpec
        end

        while #packages > 0 do
            local name = table.remove(packages)

            if allPkgs[name] then
                goto continue
            end

            local pkgs, found = provider:findPackageVersions(name)
            if not found or #pkgs ~= 1 then
                return false
            end

            local pkg = pkgs[1]

            allPkgs[name] = pkg

            do
                local requirements = pkg:getRequirements()
                for name, spec in pairs(requirements) do
                    table.insert(packages, name)
                    if allRequirements[name] then
                        allRequirements[name] = allRequirements[name] .. spec
                    else
                        allRequirements[name] = spec
                    end
                end
            end

            if pkg.isDevMode then
                local requirements = pkg:getDevRequirements()
                for name, spec in pairs(requirements) do
                    table.insert(packages, name)
                    if allRequirements[name] then
                        allRequirements[name] = allRequirements[name] .. spec
                    else
                        allRequirements[name] = spec
                    end
                end
            end

            ::continue::
        end
    end

    for name, pkgVer in pairs(allPkgs) do
        if allRequirements[name] and not allRequirements[name]:matches(pkgVer.version) then
            return false
        end
    end

    return true
end

function ns.install(rootRequirements, provider)
end

function ns.installEeprom()
end

function ns.main()
end

return ns
