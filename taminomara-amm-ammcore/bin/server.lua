local serverTemplate = require "ammcore/templates/server"
local bootloader     = require "ammcore/bootloader"

do
    local cookiePath = filesystem.path(assert(bootloader.getSrvRoot()), "needsServerInit")
    if filesystem.exists(cookiePath) then
        serverTemplate.writeServerTemplate()
        filesystem.remove(cookiePath, false)
    end
end
