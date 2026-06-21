local M = {}

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

M.VERBOSE = is_enabled("VSBUILD_VERBOSE") or is_enabled("MISE_VERBOSE")
M.QUIET = quiet_redirect()
M.WORKLOADS = value_or("VSBUILD_WORKLOADS", "Microsoft.VisualStudio.Workload.VCTools")
M.COMPONENTS = value_or("VSBUILD_COMPONENTS", "")
M.INSTALL_METHOD = value_or("VSBUILD_INSTALL_METHOD", "winget")
M.BOOTSTRAPPER_URL = value_or("VSBUILD_BOOTSTRAPPER_URL", "")
M.INCLUDE_RECOMMENDED = not is_enabled("VSBUILD_NO_RECOMMENDED")
M.INCLUDE_OPTIONAL = is_enabled("VSBUILD_INCLUDE_OPTIONAL")
M.DRY_RUN = is_enabled("VSBUILD_DRY_RUN")

return M
