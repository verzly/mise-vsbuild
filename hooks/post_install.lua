local env = require("lib/env")
local messages = require("lib/messages")
local versions = require("lib/versions")

local function quote(value)
    return '"' .. tostring(value):gsub('"', '\\"') .. '"'
end

--- Performs Visual Studio Build Tools installation after mise creates the install directory.
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo["vsbuild"]
    local version = sdkInfo.version
    local sdkPath = sdkInfo.path
    local release = versions.resolve(version)

    if release == nil then
        error("Unsupported Visual Studio Build Tools version: " .. tostring(version))
    end

    local scriptPath = RUNTIME.pluginDirPath .. "\\bin\\install-vsbuild.ps1"
    local bootstrapper = release.bootstrapper or ""
    if env.BOOTSTRAPPER_URL ~= nil and env.BOOTSTRAPPER_URL ~= "" then
        bootstrapper = env.BOOTSTRAPPER_URL
    end

    local cmd = table.concat({
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", quote(scriptPath),
        "-Version", quote(release.version),
        "-InstallPath", quote(sdkPath),
        "-WingetId", quote(release.winget),
        "-BootstrapperUrl", quote(bootstrapper),
        "-Workloads", quote(env.WORKLOADS),
        "-Components", quote(env.COMPONENTS),
        "-InstallMethod", quote(env.INSTALL_METHOD)
    }, " ")

    if env.INCLUDE_RECOMMENDED then
        cmd = cmd .. " -IncludeRecommended"
    end

    if env.INCLUDE_OPTIONAL then
        cmd = cmd .. " -IncludeOptional"
    end

    if env.VERBOSE then
        cmd = cmd .. " -VerboseOutput"
    end

    local status = os.execute(cmd)
    if status ~= 0 and status ~= true then
        error(
            "\n\nFailed to install Visual Studio Build Tools " .. version .. ".\n\n" ..
            messages.admin_tip() ..
            messages.verbose_tip(version) ..
            messages.see("debugging")
        )
    end
end
