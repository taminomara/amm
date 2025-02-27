local _loader = require "ammcore/_loader"
local debugHelpers = require "ammcore/util/debugHelpers"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"

--- Template files for server root directory.
local ns = {}

local function writeServerTemplate(root, templateRoot)
    for _, name in ipairs(filesystem.children(templateRoot)) do
        local templatePath = filesystem.path(root, name)
        local rootPath = filesystem.path(root, name)
        if filesystem.isFile(templatePath) then
            if not filesystem.exists(rootPath) then
                filesystemHelpers.copyFile(templatePath, rootPath)
            end
        elseif filesystem.isDir(templatePath) then
            if not filesystem.exists(rootPath) then
                filesystem.createDir(rootPath, true)
            end
            writeServerTemplate(rootPath, templatePath)
        end
    end
end

--- Write files that should be in the server's root directory.
---
--- These files are meant to help users with setting up a development environment.
--- I.e. you install the AMM server, open its hard drive in your IDE,
--- and you're all set up!
function ns.writeServerTemplate()
    if _loader.getLoaderKind() ~= "drive" then
        error("Server templates only available with drive loader")
    end

    if filesystem.exists("/.amm_state/serverTemplateWritten") then
        return
    end

    local file = debugHelpers.getFile()
    local dir = assert(file:match("^(.*)/[^/]*/[^/]*$"))
    writeServerTemplate("/", filesystem.path(dir, "_templates/server"))
    filesystem.createDir("/.amm_state", true)
    filesystemHelpers.writeFile("/.amm_state/serverTemplateWritten", "")
end

return ns
