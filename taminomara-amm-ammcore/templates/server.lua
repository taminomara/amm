local bootloader = require "ammcore.bootloader"
local json       = require "ammcore.contrib.json"
local filesystemHelpers = require "ammcore.util.filesystemHelpers"
local log               = require "ammcore.util.log"

--- Write server template.
local ns = {}

local logger = log.Logger:New()

function ns.writeServerTemplate(devRoot)
    local templateDataJson = bootloader.findModuleCode("taminomara-amm-ammcore/_templates/server.json")
    --- @type table<string, string>
    local templateData = json.decode(templateDataJson)
    for path, data in pairs(templateData) do
        path = filesystem.path(devRoot, path)
        local dir = path:match("^(.*)/[^/]*$")
        if not filesystem.exists(dir) then
            logger:trace("Creating %s", dir)
            assert(filesystem.createDir(dir, true))
        end
        if not filesystem.exists(path) then
            logger:trace("Writing %s", path)
            filesystemHelpers.writeFile(path, data)
        else
            logger:trace("Skipping %s: already exists", path)
        end
    end
end

return ns
