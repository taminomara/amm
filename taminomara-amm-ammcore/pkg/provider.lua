local class = require "ammcore.util.class"

local ns = {}

--- An abstract interface for package provider.
---
--- @class ammcore.pkg.provider.Provider: class.Base
ns.Provider = class.create("Provider")

--- Get versions of a package and a boolean indicating that package was found.
---
--- @param name string
--- @return ammcore.pkg.package.PackageVersion[], boolean
function ns.Provider:findPackageVersions(name)
    return {}, false
end

return ns
