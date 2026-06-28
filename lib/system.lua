local M = {}

local sep = package.config:sub(1, 1)

local function base64_encode(data)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = {}
    local i = 1

    while i <= #data do
        local b1 = data:byte(i) or 0
        local b2 = data:byte(i + 1)
        local b3 = data:byte(i + 2)

        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        table.insert(result, alphabet:sub(c1 + 1, c1 + 1))
        table.insert(result, alphabet:sub(c2 + 1, c2 + 1))
        table.insert(result, b2 and alphabet:sub(c3 + 1, c3 + 1) or "=")
        table.insert(result, b3 and alphabet:sub(c4 + 1, c4 + 1) or "=")

        i = i + 3
    end

    return table.concat(result)
end

local function append_utf16le_codepoint(out, codepoint)
    if codepoint < 0x10000 then
        table.insert(out, string.char(codepoint % 256))
        table.insert(out, string.char(math.floor(codepoint / 256) % 256))
        return
    end

    codepoint = codepoint - 0x10000
    local high = 0xD800 + math.floor(codepoint / 0x400)
    local low = 0xDC00 + (codepoint % 0x400)

    table.insert(out, string.char(high % 256))
    table.insert(out, string.char(math.floor(high / 256) % 256))
    table.insert(out, string.char(low % 256))
    table.insert(out, string.char(math.floor(low / 256) % 256))
end

local function utf16le(value)
    value = tostring(value or "")
    local out = {}

    if utf8 ~= nil and utf8.codes ~= nil then
        for _, codepoint in utf8.codes(value) do
            append_utf16le_codepoint(out, codepoint)
        end
        return table.concat(out)
    end

    for i = 1, #value do
        local b = value:byte(i)
        table.insert(out, string.char(b))
        table.insert(out, string.char(0))
    end

    return table.concat(out)
end

local function powershell_encoded_command(script)
    return base64_encode(utf16le(script))
end


local function normalize_success_codes(success_codes)
    local codes = { [0] = true }

    if success_codes ~= nil then
        for _, code in ipairs(success_codes) do
            codes[tonumber(code) or code] = true
        end
    end

    return codes
end

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
            if path ~= "" and path:sub(-1) ~= "\\" and path:sub(-1) ~= "/" then
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
    if path == nil or path == "" or path == "." then
        return true
    end

    if M.is_windows() then
        local ok = M.execute_command('if not exist "' .. tostring(path):gsub('"', '\\"') .. '" mkdir "' .. tostring(path):gsub('"', '\\"') .. '"')
        return ok
    end

    local ok = M.execute_command('mkdir -p "' .. tostring(path):gsub('"', '\\"') .. '"')
    return ok
end

function M.command_exists(command)
    local check = M.is_windows()
        and ('where.exe ' .. command .. ' > NUL 2>&1')
        or ('command -v ' .. command .. ' > /dev/null 2>&1')
    local ok = M.execute_command(check)
    return ok
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

function M.temp_dir()
    return os.getenv("TEMP") or os.getenv("TMP") or "."
end

function M.quote(value)
    value = tostring(value or "")
    if value == "" then
        return '""'
    end

    if value:find('[%s&()^!%%]') or value:find('"') then
        return '"' .. value:gsub('"', '\\"') .. '"'
    end

    return value
end

function M.powershell_quote(value)
    value = tostring(value or "")

    if value:find("[%z\r\n]") then
        error("Unsupported Windows command argument: " .. value)
    end

    return "'" .. value:gsub("'", "''") .. "'"
end

function M.windows_cmd_quote(value)
    value = tostring(value or "")

    if value:find("[%z\r\n\"]") then
        error("Unsupported Windows command script: " .. value)
    end

    return '"' .. value:gsub("%%", "%%%%") .. '"'
end

function M.render_windows_program(program, args)
    args = args or {}

    local values = { M.quote(program) }
    for _, arg in ipairs(args) do
        table.insert(values, M.quote(arg))
    end

    return table.concat(values, " ")
end

function M.windows_program_command(program, args)
    args = args or {}

    local command = { "&", M.powershell_quote(program) }
    for _, arg in ipairs(args) do
        command[#command + 1] = M.powershell_quote(arg)
    end

    local script = table.concat(command, " ") .. "; exit $LASTEXITCODE"

    return table.concat({
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-EncodedCommand",
        powershell_encoded_command(script),
    }, " ")
end

function M.powershell_command(script)
    return table.concat({
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-EncodedCommand",
        powershell_encoded_command(script),
    }, " ")
end

function M.execute_command(command, success_codes)
    local codes = normalize_success_codes(success_codes)
    local first, kind, code = os.execute(command)

    if first == true then
        return true, 0
    end

    if type(first) == "number" then
        return codes[first] == true, first
    end

    if kind == "exit" and type(code) == "number" then
        return codes[code] == true, code
    end

    return false, code or first or kind or "unknown"
end

function M.execute_windows_program(program, args, success_codes)
    return M.execute_command(M.windows_program_command(program, args), success_codes)
end

function M.execute_powershell(script, success_codes)
    return M.execute_command(M.powershell_command(script), success_codes)
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
    return M.exists(M.join_path(path, "VC", "Auxiliary", "Build", "vcvarsall.bat"))
        and M.exists(M.join_path(path, "Common7", "Tools", "VsDevCmd.bat"))
end

return M
