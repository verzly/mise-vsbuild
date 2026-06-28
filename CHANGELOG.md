# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project follows semantic versioning.

## [0.1.0] - 2026-06-28

### Added

- Add initial Windows-only `vsbuildtools` plugin for mise.
- Add Lua-first install flow for Visual Studio Build Tools through `winget` or direct bootstrapper URLs.
- Add support for `current`, `latest`, `stable`, 2026, 2022, 2019, 2017, and 2015 compatibility release lines.
- Add Visual Studio 2015 v140 toolset compatibility profile through current Visual Studio Build Tools.
- Add automatic WinGet discovery for future `Microsoft.VisualStudio.*.BuildTools` package IDs.
- Add future-year fallback for versions such as `vsbuildtools@2028`.
- Add configurable workloads, components, install method, bootstrapper URL, recommended components, optional components, and `vcvars_ver`.
- Add generated helper commands for running commands inside the MSVC developer environment.
- Add generated helper commands for `vcvarsall`, `vcvars64`, `vcvars32`, `vcvarsarm64`, `cl`, `msbuild`, CMake, update, uninstall, and discovery.
- Add README, AGPL license, changelog, and plugin metadata.

### Changed

- Improve Windows command execution by routing generated install invocations through PowerShell argument arrays instead of fragile raw `cmd.exe` quoting.
- Treat Visual Studio Installer reboot-required success codes as successful installation results.
- Refresh the README structure to match the professional `mise-php` style while keeping Visual Studio-specific operational details.

### Fixed

- Fix install command generation for mise install paths that contain spaces.
- Fix helper generation to use `vcvarsall.bat` consistently for architecture and toolset selection.
- Fix update/uninstall helpers to support both `vs_installer.exe` and `setup.exe` Visual Studio Installer entry points.
