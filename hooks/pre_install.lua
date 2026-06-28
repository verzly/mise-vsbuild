local messages = require("lib/messages")
local versions = require("lib/vsbuild_versions")

--- Resolves the requested Visual Studio Build Tools version.
--- @param ctx {version: string, runtimeVersion: string} Context
--- @return table Version and download information
function PLUGIN:PreInstall(ctx)
    if RUNTIME.osType ~= "windows" then
        error(messages.windows_only())
    end

    local release = versions.resolve(ctx.version)
    if release == nil then
        error("Unsupported Visual Studio Build Tools version: " .. tostring(ctx.version) .. "\nSupported versions: " .. versions.supported_versions_text())
    end

    return {
        version = release.version,
        note = "Installing " .. release.note,
    }
end
