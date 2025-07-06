--- @namespace ammcore.pkg.packageName

--- Utilities for parsing package name.
local ns = {}

--- @param name string
--- @return boolean
local function isValidUsername(name)
    return name:match("^[-%w]+$") and not name:match("%-%-") and true or false
end

--- @param name string
--- @return boolean
local function isValidIdentifier(name)
    return name:match("^[_%a][_%w]*$") and true or false
end

--- Parse a package name into separate components.
---
--- Package name consists of up to three components separated by dashes.
---
--- The first component represents a github username. It is optional, and must consist
--- of letters and dashes.
---
--- The second one represents a github repository name. It is mandatory, and must form
--- a valid lua identifier.
---
--- The third component represents a sub-package within a repository, if repository
--- consists of multiple packages. It is optional, and must also form
--- a valid lua identifier.
---
---
--- Examples of package names
--- -------------------------
---
--- Full package name, represents package ``"taminomara-amm-ammcore"``
--- from repository ``"github.com/taminomara/amm"``:
---
--- .. code-block::
---
---            "taminomara-amm-ammcore"
---             ────────┬─ ─┬─ ─────┬─
---    github username ─╯   │       │
---    github repo ─────────╯       │
---    package name ────────────────╯
---
--- Short package name, represents package ``"taminomara-amm"``
--- from repository ``"github.com/taminomara/amm"``:
---
--- .. code-block::
---
---            "taminomara-amm"
---             ────────┬─ ─┬─
---    github username ─╯   │
---    github repo ─────────╯
---
--- Local package ``"example"``, not tied to any repository:
---
--- .. code-block::
---
---            "example"
---             ─────┬─
---    package name ─╯
---
--- Full package name, represents package ``"example-username-repo-package"``
--- from repository ``"github.com/example-username/repo"``:
---
--- .. code-block::
---
---            "example-username-repo-package"
---             ──────────────┬─ ──┬─ ─────┬─
---    github username ───────╯    │       │
---    github repo ────────────────╯       │
---    package name ───────────────────────╯
---
--- .. note::
---
---    Notice that github username contains dashes; such user will not be able
---    to publish ``"example-username-repo"``, because AMM will think that
---    it represents a package from repository ``"github.com/example/username"``.
---
--- @param name string package name.
--- @return boolean ok `true` if name is valid.
--- @return string? user first package name component: github username, if there is any.
--- @return string? repo second package name component, either github repo or a name.
--- @return string? name third package name component, only set for github sub-packages.
function ns.parseFullPackageName(name)
    local dashes = select(2, name:gsub("-", "-"))
    local user, repo, pkg

    if dashes == 0 then
        repo = name
    elseif dashes == 1 then
        user, repo = name:match("^(.*)-(.-)$")
    else
        user, repo, pkg = name:match("^(.*)-(.-)-(.-)$")
    end

    if user and not isValidUsername(user) then
        return false
    end

    if repo and not isValidIdentifier(repo) then
        return false
    end

    if pkg and not isValidIdentifier(pkg) then
        return false
    end

    return true, user, repo, pkg
end

return ns
