local filesystemHelpers = require "ammcore.util.filesystemHelpers"
local json              = require "ammcore.contrib.json"
local version           = require "ammcore.pkg.version"

--- Parser for `.ammpackage.json`.
local ns                = {}

--- @class ammcore.pkg.ammPackageJson.AmmPackageJson
--- @field name string
--- @field version string
--- @field description? string
--- @field author? string
--- @field authors? table<number, string>
--- @field maintainer? string
--- @field maintainers? table<number, string>
--- @field license? string
--- @field urls? table<string, string>
--- @field requirements? table<string, string>
--- @field devRequirements? table<string, string>

--- Schema for `ammcore.pkg.ammPackageJson.AmmPackageJson`.
local schema = {
    name = "string",
    version = "string",
    description = "string?",
    author = "string?",
    authors = { _k = "number", _v = "string" },
    maintainer = "string?",
    maintainers = { _k = "number", _v = "string" },
    license = "string?",
    urls = { _k = "string", _v = "string" },
    requirements = { _k = "string", _v = "string" },
    devRequirements = { _k = "string", _v = "string" },
}

--- Checks that `data` matches `schema`, returns error or nil.
local function checkSchema(data, schema, path)
    if type(data) ~= "table" then
        return string.format("%s should be a table", path)
    end

    for k, v in pairs(data) do
        local kTy = schema["_k"]
        local vTy = schema[k] or schema["_v"]
        local kPath = path .. (path:len() > 0 and "." or "") .. tostring(k)
        if kTy and type(k) ~= kTy then
            return string.format("key %s should be a %s", kPath, kTy)
        end
        if vTy then
            if type(vTy) == "string" then
                vTy = vTy:match("^(.-)%??$")
                if type(v) ~= vTy then
                    return string.format("value %s should be a %s", kPath, vTy)
                end
            else
                local err = checkSchema(v, vTy, kPath)
                if err then
                    return err
                end
            end
        else
            return string.format("unknown key %s", kPath)
        end
    end

    for k, v in pairs(schema) do
        if k ~= "_k" and k ~= "_v" and type(v) == "string" then
            local isOpt = v:match("%?$")
            if not data[k] and not isOpt then
                local kPath = path .. (path:len() > 0 and "." or "") .. tostring(k)
                return string.format("%s is required", kPath)
            end
        end
    end
end

--- Read `ammpackage.json` from file.
---
--- @param path string
--- @return ammcore.pkg.version.Version version
--- @return table<string, ammcore.pkg.version.VersionSpec> requirements
--- @return table<string, ammcore.pkg.version.VersionSpec> dev requirements
--- @return ammcore.pkg.ammPackageJson.AmmPackageJson raw package data
function ns.parseFromFile(path)
    return ns.parseFromString(filesystemHelpers.readFile(path), path)
end

--- Read `ammpackage.json` from json string.
---
--- @param metadataTxt string
--- @param path string
--- @return ammcore.pkg.version.Version version
--- @return table<string, ammcore.pkg.version.VersionSpec> requirements
--- @return table<string, ammcore.pkg.version.VersionSpec> dev requirements
--- @return ammcore.pkg.ammPackageJson.AmmPackageJson raw package data
function ns.parseFromString(metadataTxt, path)
    local metadata
    do
        local ok, err = pcall(function() metadata = json.decode(metadataTxt) end)
        if not ok then
            error(string.format("unable to parse %s: %s", path, err), 0)
        end
    end

    return ns.parse(metadata, path)
end

--- Read `ammpackage.json` from lua table.
---
--- @param metadata any
--- @param path string
--- @return ammcore.pkg.version.Version version
--- @return table<string, ammcore.pkg.version.VersionSpec> requirements
--- @return table<string, ammcore.pkg.version.VersionSpec> dev requirements
--- @return ammcore.pkg.ammPackageJson.AmmPackageJson raw package data
function ns.parse(metadata, path)
    local err = checkSchema(metadata, schema, "")
    if err then
        error(string.format("unable to parse %s: %s", path, err), 0)
    end

    local ver
    do
        local ok, err = pcall(function() ver = version.parse(metadata.version) end)
        if not ok then
            error(string.format("unable to parse %s: invalid package version %s:", path, metadata.version, err), 0)
        end
    end

    local requirements = {}
    do
        for k, v in pairs(metadata.requirements or {}) do
            local spec
            do
                local ok, err = pcall(function() spec = version.parseSpec(v) end)
                if not ok then
                    error(string.format("unable to parse %s: requirement %s has invalid version %s: %s", path, k, v, err), 0)
                end
            end
            requirements[k] = spec
        end
    end

    local devRequirements = {}
    do
        for k, v in pairs(metadata.devRequirements or {}) do
            local spec
            do
                local ok, err = pcall(function() spec = version.parseSpec(v) end)
                if not ok then
                    error(string.format("unable to parse %s: dev requirement %s has invalid version %s: %s", path, k, v, err), 0)
                end
            end
            devRequirements[k] = spec
        end
    end

    return ver, requirements, devRequirements, metadata
end

return ns
