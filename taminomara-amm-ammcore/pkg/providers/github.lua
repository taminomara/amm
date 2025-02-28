local class             = require "ammcore/util/class"
local provider          = require "ammcore/pkg/provider"
local version           = require "ammcore/pkg/version"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"
local json              = require "ammcore/contrib/json"
local log               = require "ammcore/util/log"
local packageName       = require "ammcore/pkg/packageName"
local package           = require "ammcore/pkg/packageVersion"
local ammPackageJson    = require "ammcore/pkg/packageJson"
local bootloader        = require "ammcore/bootloader"

--- Github package provider.
local ns                = {}

local logger            = log.Logger:New()

--- Package version that was loaded from github.
---
--- @class ammcore.pkg.providers.github.GithubPackageVersion: ammcore.pkg.package.PackageVersion
ns.GithubPackageVersion = class.create("GithubPackageVersion", package.PackageVersion)

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param cacheData ammcore.pkg.providers.github.CacheVersion
--- @param provider ammcore.pkg.providers.github.GithubProvider
---
--- @generic T: ammcore.pkg.providers.github.GithubPackageVersion
--- @param self T
--- @return T
function ns.GithubPackageVersion:New(name, version, cacheData, provider)
    self = package.PackageVersion.New(self, name, version, provider)

    --- @private
    --- @type ammcore.pkg.providers.github.CacheVersion
    self._cacheData = cacheData

    --- @private
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self._requirements = nil

    return self
end

function ns.GithubPackageVersion:getRequirements()
    if not self._cacheData.data then
        self:_loadData()
    elseif not self._requirements then
        self._requirements = {}
        for name, spec in pairs(self._cacheData.data.requirements or {}) do
            self._requirements[name] = version.parseSpec(spec)
        end
    end

    return self._requirements
end

function ns.GithubPackageVersion:getDevRequirements()
    return {}
end

function ns.GithubPackageVersion:serialize()
    if not self._cacheData.data then
        self:_loadData()
    end
    return self._cacheData.data
end

--- @private
function ns.GithubPackageVersion:_loadData()
    local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[ @as FINInternetCard? ]]
    if not internetCard then
        error("GitHub dependency provider requires an internet card to download code")
    end

    logger:debug("Fetching %s", self._cacheData.metadataUrl)
    local res, rawMetadata = internetCard:request(self._cacheData.metadataUrl, "GET", ""):await()
    if not res then
        error("failed fetching package metadata: couldn't connect to github", 0)
    elseif res ~= 200 then
        error(string.format("failed fetching package metadata: HTTP error %s", res), 0)
    end

    local rawData
    local ok, err = pcall(function() rawData = json.decode(rawMetadata) end)
    if not ok then
        error(string.format("failed parsing package metadata: %s", err), 0)
    end

    local ver, requirements, _, data = ammPackageJson.parse(rawData, "github response")
    if data.name ~= self.name then
        error("package metadata name is inconsistent with release name", 0)
    end
    if ver ~= self.version then
        error("package metadata version is inconsistent with release version", 0)
    end

    self._cacheData.data = data
    self._requirements = requirements
end

function ns.GithubPackageVersion:install(packageRoot)
    local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[ @as FINInternetCard? ]]
    if not internetCard then
        error("GitHub dependency provider requires an internet card to download code")
    end

    logger:debug("Fetching %s", self._cacheData.codeUrl)
    local res, rawCode = internetCard:request(self._cacheData.codeUrl, "GET", ""):await()
    if not res then
        error("failed fetching package contents: couldn't connect to github", 0)
    elseif res ~= 200 then
        error(string.format("failed fetching package contents: HTTP error %s", res), 0)
    end

    local fn, err = load("return " .. rawCode, "<package bundle>", "bt", {})
    if not fn then
        error(string.format("failed parsing package contents: %s", err), 0)
    end

    logger:debug("Unpacking %s to %s", self.name, packageRoot)

    local files = fn()
    if type(files) ~= "table" then
        error("failed parsing package contents", 0)
    end
    for path, content in pairs(files) do
        if type(path) ~= "string" or type(content) ~= "string" then
            error("failed parsing package contents", 0)
        end

        local filePath = filesystem.path(packageRoot, filesystem.path(2, path))
        local fileDir = filePath:match("^(.*)/[^/]*$")
        logger:trace("Writing %s", filePath)
        filesystem.createDir(fileDir, true)
        filesystemHelpers.writeFile(filePath, content)
    end

    -- Verify installation.
    local version, _, _, data = ammPackageJson.parseFromFile(filesystem.path(packageRoot, ".ammpackage.json"))
    if data.name ~= self.name then
        error("failed parsing package contents: name from package contents doesn't match name from package metadata", 0)
    end
    if version ~= self.version then
        error("failed parsing package contents: version from package contents doesn't match version from package metadata", 0)
    end
end

--- @class ammcore.pkg.providers.github.CacheVersion
--- @field metadataUrl string
--- @field codeUrl string
--- @field data? ammcore.pkg.ammPackageJson.AmmPackageJson

--- @class ammcore.pkg.providers.github.CacheRepo
--- @field packages table<string, table<string, ammcore.pkg.providers.github.CacheVersion>>

--- Implements a provider that loads packages from github.
---
--- @class ammcore.pkg.providers.github.GithubProvider: ammcore.pkg.provider.Provider
ns.GithubProvider = class.create("GithubProvider", provider.Provider)

--- @generic T: ammcore.pkg.providers.github.GithubProvider
--- @param self T
--- @return T
function ns.GithubProvider:New()
    self = provider.Provider.New(self)

    self._internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[ @as FINInternetCard? ]]
    if not self._internetCard then
        error("GitHub dependency provider requires an internet card to download code")
    end

    --- @private
    --- @type table<string, ammcore.pkg.providers.github.CacheRepo>
    self._packages = {}

    --- @private
    --- @type table<string, true>
    self._freshPackages = {}

    local cachePath = filesystem.path(assert(bootloader.getSrvRoot()), "github.cache")
    if filesystem.exists(cachePath) and filesystem.isFile(cachePath) then
        local content = filesystemHelpers.readFile(cachePath)
        local ok, err = pcall(function() self._packages = json.decode(content) end)
        if not ok then
            logger:warning("Error when loading github metadata cache: %s", err)
        end
    end

    return self
end

--- @private
--- @param user string
--- @param repo string
--- @param name string
function ns.GithubProvider:_loadData(user, repo, name)
    local ghName = string.format("%s/%s", user, repo)

    if self._freshPackages[ghName] then
        return
    end

    logger:info("Fetching versions for %s", name)

    --- @type ammcore.pkg.providers.github.CacheRepo
    local cache = { packages = {} }
    --- @type ammcore.pkg.providers.github.CacheRepo
    local oldCache = self._packages[ghName]

    self._packages[ghName] = cache
    self._freshPackages[ghName] = true

    local url = string.format("https://api.github.com/repos/%s/%s/releases", user, repo)
    logger:debug("Fetching %s", url)
    local res, rawReleases = self._internetCard:request(url, "GET", ""):await()
    if not res then
        error("failed fetching package versions: couldn't connect to github", 0)
    elseif res == 404 then
        return
    elseif res ~= 200 then
        error(string.format("failed fetching package versions: HTTP error %s", res), 0)
    end

    local releases
    local ok, err = pcall(function() releases = json.decode(rawReleases) end)
    if not ok then
        error(string.format("failed parsing package versions: %s", err), 0)
    end

    local nTags = 0
    local nPackages = 0

    for _, release in ipairs(releases) do
        local tag = release["tag_name"]
        if type(tag) ~= "string" then
            goto continue
        end

        local releaseName, releaseVer = tag:match("^(.*)/v(.-)$")
        if not releaseName or not releaseVer then
            logger:warning("Repo https://github.com/%s/%s: ignoring release %s: tag is not properly formatted", user,
                repo, tag)
            goto continue
        end

        local releaseNameIsValid, releaseUser, releaseRepo, releasePkg = packageName.parseFullPackageName(releaseName)
        if not releaseNameIsValid then
            logger:warning("Repo https://github.com/%s/%s: ignoring release %s: tag is not properly formatted", user,
                repo, tag)
            goto continue
        end
        if releaseUser ~= user or releaseRepo ~= repo then
            logger:warning("Repo https://github.com/%s/%s: ignoring release %s: tag does not belong to this repo", user,
                repo, tag)
            goto continue
        end

        releasePkg = releasePkg or ""

        --- @type ammcore.pkg.version.Version
        local parsedReleaseVer
        if not pcall(function() parsedReleaseVer = version.parse(releaseVer) end) then
            logger:warning("Repo https://github.com/%s/%s: ignoring release %s: version is not properly formatted", user,
                repo, tag)
            goto continue
        end

        local releaseVerCanon = parsedReleaseVer:canonicalString()

        local metadataUrl, codeUrl

        for _, asset in ipairs(release["assets"]) do
            if asset["name"] == "ammpackage.json" then
                metadataUrl = asset["browser_download_url"]
            elseif asset["name"] == "package" then
                codeUrl = asset["browser_download_url"]
            end
        end

        if not metadataUrl or not codeUrl then
            logger:warning("Repo https://github.com/%s/%s: ignoring release %s: couldn't find necessary assets", user,
                repo, tag)
            goto continue
        end

        if not cache.packages[releasePkg] then
            cache.packages[releasePkg] = {}
            nPackages = nPackages + 1
        end

        cache.packages[releasePkg][releaseVerCanon] = { metadataUrl = metadataUrl, codeUrl = codeUrl }
        nTags = nTags + 1

        if oldCache and oldCache.packages[releasePkg] and oldCache.packages[releasePkg][releaseVerCanon] then
            cache.packages[releasePkg][releaseVerCanon].data = oldCache.packages[releasePkg][releaseVerCanon].data
        end

        ::continue::
    end

    logger:info(
        "Fetched %s release%s across %s package%s",
        nTags,
        nTags > 1 and "s" or "",
        nPackages,
        nPackages > 1 and "s" or ""
    )
end

function ns.GithubProvider:findPackageVersions(name)
    local ok, user, repo, pkg = packageName.parseFullPackageName(name)
    if not ok or not user or not repo then
        logger:warning("Not a github package: %s", name)
        return {}, false
    end

    self:_loadData(user, repo, name)

    local ghName = string.format("%s/%s", user, repo)

    if not self._packages[ghName] then
        return {}, false
    end

    pkg = pkg or ""

    if not self._packages[ghName].packages[pkg] then
        logger:warning("Package %s not found on GitHub", name)
        return {}, false
    end

    local result = {}

    for ver, data in pairs(self._packages[ghName].packages[pkg]) do
        table.insert(result, ns.GithubPackageVersion:New(name, version.parse(ver), data, self))
    end

    return result, true
end

function ns.GithubProvider:saveCache()
    local cachePath = filesystem.path(assert(bootloader.getSrvRoot()), "github.cache")
    filesystemHelpers.writeFile(cachePath, json.encode(self._packages))
end

return ns
