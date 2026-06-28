local env = require("env")
local options = require("lib/options")

local function set_env(env_vars, key, value)
    local str_value = tostring(value)

    -- for current process, so install hooks can read the values immediately
    env.setenv(key, str_value)

    -- for child process envs, so `mise env --dotenv` and `mise exec` expose them too
    table.insert(env_vars, { key = key, value = str_value })
end

--- Returns plugin option environment variables when this plugin is active.
--- @param ctx {options: table} Context (options = plugin configuration from mise.toml)
--- @return table[] List of environment variable definitions with key/value pairs
function PLUGIN:MiseEnv(ctx)
    local env_vars = {}

    local workloads = options.get(ctx, "workloads")
    if workloads ~= nil and workloads ~= "" and workloads ~= false then
        set_env(env_vars, "VSBUILDTOOLS_WORKLOADS", workloads)
    end

    local components = options.get(ctx, "components")
    if components ~= nil and components ~= "" and components ~= false then
        set_env(env_vars, "VSBUILDTOOLS_COMPONENTS", components)
    end

    local install_method = options.get(ctx, "install_method")
    if install_method ~= nil and install_method ~= "" and install_method ~= false then
        set_env(env_vars, "VSBUILDTOOLS_INSTALL_METHOD", install_method)
    end

    local bootstrapper_url = options.get(ctx, "bootstrapper_url")
    if bootstrapper_url ~= nil and bootstrapper_url ~= "" and bootstrapper_url ~= false then
        set_env(env_vars, "VSBUILDTOOLS_BOOTSTRAPPER_URL", bootstrapper_url)
    end

    local vcvars_ver = options.get(ctx, "vcvars_ver")
    if vcvars_ver ~= nil and vcvars_ver ~= "" and vcvars_ver ~= false then
        set_env(env_vars, "VSBUILDTOOLS_VCVARS_VER", vcvars_ver)
    end

    if options.disabled(options.get(ctx, "include_recommended")) then
        set_env(env_vars, "VSBUILDTOOLS_NO_RECOMMENDED", 1)
    end

    if options.enabled(options.get(ctx, "include_optional")) then
        set_env(env_vars, "VSBUILDTOOLS_INCLUDE_OPTIONAL", 1)
    end

    if options.enabled(options.get(ctx, "verbose")) then
        set_env(env_vars, "VSBUILDTOOLS_VERBOSE", 1)
    end

    if options.enabled(options.get(ctx, "dry_run")) then
        set_env(env_vars, "VSBUILDTOOLS_DRY_RUN", 1)
    end

    return env_vars
end
