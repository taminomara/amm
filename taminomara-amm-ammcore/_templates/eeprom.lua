local bootloader = require "ammcore.bootloader"
local log = require "ammcore.log"

local logger = log.getLogger()

--- Allows setting up server EEPROM.
local ns = {}

--- Generate standard EEPROM for an AMM computer.
---
--- @param prog string?
function ns.formatEeprom(prog)
    local eepromTemplate = bootloader.findModuleCode("ammcore/_templates/bootstrap/eeprom.lua")
    assert(eepromTemplate, "can't find the EEPROM template")

    local config = bootloader.getBootloaderConfig()

    if not prog and config.target == "drive" then
        prog = ".server"
    end

    local vars = {
        prog = prog,
        target = config.target,
        defaultMountPoint = "/",
        defaultDevRoot = "/",
        defaultSrvRoot = "/.amm",
        defaultNetCodeServerPort = 0x1CD,
    }

    local configExtras = ""

    local function addConfigExtra(name, comment, value)
        configExtras = configExtras .. "\n    --- " .. comment:gsub("\n", "    --- ")
        configExtras = configExtras .. string.format("\n    %s = %q,\n", name, value)
    end

    if config.packages and next(config.packages) then
        configExtras = configExtras .. "\n    --- Additional packages that the server should install."
        configExtras = configExtras .. "\n    packages = {\n"
        for _, package in ipairs(config.packages) do
            configExtras = configExtras .. string.format("        %q,\n", package)
        end
        configExtras = configExtras .. "    },\n"
    end

    addConfigExtra(
        "driveId",
        "Id of a hard drive with AMM files.",
        config.driveId
    )
    if config.mountPoint and config.mountPoint ~= vars.defaultMountPoint then
        addConfigExtra(
            "mountPoint",
            "Directory where hard drive will be mounted.",
            config.mountPoint
        )
    end
    if config.devRoot and config.devRoot ~= vars.defaultDevRoot then
        addConfigExtra(
            "devRoot",
            "Directory with user code",
            config.devRoot
        )
    end
    if config.srvRoot and config.srvRoot ~= vars.defaultSrvRoot then
        addConfigExtra(
            "srvRoot",
            "Directory with internal AMM files.",
            config.srvRoot
        )
    end
    if config.bootPort and config.bootPort ~= vars.defaultNetCodeServerPort then
        addConfigExtra(
            "bootPort",
            "Port of the code server.",
            config.bootPort
        )
    end

    logger:trace("Replacing EEPROM with the standard template for '%s' target", config.target)

    return eepromTemplate
        :gsub("%-%-%[%[{%s*configExtras%s*}%]%]", configExtras)
        :gsub("%[%[{%s*([%w]*)%s*}%]%]", function(key) return string.format("%q", vars[key]) end)
end

return ns
