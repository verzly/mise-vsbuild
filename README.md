# verzly/mise-vsbuildtools

`verzly/mise-vsbuildtools` is a [jdx/mise](https://github.com/jdx/mise) plugin for installing and managing Microsoft Visual Studio Build Tools on Windows.

It provides a mise-managed wrapper around the Visual Studio Installer with support for:

- **Visual Studio Build Tools current channel** through `Microsoft.VisualStudio.BuildTools`
- **Visual Studio Build Tools 2026, 2022, 2019, and 2017**
- **Visual Studio 2015 v140 toolset compatibility** through current Build Tools
- **Automatic WinGet discovery** for future `Microsoft.VisualStudio.*.BuildTools` package IDs
- **Future year fallback** such as `vsbuildtools@2028` when Microsoft publishes a matching WinGet package
- **C++ workload installation** through `Microsoft.VisualStudio.Workload.VCTools`
- **Custom workloads/components** through `mise.toml` or `mise config set`
- **Generated helper commands** for `vcvarsall`, `vcvars64`, developer shells, `cl`, `msbuild`, CMake, update, uninstall, and discovery

The plugin is designed for projects that occasionally need MSVC without requiring the full Visual Studio IDE: Python native packages, Node/Rust/Tauri native dependencies, CMake projects, Android dependencies, `llama.cpp`, CI images, or other Windows-native build steps.

- [How it works](#how-does-it-work)
  - [Windows only](#windows-only)
  - [Visual Studio versions](#visual-studio-versions)
  - [Lua-first plugin design](#lua-first-plugin-design)
  - [Install path](#install-path)
  - [System components](#system-components)
  - [Helper commands](#helper-commands)
  - [Uninstall behavior](#uninstall-behavior)
- [Get started](#get-started)
  - [Install mise](#get-started)
  - [Activate mise](#get-started)
  - [Install plugin](#get-started)
  - [Upgrade](#up-to-date)
- [Usage](#usage)
  - [Visual Studio Build Tools](#visual-studio-build-tools)
  - [Running commands inside the MSVC environment](#running-commands-inside-the-msvc-environment)
  - [Architecture and toolset selection](#architecture-and-toolset-selection)
  - [Custom workloads and components](#custom-workloads-and-components)
  - [Install method](#install-method)
  - [Future versions](#future-versions)
  - [Uninstall](#uninstall)
- [Debugging](#debugging)
- [Known Issues](#known-issues)
- [Contributing](#contributing)

Read on to learn why `verzly/mise-vsbuildtools` was created and what makes it work the way it does. Or jump straight to [Get started](#get-started) for quick installation steps.

## How does it work?

`verzly/mise-vsbuildtools` uses mise's Lua tool plugin hooks to expose Visual Studio Build Tools as a mise-managed tool named `vsbuildtools`.

During installation, the plugin asks Microsoft Visual Studio Installer to install into the mise install path for the selected version, for example:

```text
%MISE_DATA_DIR%\installs\vsbuildtools\2026
```

The default workload is:

```text
Microsoft.VisualStudio.Workload.VCTools
```

By default, recommended components are included. This usually provides the MSVC x64/x86 toolchain, Windows SDK, C++ CMake tools, and related native build tooling expected by Python packages, CMake projects, and Windows-native build systems.

### Windows only

This plugin intentionally supports Windows only. Visual Studio Build Tools are Windows system components and cannot be installed on Linux or macOS.

For Linux/macOS C++ toolchains, use system package managers or separate mise-managed tools such as `cmake`, `ninja`, `llvm`, `rust`, or language-specific toolchains.

### Visual Studio versions

Known release lines are built into the plugin:

```text
current, 2026, 2022, 2019, 2017, 2015
```

`current`, `latest`, and `stable` resolve to Microsoft's current Visual Studio Build Tools WinGet package:

```text
Microsoft.VisualStudio.BuildTools
```

Visual Studio 2026 currently uses the generic current-channel package ID. Visual Studio 2022, 2019, and 2017 use year-specific WinGet package IDs:

```text
Microsoft.VisualStudio.2022.BuildTools
Microsoft.VisualStudio.2019.BuildTools
Microsoft.VisualStudio.2017.BuildTools
```

`vsbuildtools@2015` is a compatibility profile. It installs current Visual Studio Build Tools plus the v140 component:

```text
Microsoft.VisualStudio.Component.VC.140
```

The generated helper commands default `VSBUILDTOOLS_VCVARS_VER=14.0` for that profile. This is the practical modern route for legacy projects that need the Visual Studio 2015 C++ toolset while still using the current Visual Studio Installer infrastructure.

On Windows, when `winget` is available, `mise ls-remote vsbuildtools` also tries to discover Visual Studio Build Tools packages from WinGet by scanning for package IDs matching:

```text
Microsoft.VisualStudio.BuildTools
Microsoft.VisualStudio.<YEAR>.BuildTools
```

Discovery can be disabled when you need deterministic offline behavior:

```powershell
$env:VSBUILDTOOLS_DISABLE_DISCOVERY = '1'
```

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

PowerShell script files are not required for the main install flow. Lua builds the Visual Studio Installer command, invokes `winget` or the direct bootstrapper, verifies the resulting instance, and writes small `.cmd` helper commands into the installed tool directory.

### Install path

The plugin passes `--installPath` to Visual Studio Installer. If your mise data directory is on a large drive, Visual Studio Build Tools can be installed there.

Example:

```powershell
[Environment]::SetEnvironmentVariable('MISE_DATA_DIR', 'D:\program\mise', 'User')
```

After opening a new terminal, installing `vsbuildtools@2026` will target a path similar to:

```text
D:\program\mise\installs\vsbuildtools\2026
```

For the current channel:

```text
D:\program\mise\installs\vsbuildtools\current
```

### System components

Visual Studio Build Tools are not fully portable. Even when the main instance is installed into the mise install path, Microsoft installers may still create registry entries and install shared components, Windows SDK files, installer cache files, or runtime components outside that directory.

This is expected Windows behavior. The plugin manages the selected Build Tools instance path, but it cannot make Visual Studio Build Tools a completely portable tool.

### Helper commands

The plugin intentionally does not add MSVC compiler internals directly to the global `PATH`. `cl.exe` needs the full Visual Studio developer environment, including `INCLUDE`, `LIB`, `LIBPATH`, Windows SDK paths, and other variables.

Instead, each installed version gets a `bin` directory with small helper commands:

```text
vsbuildtools-info
vsbuildtools-list
vsbuildtools-run
vsbuildtools-shell
vsbuildtools-cl
vsbuildtools-cmake
vsbuildtools-msbuild
vsdevcmd
vcvarsall
vcvars64
vcvars32
vcvarsarm64
vsbuildtools-update
vsbuildtools-uninstall
```

### Uninstall behavior

The plugin generates a `vsbuildtools-uninstall` helper command that calls Visual Studio Installer with the instance install path. Use that before deleting the mise install directory.

`mise uninstall vsbuildtools@2026` may remove the mise directory, but Visual Studio Installer should be used first so the Microsoft-registered Build Tools instance is removed cleanly.

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
# NOTE: If you are not contributing and want stable releases, use the `#latest` suffix
# to avoid tracking the development branch.
mise plugin install vsbuildtools https://github.com/verzly/mise-vsbuildtools#latest
```

For local development before publishing:

```sh
mise plugin link vsbuildtools /path/to/verzly/mise-vsbuildtools
```

Then install/select a Build Tools version:

```sh
# Install/select the Microsoft current channel
mise use -g vsbuildtools@latest

# Or install/select explicitly
mise use -g vsbuildtools@current
mise use -g vsbuildtools@2026
mise use -g vsbuildtools@2022
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
# Upgrade plugin, following the originally installed target
mise plugin upgrade vsbuildtools

# Upgrade plugin to the latest release tag
mise plugin upgrade vsbuildtools#latest

# Upgrade plugin to a specific release tag
mise plugin upgrade vsbuildtools#v0.1.0
```

To update the installed Visual Studio Build Tools instance itself:

```sh
vsbuildtools-update
```

## Usage

After installing the plugin, mise enables installation of packages named `vsbuildtools` through this plugin.

### Visual Studio Build Tools

```sh
# Check available Build Tools release lines and discovered WinGet packages
mise ls-remote vsbuildtools

# Check installed versions
mise ls vsbuildtools

# Install latest/current Visual Studio Build Tools channel
mise install vsbuildtools@latest
mise install vsbuildtools@current

# Install specific known release lines
mise install vsbuildtools@2026
mise install vsbuildtools@2022
mise install vsbuildtools@2019
mise install vsbuildtools@2017

# Install the Visual Studio 2015 v140 toolset compatibility profile
mise install vsbuildtools@2015

# Select globally
mise use -g vsbuildtools@2026

# Select locally for the current project
mise use vsbuildtools@2022
```

`mise use vsbuildtools@2022` writes to the local `mise.toml`. `mise use -g vsbuildtools@2022` writes to the global mise config. A local project config can override the global default.

### Running commands inside the MSVC environment

```sh
vsbuildtools-run where cl
vsbuildtools-run cl
vsbuildtools-run msbuild -version
vsbuildtools-run cmake --version
vsbuildtools-run python -m pip install some-native-package
```

For an interactive shell:

```sh
vsbuildtools-shell
```

Direct helper shortcuts are also available:

```sh
vsbuildtools-cl /?
vsbuildtools-msbuild -version
vsbuildtools-cmake --version
```

### Architecture and toolset selection

Generated helpers default to x64. Override the target architecture with `VSBUILDTOOLS_ARCH`:

```powershell
$env:VSBUILDTOOLS_ARCH = 'x86'
vsbuildtools-run cl
```

Common values accepted by `vcvarsall.bat` include `x86`, `x64`, `arm64`, `x86_amd64`, and `amd64_arm64`, depending on the installed components.

To select a specific MSVC toolset version, set `vcvars_ver` in mise config:

```toml
[env]
_.vsbuildtools = { vcvars_ver = "14.29" }
```

Or via CLI:

```sh
mise config set env._.vsbuildtools.vcvars_ver "14.29"
```

The `vsbuildtools@2015` compatibility profile sets `14.0` automatically.

### Custom workloads and components

The default workload is:

```text
Microsoft.VisualStudio.Workload.VCTools
```

You can override workloads/components through mise config:

```toml
[env]
_.vsbuildtools = {
  workloads = "Microsoft.VisualStudio.Workload.VCTools",
  components = "Microsoft.VisualStudio.Component.VC.CMake.Project",
  include_recommended = true,
  include_optional = false
}
```

Or via CLI:

```sh
mise config set env._.vsbuildtools.components "Microsoft.VisualStudio.Component.VC.CMake.Project"
mise install vsbuildtools@2026
```

Multiple workloads/components can be separated with commas or semicolons:

```sh
mise config set env._.vsbuildtools.components "Microsoft.VisualStudio.Component.VC.CMake.Project;Microsoft.VisualStudio.Component.VC.140"
```

### Install method

The default install method is `winget`:

```toml
[env]
_.vsbuildtools = { install_method = "winget" }
```

Known versions can also use the direct Visual Studio bootstrapper:

```toml
[env]
_.vsbuildtools = { install_method = "direct" }
```

For future/custom channels, provide your own bootstrapper URL:

```toml
[env]
_.vsbuildtools = {
  install_method = "direct",
  bootstrapper_url = "https://example.com/vs_BuildTools.exe"
}
```

### Future versions

Explicit future years are inferred as WinGet package IDs:

```sh
mise install vsbuildtools@2028
```

This attempts to install:

```text
Microsoft.VisualStudio.2028.BuildTools
```

If Microsoft has not published that package ID, WinGet will fail clearly. `vsbuildtools@latest` and `vsbuildtools@current` use the generic current-channel package and are the preferred future-proof options.

### Uninstall

Use the generated helper first:

```sh
vsbuildtools-uninstall
```

Then remove the mise tool directory:

```sh
mise uninstall vsbuildtools@2026
```

## Debugging

Enable verbose plugin output:

```sh
VSBUILDTOOLS_VERBOSE=1 mise install vsbuildtools@2026
```

Disable WinGet discovery:

```powershell
$env:VSBUILDTOOLS_DISABLE_DISCOVERY = '1'
mise ls-remote vsbuildtools
```

Preview the generated install command:

```powershell
mise config set env._.vsbuildtools.dry_run true
mise install vsbuildtools@2026
```

Common Visual Studio Installer exit codes include `740` for elevation required, `1618` for another installation running, and `3010` for success with reboot required. Visual Studio installation logs are usually written to `%TEMP%` with names starting with `dd_bootstrapper`, `dd_client`, or `dd_setup`.

## Known Issues

Visual Studio Build Tools are not fully portable. Some shared Microsoft components, registry entries, installer metadata, SDK files, or caches may be written outside the mise install directory.

Visual Studio Installer may require elevation even when launched through mise. Run the terminal as Administrator if installation fails due to permissions.

The `vsbuildtools@2015` profile is not the legacy standalone Microsoft Build Tools 2015 installer. It installs the v140 C++ toolset as a component of current Visual Studio Build Tools so it can keep using the same Visual Studio Installer lifecycle as the rest of the plugin.

## Contributing

Keep most plugin behavior in Lua under `hooks/` and `lib/`. Generated `.cmd` helpers should remain small and should only bridge into the Visual Studio developer environment.

Before opening a pull request, test the affected install path on Windows with the Visual Studio Build Tools version you changed. For documentation-only changes, keep examples consistent with the `vsbuildtools` tool name and the `env._.vsbuildtools` configuration table.

## License & Acknowledgments

This project is licensed under the GNU Affero General Public License v3.0.

Thanks to the [jdx/mise](https://github.com/jdx/mise) project and the `mise-php` plugin structure that inspired this repository layout.
