--- Returns environment variables for the selected Visual Studio Build Tools instance.
--- @param ctx table Context provided by vfox
--- @return table Environment configuration
function PLUGIN:EnvKeys(ctx)
    local sdkInfo = ctx.sdkInfo["vsbuildtools"]
    local installDir = sdkInfo.path

    return {
        { key = "VSBUILDTOOLS_HOME", value = installDir },
        { key = "VSINSTALLDIR", value = installDir .. "\\" },
        { key = "PATH", value = installDir .. "\\bin" },
    }
end
