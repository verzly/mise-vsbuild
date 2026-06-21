local env = require("lib/env")
local helpers = require("lib/helpers")
local messages = require("lib/messages")
local system = require("lib/system")

local M = {}

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

local function append_vs_args(args, name, values)
    for _, value in ipairs(values) do
        table.insert(args, name)
        table.insert(args, value)
    end
end

local function override_arg(value)
    -- The override string is consumed by winget and then passed to the VS installer.
    -- Use quotes only when needed to keep normal component/workload IDs readable.
    value = tostring(value or "")
    if value:find("%s") then
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

local function join_command(parts)
    local values = {}
    for _, part in ipairs(parts) do
        table.insert(values, system.quote(part))
    end
    return table.concat(values, " ")
end

local function run(command)
    if env.VERBOSE then
        print("> " .. command)
    end

    local status = os.execute(command)
    if not system.cmd_status_ok(status) then
        error("Command failed: " .. command)
    end
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
    return "%TEMP%\\vs_BuildTools_" .. tostring(version) .. ".exe"
end

local function direct_download_command(url, target)
    return table.concat({
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        system.quote("Invoke-WebRequest -Uri " .. url .. " -OutFile " .. target),
    }, " ")
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

    local bootstrapper = env.BOOTSTRAPPER_URL
    if bootstrapper == "" then
        bootstrapper = release.bootstrapper or ""
    end

    messages.section("🧰 Visual Studio Build Tools Installer for mise")
    messages.step("version", "Visual Studio Build Tools " .. tostring(release.version))
    messages.step("path", install_path)

    system.mkdir(install_path)

    if system.test_vs_instance(install_path) then
        messages.step("existing", "valid Build Tools instance found, refreshing helper commands")
        helpers.install(install_path, release.version)
        return
    end

    local vs_args = make_vs_args(install_path, workloads, components, env.INCLUDE_RECOMMENDED, env.INCLUDE_OPTIONAL)
    local command

    if env.INSTALL_METHOD == "winget" then
        if release.winget == nil or release.winget == "" then
            error("WinGet install method requires a package ID.")
        end

        local override = make_override(vs_args)
        command = join_command({
            "winget",
            "install",
            "-e",
            "--id", release.winget,
            "--override", override,
            "--accept-package-agreements",
            "--accept-source-agreements",
        })
        messages.step("installer", "winget package " .. release.winget)
    elseif env.INSTALL_METHOD == "direct" then
        if bootstrapper == "" then
            error("Direct install method requires VSBUILD_BOOTSTRAPPER_URL for this release.")
        end

        local target = direct_bootstrapper_path(release.version)
        if not system.exists(target) then
            messages.step("download", target)
            run(direct_download_command(bootstrapper, target))
        end

        local parts = { target }
        for _, arg in ipairs(vs_args) do
            table.insert(parts, arg)
        end
        command = join_command(parts)
        messages.step("installer", "direct bootstrapper " .. bootstrapper)
    else
        error("Unsupported install method: " .. tostring(env.INSTALL_METHOD))
    end

    if env.DRY_RUN then
        write_dry_run({
            version = release.version,
            install_path = install_path,
            install_method = env.INSTALL_METHOD,
            command = command,
        })
        helpers.install(install_path, release.version)
        return
    end

    run(command)

    if not system.test_vs_instance(install_path) then
        error("Visual Studio Build Tools installation did not produce a usable instance at: " .. install_path)
    end

    helpers.install(install_path, release.version)
    messages.step("helpers", system.join_path(install_path, "bin"))
    print("  ────────────────────────────────────────────────────")
    print("  Visual Studio Build Tools installation complete")
    print("  Try: vsbuild-info")
    print("")
end

return M
