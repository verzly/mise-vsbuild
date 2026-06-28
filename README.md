# verzly/mise-vsbuildtools

`verzly/mise-vsbuildtools` is a [jdx/mise](https://github.com/jdx/mise) plugin for installing and managing Microsoft Visual Studio Build Tools on Windows.

It provides a small, opinionated MSVC toolchain plugin for projects that need Visual Studio Build Tools without manually configuring the Visual Studio Installer. The plugin installs through WinGet, targets the mise install directory when Visual Studio supports `--installPath`, and exposes safe helper commands for running tools inside the Visual Studio developer environment.

Supported release lines:

- `current`, `latest`, `stable` - Microsoft current Build Tools channel
- `2026` - Visual Studio 2026 Build Tools
- `2022` - Visual Studio 2022 Build Tools
- `2019` - Visual Studio 2019 Build Tools
- `2017` - Visual Studio 2017 Build Tools
- future `YYYY` versions when Microsoft publishes a matching `Microsoft.VisualStudio.<YYYY>.BuildTools` WinGet package

The plugin intentionally keeps configuration minimal. There is no install-method switch, no custom installer profile option, no dry-run mode, and no `vcvars_ver` option. The installer profile is fixed so the plugin remains predictable, audit-friendly, and supportable.

- [How it works](#how-it-works)
  - [WinGet only](#winget-only)
  - [Install profile](#install-profile)
  - [Install path](#install-path)
  - [System files](#system-files)
  - [Helper commands](#helper-commands)
- [Get started](#get-started)
  - [Install mise](#get-started)
  - [Activate mise](#get-started)
  - [Install plugin](#get-started)
  - [Upgrade](#up-to-date)
- [Usage](#usage)
  - [Visual Studio Build Tools](#visual-studio-build-tools)
  - [Running commands inside the MSVC environment](#running-commands-inside-the-msvc-environment)
  - [Architecture selection](#architecture-selection)
  - [Uninstall](#uninstall)
- [Debugging](#debugging)
- [Known Issues](#known-issues)
- [Contributing](#contributing)

## How it works

The plugin is designed around one supported installation path: install Visual Studio Build Tools with WinGet, pass a fixed Visual Studio Installer profile through `--override`, verify the installed instance, and generate small `.cmd` helpers into the selected mise install directory.

The main implementation lives in:

```text
metadata.lua
hooks/available.lua
hooks/pre_install.lua
hooks/post_install.lua
hooks/env_keys.lua
hooks/mise_env.lua
lib/env.lua
lib/messages.lua
lib/options.lua
lib/tools.lua
lib/vsbuildtools_versions.lua
lib/vsbuildtools_helpers.lua
lib/windows_vsbuildtools.lua
```

PowerShell script files are not required for the main install flow. Lua builds the WinGet command, passes Visual Studio Installer arguments safely, verifies the resulting instance, and writes helper commands into the installed tool directory.

### WinGet only

The plugin always installs with WinGet. This keeps the install path predictable and avoids maintaining multiple installer backends.

Internally, the plugin runs a command equivalent to:

```powershell
winget install -e --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --quiet --norestart --installPath <mise-install-path> <fixed-msvc-profile>" --accept-package-agreements --accept-source-agreements
```

The exact package ID depends on the requested version.

### Install profile

The plugin installs a fixed MSVC Build Tools profile. This is intentionally not user-configurable.

Custom Visual Studio Installer profiles are powerful, but they turn a version manager plugin into a general Visual Studio Installer wrapper. That makes the behavior harder to review, harder to document, and easier to misuse. This plugin focuses on the MSVC Build Tools toolchain profile needed by native builds, Node/Python/Rust packages with native dependencies, Tauri projects, CMake, MSBuild, and similar Windows build workflows.

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

### System files

Visual Studio Build Tools are not fully portable. Even when the main instance is installed into the mise install path, Microsoft installers may still create registry entries and install shared files, Windows SDK files, installer cache files, or runtime files outside that directory.

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

### Architecture selection

Generated helpers default to x64. Override the target architecture with `VSBUILDTOOLS_ARCH`:

```powershell
$env:VSBUILDTOOLS_ARCH = 'x86'
vsbuildtools-run cl
```

Common values accepted by `vcvarsall.bat` include `x86`, `x64`, `arm64`, `x86_amd64`, and `amd64_arm64`, depending on the installed tools.

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

Common Visual Studio Installer exit codes include `740` for elevation required, `1618` for another installation running, and `3010` for success with reboot required. Visual Studio installation logs are usually written to `%TEMP%` with names starting with `dd_bootstrapper`, `dd_client`, or `dd_setup`.

## Known Issues

Visual Studio Build Tools are not fully portable. Some shared Microsoft files, registry entries, installer metadata, SDK files, or caches may be written outside the mise install directory.

Visual Studio Installer may require elevation even when launched through mise. Run the terminal as Administrator if installation fails due to permissions.

The plugin does not expose custom Visual Studio Installer profile configuration. That is intentional. The maintained install profile is the fixed MSVC Build Tools profile.

The legacy `Microsoft.BuildTools2015` WinGet package is not treated as a `vsbuildtools@2015` version because it is not the same install model as modern Visual Studio Build Tools and does not provide the same mise-managed instance layout.

## Contributing

Keep most plugin behavior in Lua under `hooks/` and `lib/`. Generated `.cmd` helpers should remain small and should only bridge into the Visual Studio developer environment.

Before opening a pull request, test the affected install path on Windows with the Visual Studio Build Tools version you changed. For documentation-only changes, keep examples consistent with the `vsbuildtools` tool name.

## License & Acknowledgments

This project is licensed under the GNU Affero General Public License v3.0.

Thanks to the [jdx/mise](https://github.com/jdx/mise) project and the `mise-php` plugin structure that inspired this repository layout.
