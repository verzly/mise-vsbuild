local M = {}

local known_releases = {
    {
        version = "current",
        note = "Visual Studio Build Tools current channel",
        major = "current",
        winget = "Microsoft.VisualStudio.BuildTools",
        bootstrapper = "",
        channel = "current",
    },
    {
        version = "2026",
        note = "Visual Studio 2026 Build Tools",
        major = "18",
        winget = "Microsoft.VisualStudio.BuildTools",
        bootstrapper = "https://aka.ms/vs/18/release/vs_BuildTools.exe",
    },
    {
        version = "2022",
        note = "Visual Studio 2022 Build Tools",
        major = "17",
        winget = "Microsoft.VisualStudio.2022.BuildTools",
        bootstrapper = "https://aka.ms/vs/17/release/vs_BuildTools.exe",
    },
    {
        version = "2019",
        note = "Visual Studio 2019 Build Tools",
        major = "16",
        winget = "Microsoft.VisualStudio.2019.BuildTools",
        bootstrapper = "https://aka.ms/vs/16/release/vs_BuildTools.exe",
    },
    {
        version = "2017",
        note = "Visual Studio 2017 Build Tools",
        major = "15",
        winget = "Microsoft.VisualStudio.2017.BuildTools",
        bootstrapper = "https://aka.ms/vs/15/release/vs_BuildTools.exe",
    },
}

local aliases = {
    latest = "current",
    stable = "current",
    current = "current",
    edge = "current",
    preview = "current",
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

local discovered_cache = nil

local function truthy(value)
    if value == nil then return false end
    value = tostring(value):lower()
    return value ~= "" and value ~= "0" and value ~= "false" and value ~= "no" and value ~= "off"
end

local function is_windows()
    if RUNTIME ~= nil and RUNTIME.osType ~= nil then
        return RUNTIME.osType == "windows"
    end
    return package.config:sub(1, 1) == "\\"
end

local function command_exists(command)
    if not is_windows() then
        return false
    end

    local handle = io.popen("where.exe " .. command .. " 2>NUL")
    if handle == nil then
        return false
    end

    local output = handle:read("*a") or ""
    handle:close()
    return output ~= ""
end

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
    if release == nil or release.version == nil then
        return
    end

    local existing = by_version(releases, release.version)
    if existing ~= nil then
        -- Prefer the built-in metadata for known release lines because it can include
        -- bootstrapper URLs and short aliases. Discovery is used to add future lines.
        if existing.discovered and not release.discovered then
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

local function known_bootstrapper_for_year(year)
    for _, release in ipairs(known_releases) do
        if release.version == year then
            return release.bootstrapper or ""
        end
    end
    return ""
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
            bootstrapper = "",
            channel = "current",
            discovered = true,
        }
    end

    local year = package_id:match("^Microsoft%.VisualStudio%.(%d%d%d%d)%.BuildTools$")
    if year ~= nil then
        return {
            version = year,
            note = "Visual Studio " .. year .. " Build Tools" .. (package_version ~= "" and (" (" .. package_version .. ")") or ""),
            major = known_major_for_year(year),
            winget = package_id,
            bootstrapper = known_bootstrapper_for_year(year),
            discovered = true,
        }
    end

    return nil
end

local function parse_winget_search(output)
    local releases = {}

    for line in tostring(output):gmatch("[^\r\n]+") do
        local package_id = line:match("(Microsoft%.VisualStudio%.%d%d%d%d%.BuildTools)")
        if package_id == nil then
            package_id = line:match("(Microsoft%.VisualStudio%.BuildTools)")
        end

        if package_id ~= nil then
            local after_id = line:match(package_id:gsub("%.", "%%.") .. "%s+([^%s]+)") or ""
            add_unique(releases, package_to_release(package_id, after_id))
        end
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

function M.discovery_enabled()
    return not truthy(os.getenv("VSBUILD_DISABLE_DISCOVERY"))
end

function M.discover()
    if discovered_cache ~= nil then
        return discovered_cache
    end

    discovered_cache = {}

    if not M.discovery_enabled() or not is_windows() or not command_exists("winget") then
        return discovered_cache
    end

    local command = table.concat({
        "winget", "search",
        "--source", "winget",
        "--id", "Microsoft.VisualStudio",
        "--accept-source-agreements",
        "2>NUL",
    }, " ")

    local handle = io.popen(command)
    if handle == nil then
        return discovered_cache
    end

    local output = handle:read("*a") or ""
    handle:close()

    discovered_cache = parse_winget_search(output)
    sort_releases(discovered_cache)
    return discovered_cache
end

function M.releases()
    local releases = {}

    for _, release in ipairs(known_releases) do
        add_unique(releases, clone(release))
    end

    for _, release in ipairs(M.discover()) do
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

    -- Future year support. This intentionally allows new year-specific
    -- Microsoft.VisualStudio.<YEAR>.BuildTools package IDs without requiring a
    -- plugin release. If the package does not exist, winget will fail clearly.
    if version:match("^%d%d%d%d$") then
        return {
            version = version,
            note = "Visual Studio " .. version .. " Build Tools (inferred)",
            major = "auto",
            winget = "Microsoft.VisualStudio." .. version .. ".BuildTools",
            bootstrapper = "",
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
