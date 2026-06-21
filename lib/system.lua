local M = {}

local sep = package.config:sub(1, 1)

function M.is_windows()
    if RUNTIME ~= nil and RUNTIME.osType ~= nil then
        return RUNTIME.osType == "windows"
    end
    return sep == "\\"
end

function M.join_path(...)
    local parts = { ... }
    local path = tostring(parts[1] or "")
    for i = 2, #parts do
        local part = tostring(parts[i] or "")
        if part ~= "" then
            if path:sub(-1) ~= "\\" and path:sub(-1) ~= "/" then
                path = path .. sep
            end
            path = path .. part
        end
    end
    return path
end

function M.parent_dir(path)
    return tostring(path):match("^(.*)[/\\][^/\\]+[/\\]*$") or "."
end

function M.mkdir(path)
    if M.is_windows() then
        return os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '"')
    end
    return os.execute('mkdir -p "' .. path .. '"')
end

function M.command_exists(command)
    local check = M.is_windows()
        and ('where.exe ' .. command .. ' > NUL 2>&1')
        or ('command -v ' .. command .. ' > /dev/null 2>&1')
    local ok = os.execute(check)
    return ok == true or ok == 0
end

function M.read_all(command)
    local handle = io.popen(command)
    if handle == nil then
        return ""
    end
    local output = handle:read("*a") or ""
    handle:close()
    return output
end

function M.exists(path)
    local f = io.open(path, "rb")
    if f ~= nil then
        f:close()
        return true
    end
    return false
end

function M.write_file(path, content)
    local dir = M.parent_dir(path)
    M.mkdir(dir)

    local file = assert(io.open(path, "wb"))
    file:write(content)
    file:close()
end

function M.quote(value)
    value = tostring(value or "")
    if value == "" then
        return '""'
    end

    -- Good enough for the cmd.exe calls produced by this plugin. The generated
    -- arguments are controlled by the plugin and should not contain literal quotes.
    if value:find('[%s&()^!%%]') or value:find('"') then
        return '"' .. value:gsub('"', '\\"') .. '"'
    end

    return value
end

function M.cmd_status_ok(status)
    return status == true or status == 0
end

function M.vswhere_path()
    local base = os.getenv("ProgramFiles(x86)") or "C:\\Program Files (x86)"
    return M.join_path(base, "Microsoft Visual Studio", "Installer", "vswhere.exe")
end

function M.vs_installer_path()
    local base = os.getenv("ProgramFiles(x86)") or "C:\\Program Files (x86)"
    return M.join_path(base, "Microsoft Visual Studio", "Installer", "vs_installer.exe")
end

function M.test_vs_instance(path)
    return M.exists(M.join_path(path, "VC", "Auxiliary", "Build", "vcvars64.bat"))
        and M.exists(M.join_path(path, "Common7", "Tools", "VsDevCmd.bat"))
end

return M
