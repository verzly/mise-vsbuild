# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-28

### Added

- Added initial `vsbuildtools` plugin implementation for jdx/mise.
- Added WinGet-based installation for Visual Studio Build Tools on Windows.
- Added support for `current`, `latest`, `stable`, `2026`, `2022`, `2019`, and `2017` release lines.
- Added future-year inference for `Microsoft.VisualStudio.<YYYY>.BuildTools` WinGet packages.
- Added generated helper commands for running `cl`, `cmake`, `msbuild`, `vcvarsall`, and `VsDevCmd` inside the selected Build Tools environment.
- Added update and uninstall helper commands for Visual Studio Installer-managed instances.
- Added GitHub release manifest workflows aligned with the `mise-php` repository structure.

### Changed

- Simplified the plugin configuration surface to a fixed, auditable MSVC Build Tools install profile.
- Removed custom install method, workload, component, optional component, `vcvars_ver`, and dry-run configuration paths.
- Kept only the `verbose` plugin option, exposed through `VSBUILDTOOLS_VERBOSE`.

### Removed

- Removed the legacy `vsbuildtools@2015` compatibility profile because `Microsoft.BuildTools2015` does not use the same modern Visual Studio Build Tools instance model.
