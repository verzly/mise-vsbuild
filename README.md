# verzly/mise-vsbuild

`verzly/mise-vsbuild` is a [jdx/mise](https://github.com/jdx/mise) plugin for installing and managing Visual Studio Build Tools on Windows.

It provides a mise-managed wrapper around Microsoft Visual Studio Build Tools, with support for:

- **Visual Studio Build Tools current channel** through `Microsoft.VisualStudio.BuildTools`
- **Visual Studio Build Tools 2026, 2022, 2019, and 2017**
- **Automatic WinGet discovery** for future `Microsoft.VisualStudio.*.BuildTools` package IDs
- **Future year fallback** such as `vsbuild@2028` when Microsoft publishes a matching WinGet package
- **C++ workload installation** through `Microsoft.VisualStudio.Workload.VCTools`
- **Custom install paths** under the mise install directory
- **Helper commands** for `vcvars64`, Visual Studio developer shells, `cl`, CMake, update, uninstall, and discovery

The plugin is designed for projects that occasionally need MSVC without requiring Visual Studio IDE usage, such as Python native packages, `llama.cpp`, PyTorch-adjacent builds, Android/Tauri dependencies, or other native Windows build steps.

- [How it works](#how-does-it-work)
  - [Windows only](#windows-only)
  - [Automatic discovery](#automatic-discovery)
  - [Install path](#install-path)
  - [System components](#system-components)
  - [Uninstall behavior](#uninstall-behavior)
- [Get started](#get-started)
  - [Install mise](#get-started)
  - [Activate mise](#get-started)
  - [Install plugin](#get-started)
  - [Upgrade](#up-to-date)
- [Usage](#usage)
  - [Visual Studio Build Tools](#visual-studio-build-tools)
  - [Helper commands](#helper-commands)
  - [Running commands inside MSVC environment](#running-commands-inside-msvc-environment)
  - [Custom workloads and components](#custom-workloads-and-components)
  - [Install method](#install-method)
  - [Future versions](#future-versions)
  - [Uninstall](#uninstall)
- [Debugging](#debugging)
- [Known Issues](#known-issues)
- [Contributing](#contributing)
- [License & Acknowledgments](#license--acknowledgments)

Read on to learn why `verzly/mise-vsbuild` was created and what makes it work the way it does. Or jump straight to [Get started](#get-started) for quick installation steps.

## How does it work?

`verzly/mise-vsbuild` uses mise's Lua tool plugin hooks to expose Visual Studio Build Tools as a mise-managed tool named `vsbuild`.

During installation, the plugin asks Microsoft Visual Studio Installer to install into the mise install path for the selected version, for example:

```text
%MISE_DATA_DIR%\installs\vsbuild\2022
```

The default workload is:

```text
Microsoft.VisualStudio.Workload.VCTools
```

By default, recommended components are included. This usually provides the MSVC x64/x86 toolchain, Windows SDK, C++ CMake tools, and related native build tooling expected by Python packages, CMake projects, and Windows-native build systems.

### Windows only

This plugin intentionally supports Windows only. Visual Studio Build Tools are Windows system components and cannot be installed on Linux or macOS.

For Linux/macOS C++ toolchains, use system package managers or separate mise-managed tools such as `cmake`, `ninja`, `llvm`, or language-specific toolchains.

### Automatic discovery

Known release lines are built into the plugin:

```text
current, 2026, 2022, 2019, 2017
```

On Windows, when `winget` is available, `mise ls-remote vsbuild` also tries to discover Visual Studio Build Tools packages from WinGet by scanning for package IDs matching:

```text
Microsoft.VisualStudio.BuildTools
Microsoft.VisualStudio.<YEAR>.BuildTools
```

This means future package IDs such as the following can appear without releasing a new plugin version, once Microsoft publishes them through WinGet:

```text
Microsoft.VisualStudio.2028.BuildTools
Microsoft.VisualStudio.2030.BuildTools
```

Discovery can be disabled when you need deterministic offline behavior:

```powershell
$env:VSBUILD_DISABLE_DISCOVERY = '1'
```

The `latest`, `stable`, and `current` aliases resolve to the generic current-channel WinGet package:

```text
Microsoft.VisualStudio.BuildTools
```

That makes `vsbuild@latest` future-facing by design. It is not hardcoded to a fixed year.

### Install path

The plugin passes `--installPath` to Visual Studio Installer. If your mise data directory is on a large drive, Visual Studio Build Tools can be installed there.

Example:

```powershell
[Environment]::SetEnvironmentVariable('MISE_DATA_DIR', 'D:\program\mise', 'User')
```

After opening a new terminal, installing `vsbuild@2022` will target a path similar to:

```text
D:\program\mise\installs\vsbuild\2022
```

For the current channel:

```text
D:\program\mise\installs\vsbuild\current
```

### System components

Visual Studio Build Tools are not fully portable. Even when the main instance is installed into the mise install path, Microsoft installers may still create registry entries and install shared components, Windows SDK files, installer cache files, or runtime components outside that directory.

This is expected Windows behavior. The plugin manages the selected Build Tools instance path, but it cannot make Visual Studio Build Tools a completely portable tool.

### Uninstall behavior

The plugin provides a `vsbuild-uninstall` helper command that calls Visual Studio Installer with the instance install path. Use that before deleting the mise install directory.

`mise uninstall vsbuild@2022` may remove the mise directory, but mise's currently documented tool plugin hooks do not provide a Visual Studio-specific uninstall lifecycle hook. Because of that, `vsbuild-uninstall` is the safe path for removing the Microsoft-registered Build Tools instance.

## Get started

> [!IMPORTANT]
> The plugin requires a [jdx/mise](https://github.com/jdx/mise) installation.
>
> ```sh
> # Windows
> winget install jdx.mise
> ```
>
> Activation in your shell profile is required for global use and for registering commands.
>
> ```powershell
> (&mise activate pwsh) | Out-String | Invoke-Expression
> ```

To install Visual Studio Build Tools using the plugin, first install the plugin:

```sh
mise plugin install vsbuild https://github.com/verzly/mise-vsbuild#latest
```

For local development before publishing:

```sh
mise plugin link vsbuild /path/to/verzly/mise-vsbuild
```

Then install/select a Build Tools version:

```sh
# Install/select the Microsoft current channel
mise use -g vsbuild@latest

# Or install/select explicitly
mise use -g vsbuild@current
mise use -g vsbuild@2026
mise use -g vsbuild@2022
```

> [!TIP]
> If you want Visual Studio Build Tools to install on a large drive, configure `MISE_DATA_DIR` before running `mise install`.
>
> ```powershell
> [Environment]::SetEnvironmentVariable('MISE_DATA_DIR', 'D:\program\mise', 'User')
> ```
>
> Open a new terminal after changing user environment variables.

### Up-to-date

Plugin updates can be installed with:

```sh
mise plugin upgrade vsbuild
mise plugin upgrade vsbuild#latest
```

To update the installed Visual Studio Build Tools instance itself:

```sh
vsbuild-update
```

## Usage

After installing the plugin, mise enables installation of packages named `vsbuild` through this plugin.

### Visual Studio Build Tools

```sh
# Check available Build Tools release lines and discovered WinGet packages
mise ls-remote vsbuild

# Check installed versions
mise ls vsbuild

# Install latest/current Visual Studio Build Tools channel
mise install vsbuild@latest
mise install vsbuild@current

# Install specific known release lines
mise install vsbuild@2026
mise install vsbuild@26
mise install vsbuild@2022
mise install vsbuild@2019
mise install vsbuild@2017

# Attempt a future year-specific package once Microsoft publishes it
mise install vsbuild@2028

# Use globally
mise use -g vsbuild@current

# Use per project
cd /path/to/project
mise use vsbuild@2022
```

Version aliases:

| Alias | Resolves to |
|---|---|
| `latest` | `current` |
| `stable` | `current` |
| `current` | `current` |
| `18` / `26` | `2026` |
| `17` / `22` | `2022` |
| `16` / `19` | `2019` |
| `15` | `2017` |

### Helper commands

When `vsbuild` is active, the plugin adds the installed helper directory to `PATH`.

```sh
vsbuild-info
vsbuild-list
vsbuild-shell
vsbuild-run where cl
vsbuild-cl /?
vsbuild-cmake --version
vsbuild-update
vsbuild-uninstall
```

The helpers are intentionally prefixed with `vsbuild-` to avoid overriding system tools globally.

### Running commands inside MSVC environment

To run a single command with `vcvars64.bat` loaded:

```sh
vsbuild-run where cl
vsbuild-run cl /?
vsbuild-run cmake --version
```

To open a command prompt with the x64 MSVC environment loaded:

```sh
vsbuild-shell
```

Direct `cl.exe` discovery by build tools is sometimes sensitive to whether the caller expects `cl.exe` specifically or accepts a wrapper. For CMake or complex builds, prefer either `vsbuild-run` or a shell opened by `vsbuild-shell`.

### Custom workloads and components

By default, the plugin installs:

```text
Microsoft.VisualStudio.Workload.VCTools
```

Recommended components are included by default. You can override workloads and components using environment variables or mise plugin options.

Environment variable example:

```powershell
$env:VSBUILD_WORKLOADS = 'Microsoft.VisualStudio.Workload.VCTools'
$env:VSBUILD_COMPONENTS = 'Microsoft.VisualStudio.Component.VC.CMake.Project,Microsoft.VisualStudio.Component.Windows11SDK.26100'
$env:VSBUILD_INCLUDE_OPTIONAL = '1'
mise install vsbuild@2022
```

Plugin option example in `mise.toml`:

```toml
[tools]
vsbuild = "2022"

[settings.vsbuild]
workloads = "Microsoft.VisualStudio.Workload.VCTools"
components = "Microsoft.VisualStudio.Component.VC.CMake.Project"
include_recommended = true
include_optional = false
```

To disable recommended components:

```powershell
$env:VSBUILD_NO_RECOMMENDED = '1'
mise install vsbuild@2022
```

### Install method

The default install method is WinGet:

```powershell
$env:VSBUILD_INSTALL_METHOD = 'winget'
```

Known release lines can also use direct bootstrapper URLs:

```powershell
$env:VSBUILD_INSTALL_METHOD = 'direct'
mise install vsbuild@2022
```

Future inferred release lines use WinGet by default. If Microsoft publishes a bootstrapper URL before the plugin knows about it, provide an override:

```powershell
$env:VSBUILD_INSTALL_METHOD = 'direct'
$env:VSBUILD_BOOTSTRAPPER_URL = 'https://aka.ms/vs/XX/release/vs_BuildTools.exe'
mise install vsbuild@2028
```

### Future versions

`vsbuild@latest` and `vsbuild@current` are the preferred future-proof names because they use Microsoft’s generic current-channel package:

```sh
mise install vsbuild@latest
```

Explicit future years are also supported as an inferred fallback:

```sh
mise install vsbuild@2028
```

That resolves to:

```text
Microsoft.VisualStudio.2028.BuildTools
```

If Microsoft has not published that package ID, WinGet will fail clearly. Once Microsoft publishes it, the plugin should not need a code change.

To inspect what WinGet currently exposes:

```sh
vsbuild-list
```

Or directly:

```powershell
winget search --source winget --id Microsoft.VisualStudio --accept-source-agreements
```

### Uninstall

Use the helper first:

```sh
vsbuild-uninstall
```

Then remove the mise install entry if needed:

```sh
mise uninstall vsbuild@2022
```

For the current channel:

```sh
vsbuild-uninstall
mise uninstall vsbuild@current
```

## Debugging

Enable verbose plugin output:

```powershell
$env:VSBUILD_VERBOSE = '1'
mise install vsbuild@2022
```

Check available package discovery:

```sh
mise ls-remote vsbuild
vsbuild-list
```

Check the active toolchain:

```sh
vsbuild-info
vsbuild-run where cl
vsbuild-run cl /?
vsbuild-run cmake --version
```

Check the install path:

```powershell
$env:VSBUILD_HOME
$env:VSBUILD_INSTALL_PATH
```

Disable discovery for deterministic behavior:

```powershell
$env:VSBUILD_DISABLE_DISCOVERY = '1'
mise ls-remote vsbuild
```

## Known Issues

Visual Studio Build Tools are system components. The plugin can place the main instance under the mise install path, but it cannot make Visual Studio Build Tools fully portable.

Admin permissions may be required during installation, update, or uninstall.

If a future explicit year such as `vsbuild@2028` fails, check whether Microsoft has published a matching WinGet package ID. Use `vsbuild@latest` / `vsbuild@current` when you want the Microsoft current channel instead of a year-specific line.

Some installers may return `3010`, which means installation completed but a restart is required. The plugin treats this as a successful install.

## Contributing

Pull requests are welcome. Keep the plugin Windows-only unless Visual Studio Build Tools become available on other platforms.

Useful local development commands:

```sh
mise plugin link vsbuild .
mise ls-remote vsbuild
mise install vsbuild@current --verbose
mise install vsbuild@2022 --verbose
```

## License & Acknowledgments

This project is licensed under the AGPL-3.0 License. See [`LICENSE`](./LICENSE) for details.

Acknowledgments:

- [jdx/mise](https://github.com/jdx/mise) for the runtime and plugin system
- Microsoft Visual Studio Build Tools for the Windows C++ toolchain
- WinGet for package discovery and bootstrap installation
