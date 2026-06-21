# verzly/mise-vsbuild

`verzly/mise-vsbuild` is a [jdx/mise](https://github.com/jdx/mise) plugin for installing and managing Visual Studio Build Tools on Windows.

It provides a mise-managed wrapper around Microsoft Visual Studio Build Tools, with support for:

- **Visual Studio Build Tools current channel** through `Microsoft.VisualStudio.BuildTools`
- **Visual Studio Build Tools 2026, 2022, 2019, and 2017**
- **Automatic WinGet discovery** for future `Microsoft.VisualStudio.*.BuildTools` package IDs
- **Future year fallback** such as `vsbuild@2028` when Microsoft publishes a matching WinGet package
- **C++ workload installation** through `Microsoft.VisualStudio.Workload.VCTools`
- **Custom install paths** under the mise install directory
- **Generated helper commands** for `vcvars64`, Visual Studio developer shells, `cl`, CMake, update, uninstall, and discovery

The plugin is designed for projects that occasionally need MSVC without requiring Visual Studio IDE usage, such as Python native packages, `llama.cpp`, PyTorch-adjacent builds, Android/Tauri dependencies, or other native Windows build steps.

- [How it works](#how-does-it-work)
  - [Lua-first plugin design](#lua-first-plugin-design)
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
- [Testing](#testing)
- [Release management](#release-management)
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

### Lua-first plugin design

The plugin intentionally keeps the implementation in Lua, following the same style as `mise-php`:

```text
hooks/available.lua
hooks/pre_install.lua
hooks/post_install.lua
hooks/env_keys.lua
hooks/mise_env.lua
lib/env.lua
lib/messages.lua
lib/options.lua
lib/versions.lua
lib/system.lua
lib/install.lua
lib/helpers.lua
```

PowerShell scripts are not required for the main install flow. Lua builds the Visual Studio Installer command, invokes `winget` or the direct bootstrapper, verifies the resulting instance, and writes small `.cmd` helper commands into the installed tool directory.

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

The plugin generates a `vsbuild-uninstall` helper command that calls Visual Studio Installer with the instance install path. Use that before deleting the mise install directory.

`mise uninstall vsbuild@2022` may remove the mise directory, but Visual Studio Installer should be used first so the Microsoft-registered Build Tools instance is removed cleanly.

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
mise install vsbuild@2022
mise install vsbuild@2019
mise install vsbuild@2017

# Select globally
mise use -g vsbuild@2022

# Select locally for the current project
mise use vsbuild@2022
```

`mise use vsbuild@2022` writes to the local `mise.toml`. `mise use -g vsbuild@2022` writes to the global mise config. A local project config can override the global default.

### Helper commands

After a version is installed and active, the plugin exposes generated helper commands through the mise shim/PATH mechanism:

```sh
vsbuild-info
vsbuild-list
vsbuild-run
vsbuild-shell
vsbuild-cl
vsbuild-cmake
vsdevcmd
vcvars64
vsbuild-update
vsbuild-uninstall
```

The plugin intentionally does not add MSVC compiler internals directly to the global `PATH`. `cl.exe` needs the full Visual Studio developer environment, including `INCLUDE`, `LIB`, `LIBPATH`, Windows SDK paths, and other variables. Use the helper commands instead.

### Running commands inside MSVC environment

```sh
vsbuild-run where cl
vsbuild-run cl
vsbuild-run cmake --version
vsbuild-run python -m pip install some-native-package
```

For an interactive shell:

```sh
vsbuild-shell
```

### Custom workloads and components

The default workload is:

```text
Microsoft.VisualStudio.Workload.VCTools
```

You can override workloads/components through mise config:

```toml
[env]
_.vsbuild = {
  workloads = "Microsoft.VisualStudio.Workload.VCTools",
  components = "Microsoft.VisualStudio.Component.VC.CMake.Project",
  include_recommended = true,
  include_optional = false
}
```

Or via CLI:

```sh
mise config set env._.vsbuild.components "Microsoft.VisualStudio.Component.VC.CMake.Project"
mise install vsbuild@2022
```

### Install method

The default install method is `winget`:

```toml
[env]
_.vsbuild = { install_method = "winget" }
```

Known versions can also use the direct Visual Studio bootstrapper:

```toml
[env]
_.vsbuild = { install_method = "direct" }
```

For future/custom channels, provide your own bootstrapper URL:

```toml
[env]
_.vsbuild = {
  install_method = "direct",
  bootstrapper_url = "https://example.com/vs_BuildTools.exe"
}
```

### Future versions

Explicit future years are inferred as WinGet package IDs:

```sh
mise install vsbuild@2028
```

This attempts to install:

```text
Microsoft.VisualStudio.2028.BuildTools
```

If Microsoft has not published that package ID, WinGet will fail clearly. `vsbuild@latest` and `vsbuild@current` use the generic current-channel package and are the preferred future-proof options.

### Uninstall

Use the generated helper first:

```sh
vsbuild-uninstall
```

Then remove the mise tool directory:

```sh
mise uninstall vsbuild@2022
```

## Debugging

Enable verbose plugin output:

```sh
VSBUILD_VERBOSE=1 mise install vsbuild@2022
```

Disable WinGet discovery:

```powershell
$env:VSBUILD_DISABLE_DISCOVERY = '1'
mise ls-remote vsbuild
```

Preview the generated install command:

```powershell
mise config set env._.vsbuild.dry_run true
mise install vsbuild@2022
```

## Testing

The repository includes static checks and mise smoke tests.

```sh
mise run static
mise run lua-syntax
mise run ls-remote
```

The CI workflow validates repository metadata, Lua file structure, README sections, release workflow files, version listing, and plugin option exports.

## Release management

The repository includes GitHub Actions workflows for tests, release publishing, and updating the `latest` reference.

The first project release starts at `0.1.0`. Future changes should follow Keep a Changelog grouping:

```text
Added
Changed
Removed
Fixed
Security
```

## Known Issues

Visual Studio Build Tools are not fully portable. Some shared Microsoft components, registry entries, installer metadata, SDK files, or caches may be written outside the mise install directory.

Visual Studio Installer may require elevation even when launched through mise. Run the terminal as Administrator if installation fails due to permissions.

Command-line quoting around `winget --override` is intentionally conservative. Prefer install paths without spaces for the mise data directory, such as `D:\program\mise`.

## Contributing

Keep most plugin behavior in Lua under `hooks/` and `lib/`. Generated `.cmd` helpers should remain small and should only bridge into the Visual Studio developer environment.

## License & Acknowledgments

This project is licensed under the GNU Affero General Public License v3.0.

Thanks to the [jdx/mise](https://github.com/jdx/mise) project and the `mise-php` plugin structure that inspired this repository layout.
