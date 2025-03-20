local fsh = require "ammcore._util.fsh"
local json = require "ammcore._contrib.json"
local version = require "ammcore.pkg.version"

--- Parser for ``.ammpackage.json``.
---
--- !doctype module
--- @class ammcore.pkg.packageJson
local ns = {}

--- Data parsed from ``.ammpackage.json``.
---
--- @class ammcore.pkg.packageJson.PackageJson
--- @field name string package name.
--- @field version string package version.
--- @field description? string short package description.
--- @field author? string author of the package.
--- @field authors? string[] authors of the package, if there are more than one.
--- @field maintainer? string maintainer of the package.
--- @field maintainers? string[] maintainers of the package, if there are more than one.
--- @field license? string license type.
--- @field urls? table<string, string> links to pages related to the package.
--- @field requirements? table<string, string> list of production requirements.
--- @field devRequirements? table<string, string> list of development requirements.
--- @field private _buildScript? string script that will run during package build.

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
    _buildScript = "string?",
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

--- Read ``ammpackage.json`` from file.
---
--- @param path string path to an ``ammpackage.json`` file.
--- @return ammcore.pkg.version.Version version parsed package version.
--- @return table<string, ammcore.pkg.version.VersionSpec> requirements parsed production requirements.
--- @return table<string, ammcore.pkg.version.VersionSpec> devRequirements parsed development requirements.
--- @return ammcore.pkg.packageJson.PackageJson packageJson raw package data, verified and prepared.
function ns.parseFromFile(path)
    return ns.parseFromString(fsh.readFile(path), path)
end

--- Read `ammpackage.json` from json string.
---
--- @param metadataTxt string a json string.
--- @param path string where this string comes from, needed for error messages.
--- @return ammcore.pkg.version.Version version parsed package version.
--- @return table<string, ammcore.pkg.version.VersionSpec> requirements parsed production requirements.
--- @return table<string, ammcore.pkg.version.VersionSpec> devRequirements parsed development requirements.
--- @return ammcore.pkg.packageJson.PackageJson packageJson raw package data, verified and prepared.
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
--- @param metadata any parsed json data.
--- @param path string where this data comes from, needed for error messages.
--- @return ammcore.pkg.version.Version version parsed package version.
--- @return table<string, ammcore.pkg.version.VersionSpec> requirements parsed production requirements.
--- @return table<string, ammcore.pkg.version.VersionSpec> devRequirements parsed development requirements.
--- @return ammcore.pkg.packageJson.PackageJson packageJson raw package data, verified and prepared.
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
                    error(
                        string.format("unable to parse %s: requirement %s has invalid version %s: %s", path, k, v, err),
                        0)
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
                    error(
                        string.format("unable to parse %s: dev requirement %s has invalid version %s: %s", path, k, v,
                            err),
                        0)
                end
            end
            devRequirements[k] = spec
        end
    end

    return ver, requirements, devRequirements, metadata
end

return ns
