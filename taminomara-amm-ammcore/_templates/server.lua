local bootloader = require "ammcore.bootloader"
local json = require "ammcore._contrib.json"
local fsh = require "ammcore.fsh"
local log = require "ammcore.log"

--- Write server template.
local ns = {}

local logger = log.getLogger()

function ns.writeServerTemplate(devRoot)
    local templateDataJson = bootloader.findModuleCode("taminomara-amm-ammcore/_templates/bootstrap/server.json")
    --- @type table<string, string>
    local templateData = json.decode(templateDataJson)

    local filenames = {}
    for path in pairs(templateData) do
        table.insert(filenames, path)
    end
    table.sort(filenames)

    for _, filename in ipairs(filenames) do
        local path = filesystem.path(devRoot, filename)
        local dir = fsh.parent(path)
        if not filesystem.exists(dir) then
            logger:trace("Creating %s", dir)
            assert(filesystem.createDir(dir, true))
        end
        if not filesystem.exists(path) then
            logger:trace("Writing %s", path)
            fsh.writeFile(path, templateData[filename])
        else
            logger:trace("Skipping %s: already exists", path)
        end
    end
end

return ns
