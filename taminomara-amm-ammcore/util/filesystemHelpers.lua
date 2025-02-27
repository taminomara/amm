local fin = require "ammcore/util/fin"

--- Helpers for working with file system.
local filesystemHelpers = {}

--- Read file at the given path.
---
--- @param path string
--- @return string
function filesystemHelpers.readFile(path)
    if not (filesystem.exists(path) and filesystem.isFile(path)) then
        error("No file named " .. path)
    end

    local fd = filesystem.open(path, "r")
    local _<close> = fin.defer(fd.close, fd)

    local content = ""
    while true do
        local chunk = fd:read(1024)
        if chunk == nil or #chunk == 0 then
            break
        end
        content = content .. chunk
    end

    return content
end

--- Write file to the given path.
---
--- @param path string
--- @param content string
function filesystemHelpers.writeFile(path, content)
    local fd, err = filesystem.open(path, "w")
    if not fd then
        error(err or ("Failed to write file " .. path))
    end
    local _<close> = fin.defer(fd.close, fd)

    fd:write(content)
end

--- Copy file by reading it and then writing it to a new location.
---
--- @param from string
--- @param to string
function filesystemHelpers.copyFile(from, to)
    filesystemHelpers.writeFile(to, filesystemHelpers.readFile(from))
end

return filesystemHelpers
