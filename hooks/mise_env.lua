local env = require("env")
local options = require("lib/options")

local function set_env(env_vars, key, value)
    local str_value = tostring(value)

    -- for current process, so install hooks can read the values immediately
    env.setenv(key, str_value)

    -- for child process envs, so `mise env --dotenv` and `mise exec` expose them too
    table.insert(env_vars, { key = key, value = str_value })
end

--- Returns environment variables to set when this plugin is active.
--- Documentation: https://mise.jdx.dev/env-plugin-development.html#miseenv-hook
--- @param ctx {options: table} Context (options = plugin configuration from mise.toml)
--- @return table[] List of environment variable definitions with key/value pairs
function PLUGIN:MiseEnv(ctx)
    local env_vars = {}

    if options.enabled(options.get(ctx, "verbose")) then
        set_env(env_vars, "VSBUILD_VERBOSE", 1)
    end

    return env_vars
end
