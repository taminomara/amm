local bootloader = require "ammcore.bootloader"
local pkg = require "ammcore.pkg"

if bootloader.getLoaderKind() ~= "drive" then
    computer.panic("Program \".install\" only works with drive loader")
end

pkg.checkAndUpdate(false)
