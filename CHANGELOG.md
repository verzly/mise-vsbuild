# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project follows semantic versioning.

## [0.1.0] - 2026-06-21

### Added

- Add initial Windows-only `vsbuild` plugin for mise.
- Add Lua-first install flow for Visual Studio Build Tools through `winget` or direct bootstrapper URLs.
- Add support for `current`, `latest`, `stable`, 2026, 2022, 2019, and 2017 release lines.
- Add automatic WinGet discovery for future `Microsoft.VisualStudio.*.BuildTools` package IDs.
- Add future-year fallback for versions such as `vsbuild@2028`.
- Add configurable workloads, components, install method, bootstrapper URL, recommended components, and optional components.
- Add generated helper commands for running commands inside the MSVC developer environment.
- Add release workflow, latest workflow, and CI tests.
- Add README, AGPL license, changelog, and plugin metadata.
