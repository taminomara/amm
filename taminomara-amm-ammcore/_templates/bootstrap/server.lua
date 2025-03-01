--- This code will fetch AMM package loader over the internet and setup this computer.

local config = {
    --- Packages to install in addition to the loader system.
    packages = {
        -- "taminomara-amm-amm ~= 1.0",
    }
}

-- Implementation

-- Find an internet card.
local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[ @as FINInternetCard? ]]
if not internetCard then
    error("AMM loader requires an internet card to download code")
end

-- Download bootstrap code.
local res, code = internetCard:request("https://taminomara.github.io/amm/bootstrap.lua", "GET", ""):await()
if not res then
    error("failed fetching AMM loader: couldn't connect to server")
elseif res ~= 200 then
    error(string.format("failed fetching AMM loader: HTTP error %s", res))
end

-- Compile bootstrap code.
local fn, err = load(code, "<bootstrap>")
if not fn then
    error(string.format("failed parsing AMM loader: %s", err))
end

-- Init loader.
local bootloaderApi = fn()
bootloaderApi.init(config)

-- Run the program.
require("ammcore.bin.installServer")
