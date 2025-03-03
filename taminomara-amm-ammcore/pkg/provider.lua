local class = require "ammcore.util.class"

local ns = {}

--- An abstract interface for package provider.
---
--- @class ammcore.pkg.provider.Provider: class.Base
ns.Provider = class.create("Provider")

--- Get all locally installed packages.
---
--- @return ammcore.pkg.package.PackageVersion[]
function ns.Provider:getLocalPackages()
    return {}
end

--- Get versions of a package and a boolean indicating that package was found.
---
--- @param name string
--- @param includeRemotePackages boolean
--- @return ammcore.pkg.package.PackageVersion[], boolean
function ns.Provider:findPackageVersions(name, includeRemotePackages)
    return {}, false
end

--- Write all caches to disk.
function ns.Provider:finalize()
    -- nothing to do here
end

return ns
