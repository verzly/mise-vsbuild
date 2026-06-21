local env = require("lib/env")

local M = {}

function M.verbose_tip(version)
    if env.VERBOSE then
        return "💡 Verbose mode is enabled; Visual Studio Installer and WinGet commands will be shown.\n"
    end

    return "💡 Tip: \27[93mRun 'VSBUILD_VERBOSE=1 mise install vsbuild@" .. (version or "VERSION") .. "'\27[0m to show commands and installer details.\n"
end

function M.admin_tip()
    return "💡 Tip: \27[93mRun the terminal as Administrator\27[0m if Visual Studio Installer or WinGet requests elevation.\n"
end

function M.manual_tip(command)
    return "💡 Tip: \27[93mRun '" .. command .. "'\27[0m manually after installation to confirm it works.\n"
end

function M.see(anchor)
    return "→ See: https://github.com/verzly/mise-vsbuild#" .. anchor .. "\n"
end

function M.windows_only()
    return "\n\nVisual Studio Build Tools can only be installed on Windows.\n\n"
end

return M
