local install = require("lib/install")
local messages = require("lib/messages")
local versions = require("lib/versions")

--- Performs Visual Studio Build Tools installation after mise creates the install directory.
--- @param ctx {rootPath: string, runtimeVersion: string, sdkInfo: table} Context
function PLUGIN:PostInstall(ctx)
    local sdkInfo = ctx.sdkInfo["vsbuildtools"]
    local version = sdkInfo.version
    local sdkPath = sdkInfo.path
    local release = versions.resolve(version)

    if release == nil then
        error("Unsupported Visual Studio Build Tools version: " .. tostring(version))
    end

    local ok, err = pcall(function()
        install.install(release, sdkPath)
    end)

    if not ok then
        error(
            "\n\nFailed to install Visual Studio Build Tools " .. tostring(version) .. ".\n\n" ..
            tostring(err) .. "\n" ..
            messages.admin_tip() ..
            messages.verbose_tip(version) ..
            messages.see("debugging")
        )
    end
end
