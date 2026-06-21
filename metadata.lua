PLUGIN = {}

PLUGIN.name = "vsbuild"
PLUGIN.version = "0.1.0"
PLUGIN.homepage = "https://github.com/verzly/mise-vsbuild"
PLUGIN.license = "AGPL-3.0"
PLUGIN.description = "Visual Studio Build Tools manager for mise on Windows"
PLUGIN.minRuntimeVersion = "0.3.2"
PLUGIN.notes = {
    "Windows only.",
    "Installs Visual Studio Build Tools into the mise install path when Visual Studio supports --installPath.",
    "Visual Studio still creates system registry entries and may install shared Windows components outside the install path.",
    "Use vsbuild-uninstall before mise uninstall to remove the Visual Studio instance cleanly.",
    "WinGet discovery can add future Build Tools package IDs automatically when Microsoft publishes them.",
}
