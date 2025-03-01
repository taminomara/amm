local packageTemplate            = require "ammcore.templates.package"
local bootloader                 = require "ammcore.bootloader"

packageTemplate.writePackageTemplate()

print(string.format(
    "Successfully created package 'example' at %s.\n" ..
    "Set your config.prog = \"example\" to see a \"hello world\" message.",
    filesystem.path(assert(bootloader.getDevRoot()), "example")
))
