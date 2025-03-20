local class = require "ammcore.class"
local server = require "ammcore.server"
local fsh = require "ammcore._util.fsh"
local json = require "ammcore._contrib.json"
local bootloader = require "ammcore.bootloader"

--- Implements API for local code server.
---
--- !doctype module
--- @class ammcore.server.localApi
local ns = {}

--- Implements API handle that uses `ammcore.pkg` to find packages
--- on the local hard drive.
---
--- @class ammcore.server.localApi.ServerApi: ammcore.server.ServerApi
ns.ServerApi = class.create("ServerApi", server.ServerApi)

--- @param packages ammcore.pkg.providers.local.LocalPackageVersion[]
--- @param coreModuleResolver fun(path: string[]): code: string | nil, realPath: string | nil
---
--- @generic T: ammcore.server.localApi.ServerApi
--- @param self T
--- @return T
function ns.ServerApi:New(packages, coreModuleResolver)
    self = server.ServerApi.New(self)

    --- List of locally installed packages. This list is used
    --- to resolve required modules.
    ---
    --- !doc const
    --- @type table<string, ammcore.pkg.providers.local.LocalPackageVersion>
    self.packages = {}
    for _, pkg in ipairs(packages) do
        self.packages[pkg.name] = self.packages[pkg.name] or pkg
    end

    --- @private
    --- @type fun(path: string[]): code: string | nil, realPath: string | nil
    self._coreModuleResolver = coreModuleResolver

    --- @private
    --- @type string?
    self._prebuiltCode = nil

    return self
end

function ns.ServerApi:lsPkg()
    return self.packages
end

function ns.ServerApi:getCode(path)
    if type(path) == "string" then
        path = { path }
    end

    local code, realPath = self._coreModuleResolver(path)
    if code then
        return code, realPath
    end

    for _, candidate in ipairs(path) do
        candidate = filesystem.path(2, candidate)

        -- Locate package.
        local pkgName, moduleName = candidate:match("^([^/]*)/(.*)$")

        if not pkgName or pkgName:len() == 0 then
            goto continue
        end

        local pkg = self.packages["taminomara-amm-" .. pkgName] or self.packages[pkgName]
        if not pkg then
            goto continue
        end

        local realPath = filesystem.path(pkg.packageRoot, moduleName)
        if filesystem.exists(realPath) and filesystem.isFile(realPath) then
            return fsh.readFile(realPath), realPath
        end

        ::continue::
    end
end

function ns.ServerApi:getAmmCoreVersion()
    local pkg = assert(self.packages["taminomara-amm-ammcore"], "can't find ammcore package")
    return pkg.version
end

function ns.ServerApi:getAmmCoreCode()
    local pkg = assert(self.packages["taminomara-amm-ammcore"], "can't find ammcore package")
    if not self._prebuiltCode then
        self._prebuiltCode = pkg:build()
    end
    return pkg.version, self._prebuiltCode
end

return ns
