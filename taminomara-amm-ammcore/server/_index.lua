--- @namespace ammcore.server

local class = require "ammcore.class"

--- Code server API.
local ns = {}

--- Abstract code server API implementation.
---
--- Server API bound to a concrete server should be requested
--- from `ammcore.bootloader.getCodeServerApi`.
---
--- @class ServerApi: ammcore.class.Base
ns.ServerApi = class.create("ServerApi")

--- List all packages installed on the server.
---
--- !doc abstract
--- @return table<string, ammcore.pkg.package.PackageVersion> packages installed on the server.
function ns.ServerApi:lsPkg()
    error("not implemented")
end

--- Find and return a file by its path.
---
--- If given an array of strings, then the first found file is returned.
--- For example, ``server:getCode({ "a/b/_index.lua", "a/b.lua" })`` will try
--- `"a/b/_index.lua"` first, then `"a/b.lua"`. It will return contents
--- of the first file that exists.
---
--- !doc abstract
--- @param path string|string[] file path, including its extension.
--- @return string? code module code.
--- @return string? realPath actual path to the `.lua` file that contains the code.
function ns.ServerApi:getCode(path)
    error("not implemented")
end

--- Get version of the AMM core.
---
--- !doc abstract
--- @return ammcore.pkg.version.Version
function ns.ServerApi:getAmmCoreVersion()
    error("not implemented")
end

--- Get code of the core module.
---
--- !doc abstract
--- @return ammcore.pkg.version.Version version ammcore version.
--- @return string code ammcore code.
function ns.ServerApi:getAmmCoreCode()
    error("not implemented")
end

return ns
