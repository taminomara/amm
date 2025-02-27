--- This code will fetch AMM package loader over the internet and setup this computer.

--- Packages to install in addition to the loader system.
AMM_PACKAGES = {
    -- "taminomara-amm-amm ~= 1.0",
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
    error("Failed fetching AMM loader: couldn't connect to server")
elseif res ~= 200 then
    error("Failed fetching AMM loader: error " .. tostring(res))
end

-- Compile bootstrap code.
local fn, err = load(code, "<bootstrap>")
if not fn then
    error("Failed parsing AMM loader: " .. tostring(err))
end

-- Init loader.
local bootloaderApi = fn()
bootloaderApi.init()

-- Run the program.
require("ammcore/bin/installServer")
