Computer startup procedure
==========================

Each computer that runs AMM code has the same startup procedure:

1. EEPROM creates a config for AMM bootloader (see
  `ammcore.bootloader.BootloaderConfig`), mounts the hard drive
  that contains `~ammcore.bootloader.BootloaderConfig.srvRoot`.

2. EEPROM obtains and loads contents of the bootstrap script.

   If the computer is being provisioned for the first time,
   the bootstrap script is downloaded from
   https://taminomara.github.io/amm/bootstrap.lua.

   If the computer is provisioned using another computer as a code server,
   the bootstrap script is fetched from said code server.

   Otherwise, the bootstrap script is always located in
   ``{config.srvRoot}/lib/taminomara-amm-ammcore/_bootstrap.lua``
   (see `~ammcore.bootloader.BootloaderConfig.srvRoot`).

3. EEPROM runs the bootstrap script and hands control to its ``main`` function.

4. Bootstrap script checks config values, sets their defaults,
   and uses its code table to load the first module, `ammcore.bootloader`.

5. Bootstrap script hands control to `ammcore.bootloader.main`.

6. Depending on the value of `~ammcore.bootloader.BootloaderConfig.target`,
   bootloader creates an instance of a code server API client,
   either `~ammcore.server.localApi` or `~ammcore.server.remoteApi`.

   1. If `~ammcore.server.remoteApi` is used, bootloader checks version of AMM core
      running on the remote code server.

      If this version doesn't match the version of the bootstrap script stored locally,
      the bootstrap script is updated and the computer is reset.

   2. If `~ammcore.server.localApi` is used, bootloader gathers information about
      locally installed packages and uses it to set the global `require` function.

7. Finally, bootloader requires a module specified
   in `~ammcore.bootloader.BootloaderConfig.prog`.

8. After this module returns, the control is given back to EEPROM.
