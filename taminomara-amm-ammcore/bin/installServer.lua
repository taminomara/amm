local pkg = require "ammcore/pkg/index"
local eepromTemplate = require "ammcore/templates/eeprom"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"
local bootloader        = require "ammcore/bootloader"

pkg.checkAndUpdate()

print(eepromTemplate.formatServerEeprom("ammcore/bin/server"))
computer.setEEPROM(
    eepromTemplate.formatServerEeprom("ammcore/bin/server")
)

filesystemHelpers.writeFile(
    filesystem.path(assert(bootloader.getSrvRoot()), "needsServerInit"),
    ""
)

print("AMM server successfully installed.")

computer.reset()
