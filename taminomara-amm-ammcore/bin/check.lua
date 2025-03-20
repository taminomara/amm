local bootloader = require "ammcore.bootloader"
local pkg = require "ammcore.pkg"

if bootloader.getLoaderKind() ~= "drive" then
    computer.panic("Program \".check\" only works with drive loader")
end

local provider = pkg.getPackageProvider()
if pkg.verify(pkg.gatherRootRequirements(provider), provider) then
    print("Packages are up-to-date")
else
    computer.panic("Packages need an update")
end
