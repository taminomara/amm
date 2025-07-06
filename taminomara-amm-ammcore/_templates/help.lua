--- @namespace ammcore._templates.help

local bootloader = require "ammcore.bootloader"
local json       = require "ammcore._contrib.json"

--- Writes locator script.
local ns = {}

function ns.formatHelp()
    local helpTemplate = bootloader.findModuleCode("ammcore/_templates/bootstrap/help.json")
    assert(helpTemplate, "can't find the help message template")

    local result = ""
    local sectionSep = ""

    for _, section in ipairs(json.decode(helpTemplate)) do
        result = result .. sectionSep .. section.title .. "\n"

        if section.text then
            result = result .. "\n"
            for _, line in ipairs(section.text) do
                result = result .. "  " .. line .. "\n"
            end
        end

        if section.options then
            for _, option in ipairs(section.options) do
                result = result .. "\n"
                local prefix
                if option.title:len() <= 13 then
                    result = result .. string.format("  %-15s", option.title)
                    prefix = ""
                else
                    result = result .. "  " .. option.title .. "\n"
                    prefix = "                 "
                end
                for _, line in ipairs(option.text) do
                    result = result .. prefix .. line .. "\n"
                    prefix = "                 "
                end
            end
        end

        if section.textAfter then
            result = result .. "\n"
            for _, line in ipairs(section.textAfter) do
                result = result .. "  " .. line .. "\n"
            end
        end

        sectionSep = "\n"
    end

    return result
end

return ns
