--- This code was downloaded from `https://taminomara.github.io/amm/bootstrap.lua`.
--- It contains AMM package manager for FixIt Networks.

--- Contains all files of the `ammcore` package.
--- @type table<string, string>
--- @diagnostic disable-next-line: assign-type-mismatch
local ammcoreCode = [[{ modules }]]

local api = {}

--- @param config ammcore.bootloader.BootloaderConfig
function api.main(config)
    assert(filesystem.initFileSystem("/dev"), "can't init filesystem at /dev")

    if not config.driveId then
        config.driveId = filesystem.children("/dev")[1]
        if not config.driveId then
            error("AMM needs a hard drive to install local files")
        end
    elseif type(config.driveId) ~= "string" then
        error(string.format("config.driveId has invalid value %s", config.devRoot))
    end
    if not filesystem.exists(filesystem.path("/dev", config.driveId --[[@as string]])) then
        error(string.format("no hard drive with id %s", config.driveId))
    end

    config.mountPoint = config.mountPoint or "/"
    if type(config.mountPoint) ~= "string" then
        error(string.format("config.devRoot has invalid value %s", config.devRoot))
    end
    do
        local ok, err = filesystem.mount(filesystem.path("/dev", config.driveId --[[@as string]]), config.mountPoint)
        if not ok then
            error(string.format(
                "can't mount drive %s to %s: %s",
                config.driveId, config.mountPoint, err or "unknown error")
            )
        end
    end

    config.devRoot = config.devRoot or "/"
    if type(config.devRoot) ~= "string" then
        error(string.format("config.devRoot has invalid value %s", config.devRoot))
    elseif not filesystem.exists(config.devRoot) then
        local ok, err = filesystem.createDir(config.devRoot, true)
        if not ok then
            error(string.format("can't create config.devRoot %s: %s", config.devRoot, err or "unknown error"))
        end
    elseif not filesystem.isDir(config.devRoot) then
        error(string.format("config.devRoot is not a directory: %s", config.devRoot))
    end

    config.srvRoot = config.srvRoot or "/.amm"
    if type(config.srvRoot) ~= "string" then
        error(string.format("config.srvRoot has invalid value %s", config.srvRoot))
    elseif not filesystem.exists(config.srvRoot) then
        local ok, err = filesystem.createDir(config.srvRoot, true)
        if not ok then
            error(string.format("can't create config.srvRoot %s: %s", config.srvRoot, err or "unknown error"))
        end
    elseif not filesystem.isDir(config.srvRoot) then
        error(string.format("config.srvRoot is not a directory: %s", config.srvRoot))
    end

    ---@diagnostic disable-next-line: inject-field
    config.eepromVersion = "bootstrap"

    local code, realPath = assert(
        ammcoreCode["bootloader.lua"],
        "this AMM distribution is broken: can't find ammcore.bootloader"
    ), "bootstrap://bootloader.lua"

    local codeFn, err = load(code, "@" .. realPath, "bt", _ENV)
    if not codeFn then
        error(string.format("failed parsing %s: %s", realPath, err))
    end

    -- Import loader code.
    local bootloader = codeFn() --- @module "ammcore.bootloader"

    -- Run loader.
    return bootloader.main(config, ammcoreCode)
end

return api
