--- @param builder ammcore.pkg.builder.PackageBuilder
return function(builder)
    builder:copyDir("server_template", "_templates/server_template")
    builder:addDirectoryIndex("_templates/bootstrap/server.json", "_templates/server_template", true)
end
