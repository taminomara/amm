local bootloader = require "ammcore.bootloader"

local pkgs = bootloader.getServerApi():lsPkg()
local pkgNames = {}
for name, _ in pairs(pkgs) do
    table.insert(pkgNames, name)
end
table.sort(pkgNames)
for _, name in ipairs(pkgNames) do
    print(string.format(
        "%-30s == %s%s",
        name,
        pkgs[name].version,
        pkgs[name].isDevMode and " [dev]" or "")
    )
end
