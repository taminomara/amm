package = "loader"
version = "dev-1"
source = {
   url = "https://github.com/taminomara/amm"
}
dependencies = {
   "lua == 5.4",
   "luafilesystem >= 1.8, < 2",
   "http >= 0.4, < 1",
}
build = {
   type = "builtin",
   modules = {
      env = "env.lua"
   }
}
