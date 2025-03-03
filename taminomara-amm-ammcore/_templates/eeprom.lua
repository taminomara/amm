local bootloader = require "ammcore.bootloader"
local log = require "ammcore.util.log"

local logger = log.Logger:New()

--- Allows setting up server EEPROM.
local ns = {}

--- Generate standard EEPROM for an AMM computer.
---
--- @param prog string
function ns.formatServerEeprom(prog)
    local eepromTemplate = bootloader.findModuleCode("ammcore/_templates/bootstrap/eeprom.lua")
    assert(eepromTemplate, "can't find the EEPROM template")

    local config = bootloader.getBootloaderConfig()

    local vars = {
        prog = prog,
        target = config.target == "bootstrap" and "drive" or config.target,
        defaultDriveMountPoint = "/",
        defaultDevRoot = "/",
        defaultSrvRoot = "/.amm",
        defaultNetCodeServerPort = 0x1CD,
    }

    local configExtras = ""

    local function addConfigExtra(name, comment, value)
        configExtras = configExtras .. "\n    --- " .. comment:gsub("\n", "    --- ")
        configExtras = configExtras .. string.format("\n    %s = %q,\n", name, value)
    end

    if config.target == "drive" or config.target == "bootstrap" then
        addConfigExtra(
            "driveId",
            "Id of the hard drive that contains the AMM installation.",
            config.driveId
        )
        if config.packages then
            configExtras = configExtras .. "\n    --- Additional packages that the server should install."
            configExtras = configExtras .. "\n    packages = {\n"
            for _, package in ipairs(config.packages) do
                configExtras = configExtras .. string.format("        %q,\n", package)
            end
            configExtras = configExtras .. "    },\n"
        end
        if config.driveMountPoint ~= vars.defaultDriveMountPoint then
            addConfigExtra(
                "driveMountPoint",
                "Where to mount the hard drive.",
                config.driveMountPoint
            )
        end
        if config.devRoot ~= vars.defaultDevRoot then
            addConfigExtra(
                "devRoot",
                "Directory with AMM packages installed in development mode.",
                config.devRoot
            )
        end
        if config.srvRoot ~= vars.defaultSrvRoot then
            addConfigExtra(
                "srvRoot",
                "Directory with AMM packages and internal files.",
                config.srvRoot
            )
        end
    elseif config.target == "net" or config.target == "bootstrap" then
        if config.netCodeServerAddr then
            addConfigExtra(
                "netCodeServerAddr",
                "Address of the code server. By default, AMM discovers code servers via a broadcast.",
                config.netCodeServerAddr
            )
        end
        if config.netCodeServerPort ~= vars.defaultNetCodeServerPort then
            addConfigExtra(
                "netCodeServerPort",
                "Port of the code server.",
                config.netCodeServerPort
            )
        end
    end

    logger:trace("Replacing EEPROM with the standard template for '%s' bootloader", config.target)

    return eepromTemplate
        :gsub("%-%-%[%[{%s*configExtras%s*}%]%]", configExtras)
        :gsub("%[%[{%s*([%w]*)%s*}%]%]", function(key) return string.format("%q", vars[key]) end)
end

return ns
