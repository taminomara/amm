--- This code runs when AMM is initialized.
--- It is safe to declare global constants here: they'll always be defined.

local _readonly = { __newindex = function() error("This value is read-only", 2) end }

--- Use `amm.util.fin.makeReadOnly` instead.
---
--- This function is declared here because some facilities (namely `amm._version`
--- and `amm._entrypoint`) use it, but they should not include files from `util`.
---
--- @generic T: table
--- @param t T
--- @return T
function __AMM_MAKE_READONLY(t)
    return setmetatable(t, _readonly)
end

--- Current version of the AMM package.
---
--- @type string
AMM_VERSION   = (require "amm/_version").version

--- Special address for broadcasting messages.
---
--- @type string
AMM_BROADCAST = "_broadcast_"

--- Address of this computer.
---
--- @type string
AMM_LOOPBACK  = "_loopback_"

do
    local networkCard = computer.getPCIDevices(classes.NetworkCard)[1] --[[ @as NetworkCard? ]]
    if networkCard then
        AMM_LOOPBACK = networkCard.id
    end
end

--- Port for AMM messages.
---
--- @type integer
AMM_PORT      = 0x1CC
