Development environment
=======================

When you first install AMM, code server writes libraries to ``/.amm``,
and it also creates a development environment in the root directory of your hard drive.

Development environment includes common files like ``.gitignore``, ``.luarc.json``,
and others. Everything is set up so that you can open your hard drive's
root directory in your favorite IDE and start coding.

The only thing you'll need is to generate Lua annotations for FIN interface.
Here's a step-by-step guide.

1. Locate `directory with your save files`_.

   .. tab-set::
      :sync-group: os

      .. tab-item:: Windows
         :sync: windows

         On windows, save files are located in

         .. code-block:: text

            %LOCALAPPDATA%\FactoryGame\Saved\SaveGames\

      .. tab-item:: Linux
         :sync: linux

         On linux, save files are located in one of the following paths.

         - using Steam Play:

           .. code-block:: text

              ~/.local/share/Steam/steamapps/compatdata/526870/pfx/drive_c/users/steamuser/Local Settings/Application Data/FactoryGame/Saved/SaveGames/

         - using Steam:

           .. code-block:: text

              ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/526870/pfx/drive_c/users/steamuser/AppData/Local/FactoryGame/Saved/SaveGames/

         - using Steam (Debian Based Installation):

           .. code-block:: text

               ~/.steam/debian-installation/steamapps/compatdata/526870/pfx/drive_c/users/steamuser/Local Settings/Application Data/FactoryGame/Saved/SaveGames/

_directory with your save files: https://satisfactory.fandom.com/wiki/Save_files#Save_File_Location

2. Locate directory of your hard drive.

   In Satisfactory, check ID of your drive. Its contents will be located at

   .. code-block:: text

      {save directory}/Computers/{drive ID}

3. Export Lua annotations for FIN interface.

   In Satisfactory, open console by pressing tilde (``~``), the execute command
   ``FINGenLuaDoc``.

   This will generate a file named ``FINLuaDocumentation.lua`` in your save directory.

4. Move ``FINLuaDocumentation.lua`` into

   .. code-block:: text

      {save directory}/Computers/{drive ID}/.amm/lib

5. Open the root of your hard drive in an IDE or a text editor. You're all set!

It's time to create your first AMM package.
