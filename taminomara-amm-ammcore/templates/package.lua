local bootloader        = require "ammcore.bootloader"
local filesystemHelpers = require "ammcore.util.filesystemHelpers"
local log               = require "ammcore.util.log"

local logger = log.Logger:New()

--- Template files for package root directory.
local ns                = {}

--- Write files that should be in the package's root directory.
---
--- These files are meant to help users with setting up a development environment.
--- I.e. you install the AMM package, open its hard drive in your IDE,
--- and you're all set up!
function ns.writePackageTemplate()
    local index = require("ammcore.templates.packageIndex")
    for _, path in ipairs(index) do
        local codePath = filesystem.path("taminomara-amm-ammcore/_templates/package", path)
        local realPath = filesystem.path(assert(bootloader.getDevRoot()), path)
        local realDir = realPath:match("^(.*)/[^/]*$")
        if realDir and not filesystem.exists(realDir) then
            filesystem.createDir(realDir, true)
        end
        if not filesystem.exists(realPath) then
            local code = bootloader.findModuleCode({ codePath })
            logger:trace("Writing %s", realPath)
            filesystemHelpers.writeFile(realPath, assert(code))
        else
            logger:trace("Skipping %s: already exists", realPath)
        end
    end
end

return ns
