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
    if is_enabled("VSBUILDTOOLS_VERBOSE") or is_enabled("MISE_VERBOSE") then
        return ""
    end

    if RUNTIME ~= nil and RUNTIME.osType == "windows" then
        return " > NUL 2>&1"
    end

    return " > /dev/null 2>&1"
end

M.VERBOSE = is_enabled("VSBUILDTOOLS_VERBOSE") or is_enabled("MISE_VERBOSE")
M.QUIET = quiet_redirect()
M.WORKLOADS = value_or("VSBUILDTOOLS_WORKLOADS", "Microsoft.VisualStudio.Workload.VCTools")
M.COMPONENTS = value_or("VSBUILDTOOLS_COMPONENTS", "")
M.INSTALL_METHOD = value_or("VSBUILDTOOLS_INSTALL_METHOD", "winget")
M.BOOTSTRAPPER_URL = value_or("VSBUILDTOOLS_BOOTSTRAPPER_URL", "")
M.INCLUDE_RECOMMENDED = not is_enabled("VSBUILDTOOLS_NO_RECOMMENDED")
M.INCLUDE_OPTIONAL = is_enabled("VSBUILDTOOLS_INCLUDE_OPTIONAL")
M.VCVARS_VER = value_or("VSBUILDTOOLS_VCVARS_VER", "")
M.DRY_RUN = is_enabled("VSBUILDTOOLS_DRY_RUN")

return M
