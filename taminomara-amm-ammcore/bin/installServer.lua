local pkg = require "ammcore/pkg/index"
local eepromTemplate = require "ammcore/templates/eeprom"
local serverTemplate = require "ammcore/templates/server"

pkg.checkAndUpdate()
serverTemplate.writeServerTemplate()
computer.setEEPROM(eepromTemplate.formatServerEeprom())
print("AMM server successfully installed.")
computer.reset()
