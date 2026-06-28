PLUGIN = {}

PLUGIN.name = "vsbuildtools"
PLUGIN.version = "0.1.0"
PLUGIN.homepage = "https://github.com/verzly/mise-vsbuildtools"
PLUGIN.license = "AGPL-3.0"
PLUGIN.description = "Windows Visual Studio Build Tools manager for mise"
PLUGIN.minRuntimeVersion = "0.3.2"
PLUGIN.notes = {
    "Windows only.",
    "Installs Visual Studio Build Tools into the mise install path when Visual Studio supports --installPath.",
    "Visual Studio still creates registry entries and may install shared Windows components outside the install path.",
    "MSVC paths are exposed through generated helper commands instead of being added globally to PATH.",
    "WinGet discovery can add future Build Tools package IDs automatically when Microsoft publishes them.",
    "Visual Studio 2015 is exposed as a v140 toolset compatibility profile through current Build Tools.",
}
