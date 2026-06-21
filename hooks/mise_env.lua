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
        set_env(env_vars, "VSBUILD_WORKLOADS", workloads)
    end

    local components = options.get(ctx, "components")
    if components ~= nil and components ~= "" and components ~= false then
        set_env(env_vars, "VSBUILD_COMPONENTS", components)
    end

    local install_method = options.get(ctx, "install_method")
    if install_method ~= nil and install_method ~= "" and install_method ~= false then
        set_env(env_vars, "VSBUILD_INSTALL_METHOD", install_method)
    end

    if options.disabled(options.get(ctx, "include_recommended")) then
        set_env(env_vars, "VSBUILD_NO_RECOMMENDED", 1)
    end

    if options.enabled(options.get(ctx, "include_optional")) then
        set_env(env_vars, "VSBUILD_INCLUDE_OPTIONAL", 1)
    end

    if options.enabled(options.get(ctx, "verbose")) then
        set_env(env_vars, "VSBUILD_VERBOSE", 1)
    end

    return env_vars
end
