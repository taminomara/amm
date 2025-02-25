build:copyDir(".github", "serverData/.github", "")
build:copyDir(".vscode", "serverData/.vscode", "")
build:copyFile(".gitignore", "serverData/.gitignore")
build:addFile("serverData/README.md", "See taminomara.github.io/amm for development documentation")
