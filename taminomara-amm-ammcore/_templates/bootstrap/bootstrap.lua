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
--- @return string?
local function loader(path)
    local realPath
    if path:match("^ammcore/") then
        realPath = path:gsub("^ammcore/", "") .. ".lua"
    elseif path:match("^taminomara-amm-ammcore/") then
        realPath = path:gsub("^taminomara-amm-ammcore/", "") .. ".lua"
    else
        return nil
    end
    return moduleCode[realPath], "bootstrap://" .. realPath
end

local api = {}

function api.init(config)
    config = config or {}
    config.devRoot = config.devRoot or "/"
    config.srvRoot = config.srvRoot or "/.amm"
    config.driveMountPoint = config.driveMountPoint or "/"
    config.netCodeServerPort = config.netCodeServerPort or 0x1CD

    -- Find a drive to install AMM.
    filesystem.initFileSystem("/dev")
    local devices = filesystem.children("/dev")
    if #devices == 0 then
        error("no hard drive detected")
    end
    config.driveId = config.driveId or devices[1]
    filesystem.mount(filesystem.path("/dev", config.driveId), config.driveMountPoint)

    local path = "ammcore/bootloader"

    -- Get loader code.
    local code, realPath = loader(path)
    if not code then
        error(string.format("no module named %s", path))
    end

    -- Compile loader code.
    local codeFn, err = load(code, "@" .. realPath, "t", _ENV)
    if not codeFn then
        error(string.format("failed parsing %s: %s", path, err))
    end

    -- Import loader code.
    local bootloaderApi = codeFn()

    -- Run loader.
    config.target = loader
    bootloaderApi.init(config)
end

return api
