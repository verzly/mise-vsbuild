local env = require("lib/env")
local helpers = require("lib/helpers")
local messages = require("lib/messages")
local system = require("lib/system")

local M = {}

local INSTALL_SUCCESS_CODES = { 0, 1641, 3010 }

local function split_list(value)
    local result = {}
    value = tostring(value or "")
    for item in value:gmatch("[^,;]+") do
        item = item:gsub("^%s+", ""):gsub("%s+$", "")
        if item ~= "" then
            table.insert(result, item)
        end
    end
    return result
end

local function append_unique(target, values)
    local seen = {}
    for _, value in ipairs(target) do
        seen[value] = true
    end

    for _, value in ipairs(values or {}) do
        if value ~= nil and value ~= "" and not seen[value] then
            table.insert(target, value)
            seen[value] = true
        end
    end
end

local function append_vs_args(args, name, values)
    for _, value in ipairs(values) do
        table.insert(args, name)
        table.insert(args, value)
    end
end

local function override_arg(value)
    value = tostring(value or "")
    if value:find('%s') then
        return '"' .. value:gsub('"', '\\"') .. '"'
    end
    return value
end

local function make_vs_args(install_path, workloads, components, include_recommended, include_optional)
    local args = {
        "--wait",
        "--quiet",
        "--norestart",
        "--installPath",
        install_path,
    }

    append_vs_args(args, "--add", workloads)
    append_vs_args(args, "--add", components)

    if include_recommended then
        table.insert(args, "--includeRecommended")
    end

    if include_optional then
        table.insert(args, "--includeOptional")
    end

    return args
end

local function make_override(args)
    local values = {}
    for _, arg in ipairs(args) do
        table.insert(values, override_arg(arg))
    end
    return table.concat(values, " ")
end

local function run_command(command, success_codes)
    if env.VERBOSE then
        print("> " .. command)
    end

    local ok, code = system.execute_command(command, success_codes)
    if not ok then
        error("Command failed with exit code " .. tostring(code) .. ": " .. command)
    end

    return code
end

local function run_windows_program(program, args, success_codes)
    local command = system.windows_program_command(program, args)
    if env.VERBOSE then
        print("> " .. system.render_windows_program(program, args))
    end

    local ok, code = system.execute_command(command, success_codes)
    if not ok then
        error("Command failed with exit code " .. tostring(code) .. ": " .. system.render_windows_program(program, args))
    end

    return code
end

local function write_dry_run(plan)
    messages.section("Visual Studio Build Tools Installer for mise")
    messages.step("dry-run", "installation command preview")
    messages.step("version", plan.version)
    messages.step("path", plan.install_path)
    messages.step("installer", plan.install_method)
    print(plan.command)
end

local function direct_bootstrapper_path(version)
    return system.join_path(system.temp_dir(), "vs_BuildTools_" .. tostring(version) .. ".exe")
end

local function direct_download_command(url, target)
    local script = table.concat({
        "$ErrorActionPreference = 'Stop'",
        "try { Invoke-WebRequest -Uri " .. system.powershell_quote(url) .. " -OutFile " .. system.powershell_quote(target) .. "; exit 0 }",
        "catch { Write-Error $_; exit 1 }",
    }, "; ")

    return system.powershell_command(script)
end

local function install_method()
    return tostring(env.INSTALL_METHOD or "winget"):lower()
end

function M.install(release, install_path)
    if not system.is_windows() then
        error(messages.windows_only())
    end

    local workloads = split_list(env.WORKLOADS)
    local components = split_list(env.COMPONENTS)

    if #workloads == 0 and #components == 0 then
        table.insert(workloads, "Microsoft.VisualStudio.Workload.VCTools")
    end

    append_unique(components, release.default_components or {})

    local bootstrapper = env.BOOTSTRAPPER_URL
    if bootstrapper == "" then
        bootstrapper = release.bootstrapper or ""
    end

    local method = install_method()

    messages.section("Visual Studio Build Tools Installer for mise")
    messages.step("version", "Visual Studio Build Tools " .. tostring(release.version))
    messages.step("path", install_path)

    if release.vcvars_ver ~= nil and release.vcvars_ver ~= "" then
        messages.step("toolset", "MSVC " .. tostring(release.vcvars_ver))
    end

    system.mkdir(install_path)

    if system.test_vs_instance(install_path) then
        messages.step("existing", "valid Build Tools instance found, refreshing helper commands")
        helpers.install(install_path, release.version, release.vcvars_ver)
        return
    end

    local vs_args = make_vs_args(install_path, workloads, components, env.INCLUDE_RECOMMENDED, env.INCLUDE_OPTIONAL)
    local command_preview
    local execute

    if method == "winget" then
        if release.winget == nil or release.winget == "" then
            error("WinGet install method requires a package ID.")
        end

        if not system.command_exists("winget") then
            error("winget was not found. Install Windows Package Manager or set VSBUILDTOOLS_INSTALL_METHOD=direct.")
        end

        local override = make_override(vs_args)
        local winget_args = {
            "install",
            "-e",
            "--id", release.winget,
            "--override", override,
            "--accept-package-agreements",
            "--accept-source-agreements",
        }

        command_preview = system.render_windows_program("winget", winget_args)
        execute = function()
            return run_windows_program("winget", winget_args, INSTALL_SUCCESS_CODES)
        end
        messages.step("installer", "winget package " .. release.winget)
    elseif method == "direct" then
        if bootstrapper == "" then
            error("Direct install method requires VSBUILDTOOLS_BOOTSTRAPPER_URL for this release.")
        end

        local target = direct_bootstrapper_path(release.version)
        if not system.exists(target) then
            messages.step("download", target)
            local download_command = direct_download_command(bootstrapper, target)
            if env.DRY_RUN then
                command_preview = download_command .. "\n" .. system.render_windows_program(target, vs_args)
            else
                run_command(download_command)
            end
        end

        command_preview = command_preview or system.render_windows_program(target, vs_args)
        execute = function()
            return run_windows_program(target, vs_args, INSTALL_SUCCESS_CODES)
        end
        messages.step("installer", "direct bootstrapper " .. bootstrapper)
    else
        error("Unsupported install method: " .. tostring(env.INSTALL_METHOD))
    end

    if env.DRY_RUN then
        write_dry_run({
            version = release.version,
            install_path = install_path,
            install_method = method,
            command = command_preview,
        })
        helpers.install(install_path, release.version, release.vcvars_ver)
        return
    end

    local code = execute()
    if code == 1641 or code == 3010 then
        messages.warning("Visual Studio Installer completed successfully but Windows reported that a reboot is required.")
    end

    if not system.test_vs_instance(install_path) then
        error("Visual Studio Build Tools installation did not produce a usable instance at: " .. install_path)
    end

    helpers.install(install_path, release.version, release.vcvars_ver)
    messages.step("helpers", system.join_path(install_path, "bin"))
    print("  ----------------------------------------------------")
    print("  Visual Studio Build Tools installation complete")
    print("  Try: vsbuildtools-info")
    print("")
end

return M
