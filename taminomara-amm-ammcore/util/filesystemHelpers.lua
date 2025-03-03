local fin = require "ammcore.util.fin"

--- Helpers for working with file system.
local ns = {}

--- Read file at the given path.
---
--- @param path string
--- @return string
function ns.readFile(path)
    if not filesystem.exists(path) then
        error(string.format("failed reading file %s: no such file", path))
    end
    if not filesystem.isFile(path) then
        error(string.format("failed reading file %s: not a file", path))
    end

    local fd = filesystem.open(path, "r")
    local _<close> = fin.defer(fd.close, fd)

    local content = ""
    while true do
        local chunk = fd:read(1024)
        if not chunk or chunk:len() == 0 then
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
function ns.writeFile(path, content)
    local fd, err = filesystem.open(path, "w")
    if not fd then
        error(string.format("failed writing file %s: %s", path, err or "unknown error"))
    end
    local _<close> = fin.defer(fd.close, fd)

    fd:write(content)
end

--- Copy file by reading it and then writing it to a new location.
---
--- @param from string
--- @param to string
function ns.copyFile(from, to)
    ns.writeFile(to, ns.readFile(from))
end

--- Get parent directory of the given path.
---
--- @param path string
--- @return string
function ns.parent(path)
    path = filesystem.path(0, path)

    local parent = path:match("^(.+)/[^/]+$")
    if parent then
        return parent
    else
        return path:sub(1, 1) == "/" and "/" or ""
    end
end

return ns
