--- This code will fetch AMM package loader over the internet and setup this computer.

local config = {
    --- This option will configure this computer to use a code server
    --- to find all required packages.
    target = "net",

    --- This option will install packages from github and configure this computer
    --- to become a code server.
    -- target = "drive",
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
local fn, err = load(code, "@https://taminomara.github.io/amm/bootstrap.lua")
if not fn then
    error(string.format("failed parsing AMM loader: %s", err))
end

-- Run the loader.
config.prog = ".provision"
fn().main(config)
