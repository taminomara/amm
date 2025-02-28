local bootloader = require "ammcore/bootloader"
local debugHelpers = require "ammcore/util/debugHelpers"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"

--- Template files for server root directory.
local ns = {}

local function writeServerTemplate(root, templateRoot)
    for _, name in ipairs(filesystem.children(templateRoot)) do
        local templatePath = filesystem.path(templateRoot, name)
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
    if bootloader.getLoaderKind() ~= "drive" then
        error("server templates only available with drive loader")
    end

    local file = debugHelpers.getFile()
    local dir = assert(file:match("^(.*)/[^/]*/[^/]*$"))
    writeServerTemplate(bootloader.getDevRoot(), filesystem.path(dir, "_templates/server"))
end

return ns
