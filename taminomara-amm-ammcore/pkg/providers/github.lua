local class             = require "ammcore/util/class"
local provider          = require "ammcore/pkg/provider"
local version           = require "ammcore/pkg/version"
local filesystemHelpers = require "ammcore/util/filesystemHelpers"
local json              = require "ammcore/contrib/json"
local log               = require "ammcore/util/log"
local packageName       = require "ammcore/pkg/packageName"
local package           = require "ammcore/pkg/packageVersion"
local ammPackageJson    = require "ammcore/pkg/ammPackageJson"

--- Github package provider.
local ns                = {}

local logger            = log.Logger:New()

local cachePath         = "/.amm_packages.gh-cache.json"

--- Package version that was loaded from github.
---
--- @class ammcore.pkg.package.GithubPackageVersion: ammcore.pkg.package.PackageVersion
ns.GithubPackageVersion = class.create("GithubPackageVersion", package.PackageVersion)

--- @param name string
--- @param version ammcore.pkg.version.Version
--- @param data ammcore.pkg.providers.github.CacheVersion
--- @param provider ammcore.pkg.providers.github.GithubProvider
---
--- @generic T: ammcore.pkg.package.GithubPackageVersion
--- @param self T
--- @return T
function ns.GithubPackageVersion:New(name, version, data, provider)
    self = ns.PackageVersion.New(self, name, version, provider)

    --- @private
    --- @type ammcore.pkg.providers.github.CacheVersion
    self._data = data

    --- @private
    --- @type table<string, ammcore.pkg.version.VersionSpec>
    self._requirements = nil

    return self
end

function ns.GithubPackageVersion:getRequirements()
    if not self._data.requirements then
        local internetCard = computer.getPCIDevices(classes.FINInternetCard)[1] --[[ @as FINInternetCard? ]]
        if not internetCard then
            error("GitHub dependency provider requires an internet card to download code")
        end

        logger:debug("Fetching %s", self._data.metadataUrl)
        local res, rawMetadata = internetCard:request(self._data.metadataUrl, "GET", ""):await()
        if not res then
            error("Couldn't connect to github")
        elseif res ~= 200 then
            error("Got an error from github API: " .. tostring(res))
        end

        local data
        local ok, err = pcall(function() data = json.decode(rawMetadata) end)
        if not ok then
            error("Failed to parse response from github: " .. err)
        end

        local ver, requirements = ammPackageJson.parse(data, "github response")

        if ver ~= self.version then
            error("Package metadata version is inconsistent with release version")
        end

        self._data.requirements = data["requirements"] or {}
        self._requirements = requirements
    elseif not self._requirements then
        self._requirements = {}
        for name, spec in pairs(self._data.requirements) do
            self._requirements[name] = version.parseSpec(spec)
        end
    end

    return self._requirements
end

function ns.GithubPackageVersion:getDevRequirements()
    return {}
end

--- @class ammcore.pkg.providers.github.CacheVersion
--- @field metadataUrl string
--- @field codeUrl string
--- @field requirements table<string, string>?

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
function ns.GithubProvider:_loadData(user, repo)
    local ghName = string.format("%s/%s", user, repo)

    if self._freshPackages[ghName] then
        return
    end

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
        error("Couldn't connect to github")
    elseif res == 404 then
        logger:warning("Repo https://github.com/%s/%s: package not found", user, repo)
        return
    elseif res ~= 200 then
        error("Got an error from github API: " .. tostring(res))
    end

    local releases
    local ok, err = pcall(function() releases = json.decode(rawReleases) end)
    if not ok then
        error("Failed to parse response from github: " .. err)
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
            elseif asset["name"] == "ammcode.tsv" then
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
            cache.packages[releasePkg][releaseVerCanon].requirements = oldCache.packages[releasePkg][releaseVerCanon]
                .requirements
        end

        ::continue::
    end

    logger:info("Repo https://github.com/%s/%s: fetched %s releases across %s packages", user, repo, nTags, nPackages)
end

function ns.GithubProvider:findPackageVersions(name)
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
        logger:warning("Repo https://github.com/%s/%s: package not found")
    end

    local result = {}

    for ver, data in pairs(self._packages[ghName].packages[pkg]) do
        table.insert(result, ns.GithubPackageVersion:New(name, version.parse(ver), data, self))
    end

    return result, true
end

return ns
