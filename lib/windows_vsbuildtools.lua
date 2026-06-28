local env = require("lib/env")
local helpers = require("lib/vsbuildtools_helpers")
local messages = require("lib/messages")
local system = require("lib/tools")

local M = {}

local INSTALL_SUCCESS_CODES = { 0, 1641, 3010 }
local MSVC_PROFILE_ID = "Microsoft.VisualStudio.Workload.VCTools"

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

local function make_vs_args(install_path)
    local args = {
        "--wait",
        "--quiet",
        "--norestart",
        "--installPath",
        install_path,
    }

    append_vs_args(args, "--add", { MSVC_PROFILE_ID })
    table.insert(args, "--includeRecommended")

    return args
end

local function make_override(args)
    local values = {}
    for _, arg in ipairs(args) do
        table.insert(values, override_arg(arg))
    end
    return table.concat(values, " ")
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

function M.install(release, install_path)
    if not system.is_windows() then
        error(messages.windows_only())
    end

    if release.winget == nil or release.winget == "" then
        error("Visual Studio Build Tools release has no WinGet package ID: " .. tostring(release.version))
    end

    if not system.command_exists("winget") then
        error("winget was not found. Install Windows Package Manager before installing Visual Studio Build Tools with this plugin.")
    end

    messages.section("Visual Studio Build Tools Installer for mise")
    messages.step("version", "Visual Studio Build Tools " .. tostring(release.version))
    messages.step("path", install_path)
    messages.step("installer", "winget package " .. release.winget)

    system.mkdir(install_path)

    if system.test_vs_instance(install_path) then
        messages.step("existing", "valid Build Tools instance found, refreshing helper commands")
        helpers.install(install_path, release.version)
        return
    end

    local vs_args = make_vs_args(install_path)
    local winget_args = {
        "install",
        "-e",
        "--id", release.winget,
        "--override", make_override(vs_args),
        "--accept-package-agreements",
        "--accept-source-agreements",
    }

    local code = run_windows_program("winget", winget_args, INSTALL_SUCCESS_CODES)
    if code == 1641 or code == 3010 then
        messages.warning("Visual Studio Installer completed successfully but Windows reported that a reboot is required.")
    end

    if not system.test_vs_instance(install_path) then
        error("Visual Studio Build Tools installation did not produce a usable instance at: " .. install_path)
    end

    helpers.install(install_path, release.version)
    messages.step("helpers", system.join_path(install_path, "bin"))
    print("  ----------------------------------------------------")
    print("  Visual Studio Build Tools installation complete")
    print("  Try: vsbuildtools-info")
    print("")
end

return M
