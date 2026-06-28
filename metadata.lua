PLUGIN = {}

PLUGIN.name = "vsbuildtools"
PLUGIN.version = "0.1.0"
PLUGIN.homepage = "https://github.com/verzly/mise-vsbuildtools"
PLUGIN.license = "AGPL-3.0"
PLUGIN.description = "Visual Studio Build Tools manager for mise on Windows"
PLUGIN.minRuntimeVersion = "0.3.2"
PLUGIN.notes = {
    "Windows only.",
    "Installs Visual Studio Build Tools through WinGet.",
    "Installs the MSVC C++ Build Tools profile with recommended components.",
    "Visual Studio may create registry entries and shared Microsoft components outside the mise install path.",
    "MSVC paths are exposed through generated helper commands instead of being added globally to PATH.",
}
