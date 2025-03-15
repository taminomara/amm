local class = require "ammcore.class"

--- Source of packages.
---
--- !doctype module
--- @class ammcore.pkg.provider
local ns = {}

--- An abstract interface for package provider.
---
--- @class ammcore.pkg.provider.Provider: ammcore.class.Base
ns.Provider = class.create("Provider")

--- Get all locally installed packages.
---
--- @return ammcore.pkg.package.PackageVersion[] versions locally installed packages.
function ns.Provider:getLocalPackages()
    return {}
end

--- Get versions of a package and a boolean indicating that package was found.
---
--- @param name string package name.
--- @param includeRemotePackages boolean allow package to fetch packages from github or other remote source.
--- @return ammcore.pkg.package.PackageVersion[] versions found versions, could be an empty array.
--- @return boolean found `true` if the package was successfully resolved by this provider.
function ns.Provider:findPackageVersions(name, includeRemotePackages)
    return {}, false
end

--- Write all caches to disk.
function ns.Provider:finalize()
    -- nothing to do here
end

return ns
