Implements packaging system, import system and universal bootloader.

This is, in essence, an implementation of a package manager for FicsIt Networks.
It can be thought of as consisting of several components:

1. _EEPROM_ is the first thing that's executed when a computer starts.
   Its purpose is to set up global configuration values such as `AMM_BOOT_CONFIG`,
   locate and initialize the _bootloader_, and start the main file
   by calling the _entrypoint_.

   If AMM code is stored locally, the _bootloader_ is located on a hard drive,
   so _EEPROM_ just loads it and runs it.

   If AMM code is served over a FicsIt network, the _bootloader_ is downloaded
   from a _code server_.

   If this is the first time you init AMM in a save, and there is no _code server_
   or a hard drive with an AMM installation, the _bootloader_ is downloaded from
   the internet via the _bootstrap_ script.

2. _Bootstrap_ script is located at https://taminomara.github.io/amm/bootstrap.lua.

   This script contains the latest version of `ammcore` package. By downloading
   it via an internet card and interacting with its API you can create
   an AMM installation on a hard drive.

3. _Bootloader_ implements the `require` function. Depending on `AMM_BOOT_CONFIG`,
   the `require` function can fetch files from a hard drive, over a network,
   or from a bundled package that was included in the bootstrap script.

4. _Entrypoint_ is located in `ammcore.bin.main`. It is a script that locates
   and runs the main file.

5. _Code server_ is a component that serves packages and `lua` files
   to other computers. It implements the _AMM boot_ protocol (similar to _netboot_
   used by other FIN frameworks), provides the central settings storage,
   as well as the single point for updating installed packages.

6. _Packaging system_ is what downloads and installs AMM packages.
   Users interact with it primarily through the _code server_ API or
   through `ammcore.bin.installPackages`.

7. _AMM package_ is, well, a package, that can be downloaded from github
  and installed using the _packaging system_.

  Packages consist of `lua` files and the `.ammpackage.json` file.
  The later contains package dependencies, version, and other information.
