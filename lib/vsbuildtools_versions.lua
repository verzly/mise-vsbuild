local M = {}

local CACHE_URL = "https://raw.githubusercontent.com/verzly/mise-vsbuildtools/cache/versions.txt"

local known_releases = {
    {
        version = "current",
        note = "Visual Studio Build Tools current channel",
        major = "current",
        winget = "Microsoft.VisualStudio.BuildTools",
        channel = "current",
    },
    {
        version = "2026",
        note = "Visual Studio 2026 Build Tools",
        major = "18",
        winget = "Microsoft.VisualStudio.BuildTools",
        channel = "stable",
    },
    {
        version = "2022",
        note = "Visual Studio 2022 Build Tools",
        major = "17",
        winget = "Microsoft.VisualStudio.2022.BuildTools",
    },
    {
        version = "2019",
        note = "Visual Studio 2019 Build Tools",
        major = "16",
        winget = "Microsoft.VisualStudio.2019.BuildTools",
    },
    {
        version = "2017",
        note = "Visual Studio 2017 Build Tools",
        major = "15",
        winget = "Microsoft.VisualStudio.2017.BuildTools",
    },
}

local aliases = {
    latest = "current",
    stable = "current",
    current = "current",
    ["18"] = "2026",
    ["18.0"] = "2026",
    ["26"] = "2026",
    ["17"] = "2022",
    ["17.0"] = "2022",
    ["22"] = "2022",
    ["16"] = "2019",
    ["16.0"] = "2019",
    ["19"] = "2019",
    ["15"] = "2017",
    ["15.0"] = "2017",
}

local cached_releases = nil

local function clone(release)
    local out = {}
    for k, v in pairs(release) do
        out[k] = v
    end
    return out
end

local function by_version(releases, version)
    for _, release in ipairs(releases) do
        if release.version == version then
            return release
        end
    end
    return nil
end

local function add_unique(releases, release)
    if release == nil or release.version == nil or release.version == "" then
        return
    end

    local existing = by_version(releases, release.version)
    if existing ~= nil then
        if existing.cached ~= true and release.cached == true then
            for k, v in pairs(release) do
                existing[k] = v
            end
        end
        return
    end

    table.insert(releases, release)
end

local function known_major_for_year(year)
    for _, release in ipairs(known_releases) do
        if release.version == year then
            return release.major
        end
    end
    return "auto"
end

local function package_to_release(package_id, package_version)
    if package_id == nil then
        return nil
    end

    package_id = tostring(package_id)
    package_version = package_version or ""

    if package_id == "Microsoft.VisualStudio.BuildTools" then
        return {
            version = "current",
            note = "Visual Studio Build Tools current channel" .. (package_version ~= "" and (" (" .. package_version .. ")") or ""),
            major = "current",
            winget = package_id,
            channel = "current",
            cached = true,
        }
    end

    local year = package_id:match("^Microsoft%.VisualStudio%.(%d%d%d%d)%.BuildTools$")
    if year ~= nil then
        return {
            version = year,
            note = "Visual Studio " .. year .. " Build Tools" .. (package_version ~= "" and (" (" .. package_version .. ")") or ""),
            major = known_major_for_year(year),
            winget = package_id,
            cached = true,
        }
    end

    return nil
end

local function parse_cache_line(line)
    local version, package_id, package_version = tostring(line or ""):match("^([^\t]+)\t([^\t]+)\t?(.*)$")
    if package_id == nil then
        return nil
    end

    version = tostring(version or ""):match("^%s*(.-)%s*$")
    package_id = tostring(package_id or ""):match("^%s*(.-)%s*$")
    package_version = tostring(package_version or ""):match("^%s*(.-)%s*$")

    local release = package_to_release(package_id, package_version)
    if release ~= nil then
        release.version = version

        if version:match("^%d%d%d%d$") then
            release.note = "Visual Studio " .. version .. " Build Tools" .. (package_version ~= "" and (" (" .. package_version .. ")") or "")
            release.major = known_major_for_year(version)
            release.channel = release.channel == "current" and "stable" or release.channel
        end
    end
    return release
end

local function parse_cache(body)
    local releases = {}

    for line in tostring(body or ""):gmatch("[^\r\n]+") do
        add_unique(releases, parse_cache_line(line))
    end

    return releases
end

local function sort_releases(releases)
    table.sort(releases, function(a, b)
        if a.version == "current" then return true end
        if b.version == "current" then return false end

        local an = tonumber(a.version) or 0
        local bn = tonumber(b.version) or 0
        if an ~= bn then
            return an > bn
        end
        return tostring(a.version) < tostring(b.version)
    end)
end

function M.cached()
    if cached_releases ~= nil then
        return cached_releases
    end

    cached_releases = {}

    local ok, http = pcall(require, "http")
    if not ok or http == nil then
        return cached_releases
    end

    local resp, err = http.get({
        url = CACHE_URL,
        headers = {
            ["User-Agent"] = "verzly-mise-vsbuildtools",
        },
    })

    if err ~= nil or resp == nil or resp.status_code ~= 200 then
        return cached_releases
    end

    cached_releases = parse_cache(resp.body)
    sort_releases(cached_releases)
    return cached_releases
end

function M.releases()
    local releases = {}

    for _, release in ipairs(known_releases) do
        add_unique(releases, clone(release))
    end

    for _, release in ipairs(M.cached()) do
        add_unique(releases, release)
    end

    sort_releases(releases)
    return releases
end

function M.resolve(version)
    if version == nil or version == "" then
        version = "latest"
    end

    version = tostring(version)
    version = aliases[version] or version

    for _, release in ipairs(M.releases()) do
        if release.version == version or release.major == version then
            return release
        end
    end

    if version:match("^%d%d%d%d$") then
        return {
            version = version,
            note = "Visual Studio " .. version .. " Build Tools (inferred)",
            major = "auto",
            winget = "Microsoft.VisualStudio." .. version .. ".BuildTools",
            inferred = true,
        }
    end

    return nil
end

function M.supported_versions_text()
    local values = {}
    for _, release in ipairs(M.releases()) do
        table.insert(values, release.version)
    end
    table.insert(values, "latest")
    table.insert(values, "stable")
    table.insert(values, "future YYYY via WinGet if Microsoft publishes Microsoft.VisualStudio.<YYYY>.BuildTools")
    return table.concat(values, ", ")
end

return M
