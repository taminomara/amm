--- This code was downloaded from `https://taminomara.github.io/amm/bootstrap.lua`.
--- It contains AMM package manager for Fixit Networks.

--- Contains all files of the `ammcore` package.
--- @type table<string, string>
--- @diagnostic disable-next-line: assign-type-mismatch
local ammcoreCode = [[{ modules }]]

local api = {}

function api.main(config)
    local code, realPath = assert(
        ammcoreCode["bootloader.lua"],
        "this AMM distribution is broken: can't find ammcore.bootloader"
    ), "bootstrap://bootloader.lua"

    local codeFn, err = load(code, "@" .. realPath, "t", _ENV)
    if not codeFn then
        error(string.format("failed parsing %s: %s", realPath, err))
    end

    -- Import loader code.
    local bootloader = codeFn() --[[ @as ammcore.bootloader ]]

    -- Run loader.
    return bootloader.main(config, ammcoreCode)
end

return api
