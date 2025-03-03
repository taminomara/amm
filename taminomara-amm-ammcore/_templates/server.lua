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

    local filenames = {}
    for path in pairs(templateData) do
        table.insert(filenames, path)
    end
    table.sort(filenames)

    for _, filename in ipairs(filenames) do
        local path = filesystem.path(devRoot, filename)
        local dir = filesystemHelpers.parent(path)
        if not filesystem.exists(dir) then
            logger:trace("Creating %s", dir)
            assert(filesystem.createDir(dir, true))
        end
        if not filesystem.exists(path) then
            logger:trace("Writing %s", path)
            filesystemHelpers.writeFile(path, templateData[filename])
        else
            logger:trace("Skipping %s: already exists", path)
        end
    end
end

return ns
