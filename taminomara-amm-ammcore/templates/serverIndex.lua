--- In production, this file is generated automatically by '_build.lua'.

local debugHelpers = require "ammcore.util.debugHelpers"

local index = {}

do
    local function travel(root, pkgRoot)
        if filesystem.isDir(root) then
            for _, name in ipairs(filesystem.children(root)) do
                travel(filesystem.path(root, name), filesystem.path(pkgRoot, name))
            end
        elseif filesystem.isFile(root) then
            table.insert(index, pkgRoot)
        end
    end

    local file = debugHelpers.getFile()
    local dir = assert(file:match("^(.*)/[^/]*/[^/]*$"))
    local root = filesystem.path(dir, "_templates/server/")
    travel(root, "")
end

return index
