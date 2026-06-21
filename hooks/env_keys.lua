--- Returns environment variables for the selected Visual Studio Build Tools instance.
--- @param ctx table Context provided by vfox
--- @return table Environment configuration
function PLUGIN:EnvKeys(ctx)
    local sdkInfo = ctx.sdkInfo["vsbuild"]
    local installDir = sdkInfo.path

    local binDir = installDir .. "\\bin"

    return {
        { key = "VSBUILD_HOME", value = installDir },
        { key = "VSBUILD_INSTALL_PATH", value = installDir },
        { key = "VSBUILD_VERSION", value = sdkInfo.version },
        { key = "VSINSTALLDIR", value = installDir .. "\\" },
        { key = "PATH", value = binDir },
    }
end
