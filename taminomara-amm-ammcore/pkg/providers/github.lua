--- @namespace ammcore.pkg.providers.github

local class = require "ammcore.class"
local provider = require "ammcore.pkg.provider"
local version = require "ammcore.pkg.version"
local fsh = require "ammcore.fsh"
local json = require "ammcore._contrib.json"
local log = require "ammcore.log"
local packageName = require "ammcore.pkg.packageName"
local package = require "ammcore.pkg.package"
local packageJson = require "ammcore.pkg.packageJson"
local bootloader = require "ammcore.bootloader"

local ns = {}

local logger = log.getLogger()

--- Package version that was loaded from github.
---
--- @class GithubPackageVersion: ammcore.pkg.package.PackageVersion
ns.GithubPackageVersion = class.create("GithubPackageVersion", package.PackageVersion)

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param cacheData _CacheVersion
function ns.GithubPackageVersion:__init(name, version, cacheData)
    package.PackageVersion.__init(self, name, version)

    --- @private
    --- @type _CacheVersion
    self._cacheData = cacheData

    --- @private
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self._requirements = nil
end

function ns.GithubPackageVersion:getMetadata()
    if not self._cacheData.data then
        self:_loadData()
    end
    return self._cacheData.data --[[@as any]]
end

function ns.GithubPackageVersion:getRequirements()
    if not self._cacheData.data then
        self:_loadData()
    elseif not self._requirements then
        self._requirements = {}
        for name, specTxt in pairs(self._cacheData.data.requirements or {}) do
            self._requirements[name] = version.parseSpec(specTxt)
        end
    end

    return self._requirements
end

function ns.GithubPackageVersion:getDevRequirements()
    return {}
end

--- @private
function ns.GithubPackageVersion:_loadData()
    local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[@as FINInternetCard?]]
    if not internetCard then
        error("GitHub dependency provider requires an internet card to download code")
    end

    logger:debug("Fetching %s", self._cacheData.metadataUrl)
    local res, metadataTxt = internetCard:request(self._cacheData.metadataUrl, "GET", ""):await()
    if not res then
        error("failed fetching package metadata: couldn't connect to github", 0)
    elseif res ~= 200 then
        error(string.format("failed fetching package metadata: HTTP error %s", res), 0)
    end

    local ver, requirements, _, data = packageJson.parseFromString(metadataTxt, "github response")
    if data.name ~= self.name then
        error("package metadata name is inconsistent with release name", 0)
    end
    if ver ~= self.version then
        error("package metadata version is inconsistent with release version", 0)
    end

    self._cacheData.data = data
    self._requirements = requirements
end

function ns.GithubPackageVersion:build()
    local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[@as FINInternetCard?]]
    if not internetCard then
        error("GitHub dependency provider requires an internet card to download code")
    end

    logger:debug("Fetching %s", self._cacheData.codeUrl)
    local res, archive = internetCard:request(self._cacheData.codeUrl, "GET", ""):await()
    if not res then
        error("failed fetching package contents: couldn't connect to github", 0)
    elseif res ~= 200 then
        error(string.format("failed fetching package contents: HTTP error %s", res), 0)
    end

    return archive
end

--- !doc private
--- @class _CacheVersion
--- @field metadataUrl string
--- @field codeUrl string
--- @field data? ammcore.pkg.packageJson.PackageJson

--- !doc private
--- @class _CacheRepo
--- @field packages table<string, table<string, _CacheVersion>>

--- Implements a provider that loads packages from github.
---
--- @class GithubProvider: ammcore.pkg.provider.Provider
ns.GithubProvider = class.create("GithubProvider", provider.Provider)

--- @param internetCard FINInternetCard
function ns.GithubProvider:__init(internetCard)
    provider.Provider.__init(self)

    self._internetCard = internetCard

    --- @private
    --- @type table<string, _CacheRepo>
    self._packages = {}

    --- @private
    --- @type table<string, true>
    self._freshPackages = {}

    local srvRoot = bootloader.getSrvRoot()
    local cachePath = srvRoot and filesystem.path(srvRoot, "github.cache")
    if cachePath and filesystem.exists(cachePath) and filesystem.isFile(cachePath) then
        local content = fsh.readFile(cachePath)
        local ok, err = pcall(function() self._packages = json.decode(content) end)
        if not ok then
            logger:warning("Error when loading github metadata cache: %s", err)
        end
    end
end

--- @private
--- @param user string
--- @param repo string
function ns.GithubProvider:_loadData(user, repo)
    local ghName = string.format("%s/%s", user, repo)

    if self._freshPackages[ghName] then
        return
    end

    logger:info("Fetching versions from github repo %s", ghName)

    --- @type _CacheRepo
    local cache = { packages = {} }
    --- @type _CacheRepo
    local oldCache = self._packages[ghName]

    self._packages[ghName] = cache
    self._freshPackages[ghName] = true

    local url = string.format("https://api.github.com/repos/%s/%s/releases", user, repo)
    logger:debug("Fetching %s", url)
    local res, releasesTxt = self._internetCard:request(url, "GET", ""):await()
    if not res then
        error("failed fetching package versions: couldn't connect to github", 0)
    elseif res == 404 then
        return
    elseif res ~= 200 then
        error(string.format("failed fetching package versions: HTTP error %s", res), 0)
    end

    local releases
    local ok, err = pcall(function() releases = json.decode(releasesTxt) end)
    if not ok then
        error(string.format("failed parsing package versions: %s", err), 0)
    end

    local nTags = 0
    local nPackages = 0

    for _, release in ipairs(releases) do
        local tag = release["tag_name"]
        if type(tag) ~= "string" then
            logger:warning("Repo %s: ignoring an unknown release: no tag specified", ghName)
            goto continue
        end

        local releaseName, releaseVerTxt = tag:match("^(.*)/v(.-)$")
        if not releaseName or not releaseVerTxt then
            logger:warning("Repo %s: ignoring release %s: tag is not properly formatted", ghName, tag)
            goto continue
        end

        local releaseNameIsValid, releaseUser, releaseRepo, releasePkg = packageName.parseFullPackageName(releaseName)
        if not releaseNameIsValid then
            logger:warning("Repo %s: ignoring release %s: tag is not properly formatted", ghName, tag)
            goto continue
        end
        if releaseUser ~= user or releaseRepo ~= repo then
            logger:warning("Repo %s: ignoring release %s: tag does not belong to this repo", ghName, tag)
            goto continue
        end

        releasePkg = releasePkg or ""

        --- @type ammcore.pkg.version.Version
        local releaseVer
        if not pcall(function() releaseVer = version.parse(releaseVerTxt) end) then
            logger:warning("Repo %s: ignoring release %s: version is not properly formatted", ghName, tag)
            goto continue
        end

        local releaseVerCanonTxt = releaseVer:canonicalString()

        local metadataUrl, codeUrl

        for _, asset in ipairs(release["assets"]) do
            if asset["name"] == "ammpackage.json" then
                metadataUrl = asset["browser_download_url"]
            elseif asset["name"] == "package" then
                codeUrl = asset["browser_download_url"]
            end
        end

        if not metadataUrl or not codeUrl then
            logger:warning("Repo %s: ignoring release %s: couldn't find necessary assets", ghName, tag)
            goto continue
        end

        if not cache.packages[releasePkg] then
            cache.packages[releasePkg] = {}
            nPackages = nPackages + 1
        end

        cache.packages[releasePkg][releaseVerCanonTxt] = { metadataUrl = metadataUrl, codeUrl = codeUrl }
        nTags = nTags + 1

        if oldCache and oldCache.packages[releasePkg] and oldCache.packages[releasePkg][releaseVerCanonTxt] then
            cache.packages[releasePkg][releaseVerCanonTxt].data = oldCache.packages[releasePkg][releaseVerCanonTxt].data
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

--- @param name string
--- @param includeRemotePackages boolean
--- @return ammcore.pkg.providers.local.LocalPackageVersion[]
--- @return boolean
function ns.GithubProvider:findPackageVersions(name, includeRemotePackages)
    if not includeRemotePackages then
        return {}, false
    end

    local ok, user, repo, pkg = packageName.parseFullPackageName(name)
    if not ok or not user or not repo then
        logger:warning("Not a github package: %s", name)
        return {}, false
    end

    self:_loadData(user, repo)

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
        table.insert(result, ns.GithubPackageVersion(name, version.parse(ver), data))
    end

    return result, true
end

function ns.GithubProvider:finalize()
    local srvRoot = bootloader.getSrvRoot()
    if srvRoot then
        local cachePath = filesystem.path(srvRoot, "github.cache")
        fsh.writeFile(cachePath, json.encode(self._packages))
    end
end

return ns
