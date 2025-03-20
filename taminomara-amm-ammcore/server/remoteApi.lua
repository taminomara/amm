local class = require "ammcore.class"
local json = require "ammcore._contrib.json"
local packageJson = require "ammcore.pkg.packageJson"
local package = require "ammcore.pkg.package"
local server = require "ammcore.server"
local version= require "ammcore.pkg.version"

--- Implements API for remote code server.
---
--- !doctype module
--- @class ammcore.server.remoteApi
local ns = {}

--- Package version that was fetched from code server.
---
--- This class does not implement `build`, it only provides data about the package.
---
--- !doc private
--- @class ammcore.server.remoteApi.CodeServerPackageVersion: ammcore.pkg.package.PackageVersion
local CodeServerPackageVersion = class.create("CodeServerPackageVersion", package.PackageVersion)

--- @param metadataRaw ammcore.pkg.packageJson.PackageJson
---
--- @generic T: ammcore.server.remoteApi.CodeServerPackageVersion
--- @param self T
--- @return T
function CodeServerPackageVersion:New(metadataRaw)
    local version, requirements, devResuirements, metadata = packageJson.parse(
        metadataRaw, "code server response"
    )

    self = package.PackageVersion.New(self, metadata.name, version)

    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self.requirements = requirements

    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self.devRequirements = devResuirements

    --- @type ammcore.pkg.packageJson.PackageJson
    self.data = metadata

    return self
end

function CodeServerPackageVersion:getMetadata()
    return self.data
end

function CodeServerPackageVersion:getRequirements()
    return self.requirements
end

function CodeServerPackageVersion:getDevRequirements()
    return self.devRequirements
end

--- Implements API handle that uses ammboot protocol to find packages
--- on another computer.
---
--- @class ammcore.server.remoteApi.ServerApi: ammcore.server.ServerApi
ns.ServerApi = class.create("ServerApi", server.ServerApi)

--- @param networkCard NetworkCard
--- @param addr string
--- @param port integer
--- @param timeout integer?
--- @param coreModuleResolver fun(path: string[]): code: string | nil, realPath: string | nil
---
--- @generic T: ammcore.server.remoteApi.ServerApi
--- @param self T
--- @return T
function ns.ServerApi:New(networkCard, addr, port, timeout, coreModuleResolver)
    self = server.ServerApi.New(self)

    --- Network card used to send requests to and receive responses from a code server.
    ---
    --- !doctype const
    --- @type NetworkCard
    self.networkCard = networkCard

    --- Code server address.
    ---
    --- !doctype const
    --- @type string
    self.addr = addr

    --- Code server port.
    ---
    --- !doctype const
    --- @type integer
    self.port = port

    --- Request timeout in millisecinds. Default is ``500``.
    ---
    --- @type integer
    self.timeout = timeout or 2000

    --- @private
    --- @type fun(path: string[]): code: string | nil, realPath: string | nil
    self._coreModuleResolver = coreModuleResolver

    event.listen(self.networkCard)

    return self
end

--- @param message string
--- @param deadline integer
--- @return string name
--- @return Object networkCard
--- @return string sender
--- @return integer port
--- @return string receivedMessage
--- @return any ...
function ns.ServerApi:_waitResponse(message, deadline)
    while true do
        local now = computer.millis()
        if now > deadline then
            error("timeout while waiting for response from a code server")
        end

        local e = { event.pull(now - deadline) }
        local name, _, sender, port, receivedMessage = table.unpack(e)
        if
            name == "NetworkMessage"
            and sender == self.addr
            and port == self.port
            and receivedMessage == message
        then
            return table.unpack(e) --[[ @as any ]]
        end
    end
end

function ns.ServerApi:lsPkg()
    self.networkCard:send(self.addr, self.port, "lsPkg")
    local deadline = computer.millis() + self.timeout
    local _, _, _, _, _, pkgDataTxt = self:_waitResponse("rcvPkg", deadline)

    local result = {}
    for name, metadata in pairs(json.decode(pkgDataTxt)) do
        result[name] = CodeServerPackageVersion:New(metadata)
    end
    return result
end

function ns.ServerApi:getCode(path)
    if type(path) == "string" then
        path = { path }
    end

    local code, realPath = self._coreModuleResolver(path)
    if code then
        return code, realPath
    end

    local pathStr = table.concat(path, ":")
    self.networkCard:send(self.addr, self.port, "getCode", pathStr)
    local deadline = computer.millis() + self.timeout
    while true do
        local _, _, _, _, _, responseCandidates, code, realPath = self:_waitResponse(
            "rcvCode", deadline
        )
        if responseCandidates == pathStr then
            return code, realPath and ("ammboot://" .. realPath)
        end
    end
end

function ns.ServerApi:getAmmCoreVersion()
    self.networkCard:send(self.addr, self.port, "getAmmCoreVersion")
    local deadline = computer.millis() + self.timeout
    local _, _, _, _, _, verTxt = self:_waitResponse("rcvAmmCoreVersion", deadline)
    return version.parse(verTxt)
end

function ns.ServerApi:getAmmCoreCode()
    self.networkCard:send(self.addr, self.port, "getAmmCoreCode")
    local deadline = computer.millis() + self.timeout
    local _, _, _, _, _, verTxt, code = self:_waitResponse("rcvAmmCoreCode", deadline)
    return version.parse(verTxt), code
end

return ns
