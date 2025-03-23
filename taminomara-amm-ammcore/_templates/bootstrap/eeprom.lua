local config = {
    --- Which program to run after the system is fully booted.
    prog = [[{ prog }]],
    -- prog = ".help",  -- Print help and exit.

    --- Where to find installed AMM packages.
    target = [[{ target }]],
--[[{ configExtras }]]}

-- BEGIN AMM INIT --
config.mountPoint = filesystem.path(1, config.mountPoint or [[{ defaultMountPoint }]])
config.devRoot = filesystem.path(1, config.devRoot or [[{ defaultDevRoot }]])
config.srvRoot = filesystem.path(1, config.srvRoot or [[{ defaultSrvRoot }]])
config.eepromVersion = 1; filesystem.initFileSystem("dev/")
if not config.driveId then error("config.driveId is required")
elseif not filesystem.exists("dev/" .. config.driveId) then error("no hard drive with id " .. config.driveId)
else assert(filesystem.mount("dev/" .. config.driveId, config.mountPoint)) end
do  local root;
    for _, candidate in ipairs({
            filesystem.path(config.devRoot, "taminomara-amm-ammcore"),
            filesystem.path(config.srvRoot, "lib/taminomara-amm-ammcore")}) do
        if filesystem.exists(candidate .. "/.ammpackage.json") then root = candidate; break end end
    if root then filesystem.doFile(root .. "/bootloader.lua").main(config, root)
    else error("can't find AMM bootloader") end end
-- END AMM INIT --
