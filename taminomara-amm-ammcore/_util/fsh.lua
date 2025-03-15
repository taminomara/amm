local defer = require "ammcore.defer"

--- Helpers for working with FIN file system.
---
--- !doctype module
--- @class ammcore._util.fsh
local ns = {}

--- Read file at the given path or raise an error.
---
--- @param path string path to the file.
--- @return string content file contents.
function ns.readFile(path)
    if not filesystem.exists(path) then
        error(string.format("failed reading file %s: no such file", path))
    end
    if not filesystem.isFile(path) then
        error(string.format("failed reading file %s: not a file", path))
    end

    local fd = filesystem.open(path, "r")
    local _ <close> = defer.defer(fd.close, fd)

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

--- Write file to the given path or raise an error.
---
--- @param path string path to the file.
--- @param content string content to be written.
function ns.writeFile(path, content)
    local dir = ns.parent(path)
    if not filesystem.exists(dir) then
        error(string.format("failed writing file %s: no directory named %s", path, dir))
    end
    local fd, err = filesystem.open(path, "w")
    if not fd then
        error(string.format("failed writing file %s: %s", path, err or "unknown error"))
    end
    local _ <close> = defer.defer(fd.close, fd)

    fd:write(content)
end

--- Copy file by reading it and then writing it to a new location.
---
--- @param from string path to the source file.
--- @param to string path to the destination file.
function ns.copyFile(from, to)
    from = filesystem.path(1, from)
    to = filesystem.path(1, to)
    if to ~= from then
        ns.writeFile(to, ns.readFile(from))
    end
end

--- Get parent directory of the given path.
---
--- @param path string a filesystem path.
--- @return string parent directory of ``path``.
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
