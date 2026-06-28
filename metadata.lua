PLUGIN = {}

PLUGIN.name = "vsbuild"
PLUGIN.version = "0.1.0"
PLUGIN.homepage = "https://github.com/verzly/mise-vsbuild"
PLUGIN.license = "AGPL-3.0"
PLUGIN.description = "Visual Studio Build Tools manager plugin for mise on Windows (by verzly)"
PLUGIN.minRuntimeVersion = "0.3.2"
PLUGIN.manifestUrl = "https://github.com/verzly/mise-vsbuild/releases/download/manifest/manifest.json"
PLUGIN.notes = {
    "Windows only.",
    "Installs Visual Studio Build Tools through WinGet.",
    "Installs a fixed MSVC Build Tools profile.",
    "Visual Studio may create registry entries and shared Microsoft files outside the mise install path.",
    "MSVC paths are exposed through generated helper commands instead of being added globally to PATH.",
}
