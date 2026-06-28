local M = {}

local cyan = "\27[96m"
local yellow = "\27[93m"
local reset = "\27[0m"

function M.step(name, message)
    print(string.format("  %-14s %s", name, message or ""))
end

function M.section(title)
    print("")
    print("  " .. title)
    print("  ----------------------------------------------------")
end

function M.note(message)
    print(cyan .. "Note:" .. reset .. " " .. message)
end

function M.warning(message)
    io.stderr:write(yellow .. "Warning:" .. reset .. " " .. message .. "\n")
end

function M.see(anchor)
    return "See: https://github.com/verzly/mise-vsbuild#" .. anchor .. "\n"
end

function M.windows_only()
    return "\n\nVisual Studio Build Tools can only be installed on Windows.\n\n"
end

function M.admin_tip()
    return "Tip: Run the terminal as Administrator if Visual Studio Installer or winget requests elevation.\n"
end

function M.verbose_tip(version)
    return "Tip: Set VSBUILD_VERBOSE=1 and retry: mise install vsbuild@" .. tostring(version) .. "\n"
end

function M.manual_tip(command)
    return "Tip: Run '" .. command .. "' manually to confirm it works.\n"
end

return M
