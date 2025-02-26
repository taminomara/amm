--- This code was downloaded from `https://taminomara.github.io/amm/bootstrap.lua`.
--- It contains AMM package manager for Fixit Networks.

--- Contains all files of the `ammcore` package.
--- @type table<string, string>
--- @diagnostic disable-next-line: assign-type-mismatch
local moduleCode = [[{ modules }]]

--- In-memory loader, looks up code in the `moduleCode` table.
---
--- @param path string
--- @return string?
local function loader(path)
    if path:match("^ammcore/") then
        return moduleCode[path:gsub("^ammcore/", "")]
    elseif path:match("^taminomara-amm-ammcore/") then
        return moduleCode[path:gsub("^taminomara-amm-ammcore/", "")]
    else
        return nil
    end
end

local api = {}

function api.init(config)
    config = config or {}

    -- Find a drive to install AMM.
    filesystem.initFileSystem("/dev")
    local devices = filesystem.children("/dev")
    if #devices == 0 then
        error("BootloaderError: no hard drive detected")
    end
    config.driveId = config.driveId or devices[1]

    local path = "ammcore/_loader.lua"

    -- Get loader code.
    local code = loader(path)
    if not code then
        error(string.format("ImportError: no module named %s", path))
    end

    -- Compile loader code.
    local codeFn, err = load(code, path, "bt", _ENV)
    if not codeFn then
        error(string.format("ImportError: failed to parse %s: %s", path, err))
    end

    -- Import loader code.
    local bootloaderApi = codeFn()

    -- Run loader.
    config.target = loader
    bootloaderApi.init(config)
end

return api
