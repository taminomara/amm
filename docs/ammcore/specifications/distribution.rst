

When downloaded from GitHub, AMM core package always consists
of a single file, ``_bootstrap.lua``. This file contains a table
with code of all lua files in the AMM package. When loaded, it exports
a single function called ``main`` with interface
identical to `ammcore.bootloader.main`.

The latest version of bootstrap can also be found at
https://taminomara.github.io/amm/bootstrap.lua. This link can be used
in EEPROM to quickly fetch the core code in order to get access
to the packaging facilities and install AMM locally.
