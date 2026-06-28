local function is_enabled(env_var)
    local v = os.getenv(env_var)
    if v == nil then return false end
    v = tostring(v):lower()
    return v ~= "" and v ~= "0" and v ~= "false"
end

local function is_verbose()
    if is_enabled("VSBUILDTOOLS_VERBOSE") then return true end
    if is_enabled("MISE_VERBOSE") then return true end
    return false
end

local function quiet_redirect()
    if is_verbose() then
        return ""
    end

    if RUNTIME ~= nil and RUNTIME.osType == "windows" then
        return " > NUL 2>&1"
    end

    return " > /dev/null 2>&1"
end

local VERBOSE = is_verbose()
local QUIET   = quiet_redirect()

return {
    VERBOSE = VERBOSE,
    QUIET   = QUIET,
}
