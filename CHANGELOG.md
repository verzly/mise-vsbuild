# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] - 2026-06-21

### Added

- Add shared PowerShell logging helpers under `bin/lib/log.ps1`.
- Add shared PowerShell command and Visual Studio helper modules under `bin/lib/`.

- Added Windows-only mise tool plugin for Visual Studio Build Tools.
- Added support for the Visual Studio Build Tools current channel via `Microsoft.VisualStudio.BuildTools`.
- Added support for Visual Studio Build Tools 2026, 2022, 2019, and 2017 release lines.
- Added future year fallback for versions such as `vsbuild@2028`, resolving to `Microsoft.VisualStudio.<YEAR>.BuildTools`.
- Added WinGet discovery for Visual Studio Build Tools packages when available.
- Added default C++ workload installation through `Microsoft.VisualStudio.Workload.VCTools`.
- Added configurable workloads, components, install method, recommended components, optional components, and verbose output.
- Added helper commands for MSVC shell activation, single-command execution, `cl`, CMake, update, uninstall, installation diagnostics, and local Build Tools discovery.
- Added README, AGPL-3.0 license, and development metadata.
- Added CI tests for repository metadata, Lua syntax, mise plugin registration, version listing, plugin option export, and PowerShell installer dry-run validation.
- Added release workflow to generate plugin archives and publish mise manifest metadata from tags.
- Added latest-tag workflow for stable `#latest` plugin installation references.
- Added dry-run mode to installer, updater, and uninstaller scripts for safe automated testing.
