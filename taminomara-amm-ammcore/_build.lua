builder:copyDir(".vscode", "_templates/server/.vscode", "*")
builder:copyFile(".gitignore", "_templates/server/.gitignore")
for _, location in ipairs({"server", "package"}) do
    local indexFile = "return {"
    for name, _ in pairs(builder:getCode()) do
        local path = name:match("^_templates/" .. location .. "/(.*)$")
        if path then
            indexFile = indexFile .. string.format("%q,", path)
        end
    end
    indexFile = indexFile .. "}"
    builder:addFile("templates/" .. location .. "Index.lua", indexFile, true)
end
