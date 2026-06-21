local function is_enabled(env_var)
    local v = os.getenv(env_var)
    if v == nil then return false end
    v = tostring(v):lower()
    return v ~= "" and v ~= "0" and v ~= "false" and v ~= "no" and v ~= "off"
end

local function value_or(name, default)
    local v = os.getenv(name)
    if v == nil or v == "" then return default end
    return v
end

local function quiet_redirect()
    if is_enabled("VSBUILD_VERBOSE") or is_enabled("MISE_VERBOSE") then
        return ""
    end

    if RUNTIME ~= nil and RUNTIME.osType == "windows" then
        return " > NUL 2>&1"
    end

    return " > /dev/null 2>&1"
end

return {
    VERBOSE = is_enabled("VSBUILD_VERBOSE") or is_enabled("MISE_VERBOSE"),
    QUIET = quiet_redirect(),
    WORKLOADS = value_or("VSBUILD_WORKLOADS", "Microsoft.VisualStudio.Workload.VCTools"),
    COMPONENTS = value_or("VSBUILD_COMPONENTS", ""),
    INSTALL_METHOD = value_or("VSBUILD_INSTALL_METHOD", "winget"),
    BOOTSTRAPPER_URL = value_or("VSBUILD_BOOTSTRAPPER_URL", ""),
    INCLUDE_RECOMMENDED = not is_enabled("VSBUILD_NO_RECOMMENDED"),
    INCLUDE_OPTIONAL = is_enabled("VSBUILD_INCLUDE_OPTIONAL"),
}
