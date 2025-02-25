local filesystemHelpers = require "ammcore/util/filesystemHelpers"
local json              = require "ammcore/contrib/json"
local version           = require "ammcore/pkg/version"
local package           = require "ammcore/pkg/packageVersion"

--- Parser for `.ammpackage.json`.
local ns                = {}

--- Read `ammpackage.json` from file.
---
--- @param path string
--- @return ammcore.pkg.version.Version, table<string, ammcore.pkg.version.VersionSpec>, table<string, ammcore.pkg.version.VersionSpec>
function ns.parseFromFile(path)
    local rawData = filesystemHelpers.readFile(path)
    local data
    do
        local ok, err = pcall(function() data = json.decode(rawData) end)
        if not ok then
            error(string.format("Unable to parse %s: %s", path, err))
        end
    end

    return ns.parse(data, path)
end

--- Read `ammpackage.json` from lua table.
---
--- @param data any
--- @param path string
--- @return ammcore.pkg.version.Version, table<string, ammcore.pkg.version.VersionSpec>, table<string, ammcore.pkg.version.VersionSpec>
function ns.parse(data, path)
    if type(data) ~= "table" then
        error(string.format("Unable to parse %s: package data should be an object", path))
    end

    local rawVersion = data.version
    if type(rawVersion) ~= "string" then
        error(string.format("Unable to parse %s: invalid package version %s", path, rawVersion))
    end
    local ver
    do
        local ok, err = pcall(function() ver = version.parse(rawVersion) end)
        if not ok then
            error(string.format("Unable to parse %s: invalid package version %s:", path, rawVersion, err))
        end
    end

    local requirements = {}
    do
        local rawRequirements = data.requirements
        if type(rawRequirements) ~= "nil" and type(rawRequirements) ~= "table" then
            error(string.format("Unable to parse %s: requirements should be an object", path))
        end
        for k, v in pairs(rawRequirements or {}) do
            if not type(k) == "string" then
                error(string.format("Unable to parse %s: invalid requirement %s", k))
            end
            if not type(v) == "string" then
                error(string.format("Unable to parse %s: requirement %s has invalid version %s", k, v))
            end
            local spec
            do
                local ok, err = pcall(function() spec = version.parseSpec(v) end)
                if not ok then
                    error(string.format("Unable to parse %s: requirement %s has invalid version %s: %s", k, v, err))
                end
            end
            requirements[k] = spec
        end
    end

    local devRequirements = {}
    do
        local rawRequirements = data.devRequirements
        if type(rawRequirements) ~= "nil" and type(rawRequirements) ~= "table" then
            error(string.format("Unable to parse %s: devRequirements should be an object", path))
        end
        for k, v in pairs(rawRequirements or {}) do
            if not type(k) == "string" then
                error(string.format("Unable to parse %s: invalid dev requirement %s", k))
            end
            if not type(v) == "string" then
                error(string.format("Unable to parse %s: dev requirement %s has invalid version %s", k, v))
            end
            local spec
            do
                local ok, err = pcall(function() spec = version.parseSpec(v) end)
                if not ok then
                    error(string.format("Unable to parse %s: dev requirement %s has invalid version %s: %s", k, v,
                        err))
                end
            end
            devRequirements[k] = spec
        end
    end

    return ver, requirements, devRequirements
end

return ns
