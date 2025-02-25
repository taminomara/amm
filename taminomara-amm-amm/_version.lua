--- Current AMM version info.
local version = {}

--- AMM package version.
---
--- @type string
version.version = "0.0.0"

--- AMM package version as an array.
---
--- @type integer[]
version.versionComponents = __AMM_MAKE_READONLY({ 0, 0, 0 })

return __AMM_MAKE_READONLY(version)
