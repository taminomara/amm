local _loader = require "ammcore/_loader"
local debugHelpers = require "ammcore/util/debugHelpers"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"

--- Allows setting up server EEPROM.
local ns = {}

function ns.formatServerEeprom()
    if _loader.getLoaderKind() ~= "drive" then
        error("Server templates only available with drive loader")
    end

    local file = debugHelpers.getFile()
    local dir = assert(file:match("^(.*)/[^/]*/[^/]*$"))
    local eepromTemplate = filesystemHelpers.readFile(filesystem.path(dir, "_templates/bootstrap/eeprom.lua"))

    local packagesTemplate = "{\n"
    if AMM_PACKAGES and #AMM_PACKAGES > 0 then
        for _, package in ipairs(AMM_PACKAGES) do
            packagesTemplate = packagesTemplate .. string.format("    %q\n", package)
        end
    else
        packagesTemplate = packagesTemplate .. "    -- \"taminomara-amm-amm ~= 1.0\",\n"
    end
    packagesTemplate = packagesTemplate .. "}"

    local vars = {
        packages = packagesTemplate,
        prog = string.format("%q", "ammcore/bin/server"),
        target = string.format("%q", "drive"),
        driveId = string.format("%q", AMM_BOOT_CONFIG.driveId),
    }

    return eepromTemplate:gsub("%[%[{%s*([%w]*)%s*}%]%]", vars)
end

return ns
