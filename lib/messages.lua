local M = {}

function M.see(anchor)
    return "See README.md#" .. anchor .. " for details.\n"
end

function M.windows_only()
    return "\n\nVisual Studio Build Tools can only be installed on Windows.\n\n"
end

function M.admin_tip()
    return "💡 Tip: Run the terminal as Administrator if Visual Studio Installer or winget requests elevation.\n"
end

function M.verbose_tip(version)
    return "💡 Tip: Set VSBUILD_VERBOSE=1 and retry: mise install vsbuild@" .. tostring(version) .. "\n"
end

return M
