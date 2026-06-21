use std::collections::HashMap;
use std::env;
use std::fs;

fn main() {
    if let Err(err) = run_main() {
        eprintln!("{err}");
        std::process::exit(1);
    }
}

fn run_main() -> Result<(), String> {
    let mut args = env::args().skip(1);
    let command = args.next().ok_or_else(usage)?;
    let args: Vec<String> = args.collect();

    match command.as_str() {
        "static" => check_static(),
        "env-options" => check_env_options(&args),
        "version-list" => check_version_list(&args),
        _ => Err(usage()),
    }
}

fn usage() -> String {
    "Usage:\n  ci-checks static\n  ci-checks env-options <mise-env-file>\n  ci-checks version-list <versions-file>".to_string()
}

fn read(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map_err(|err| format!("Failed to read {path}: {err}"))
}

fn check_static() -> Result<(), String> {
    let metadata = read("metadata.lua")?;
    let readme = read("README.md")?;
    let changelog = read("CHANGELOG.md")?;
    let license = read("LICENSE")?;

    require_contains(&metadata, "PLUGIN.name = \"vsbuild\"", "metadata plugin name")?;
    require_contains(&metadata, "PLUGIN.version = \"0.1.0\"", "metadata plugin version")?;
    require_contains(&metadata, "Windows only", "metadata notes")?;

    require_contains(&readme, "# verzly/mise-vsbuild", "README title")?;
    require_contains(&readme, "## Testing", "README testing section")?;
    require_contains(&readme, "## Release management", "README release management section")?;
    require_contains(&readme, "## License & Acknowledgments", "README license section")?;
    require_contains(&readme, "Lua-first plugin design", "README Lua-first section")?;

    require_contains(&changelog, "## [0.1.0]", "CHANGELOG initial release")?;
    require_contains(&changelog, "release workflow", "CHANGELOG release workflow entry")?;
    require_contains(&changelog, "CI tests", "CHANGELOG CI tests entry")?;

    require_contains(&license, "GNU AFFERO GENERAL PUBLIC LICENSE", "AGPL license text")?;

    for path in [
        ".github/workflows/test.yml",
        ".github/workflows/publish.yaml",
        ".github/workflows/latest.yml",
        ".github/scripts/ci-checks.rs",
        "hooks/available.lua",
        "hooks/pre_install.lua",
        "hooks/post_install.lua",
        "hooks/env_keys.lua",
        "hooks/mise_env.lua",
        "lib/env.lua",
        "lib/messages.lua",
        "lib/options.lua",
        "lib/versions.lua",
        "lib/system.lua",
        "lib/install.lua",
        "lib/helpers.lua",
    ] {
        fs::metadata(path).map_err(|err| format!("Expected {path} to exist: {err}"))?;
    }

    for path in [
        "bin/install-vsbuild.ps1",
        "bin/update-vsbuild.ps1",
        "bin/uninstall-vsbuild.ps1",
        "bin/list-vsbuild.ps1",
    ] {
        if fs::metadata(path).is_ok() {
            return Err(format!("PowerShell script should not be committed anymore: {path}"));
        }
    }

    println!("static repository checks passed");
    Ok(())
}

fn require_contains(content: &str, needle: &str, label: &str) -> Result<(), String> {
    if !content.contains(needle) {
        return Err(format!("Missing {label}: {needle:?}"));
    }
    Ok(())
}

fn check_env_options(args: &[String]) -> Result<(), String> {
    if args.len() != 1 {
        return Err(usage());
    }

    let expected = HashMap::from([
        ("VSBUILD_WORKLOADS", "Microsoft.VisualStudio.Workload.VCTools"),
        ("VSBUILD_COMPONENTS", "Microsoft.VisualStudio.Component.VC.CMake.Project"),
        ("VSBUILD_INSTALL_METHOD", "winget"),
        ("VSBUILD_NO_RECOMMENDED", "1"),
        ("VSBUILD_INCLUDE_OPTIONAL", "1"),
        ("VSBUILD_VERBOSE", "1"),
        ("VSBUILD_DRY_RUN", "1"),
    ]);

    let content = read(&args[0])?;
    let mut values = HashMap::new();

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let Some((key, value)) = line.split_once('=') else {
            continue;
        };

        values.insert(key.trim().to_string(), strip_env_quotes(value.trim()).to_string());
    }

    let mut failures = Vec::new();
    for (key, expected_value) in expected {
        let actual = values.get(key).map(String::as_str);
        if actual != Some(expected_value) {
            failures.push(format!(
                "{key}: expected {expected_value:?}, got {:?}",
                actual
            ));
        }
    }

    if !failures.is_empty() {
        return Err(failures.join("\n"));
    }

    println!("env._.vsbuild options were exported correctly");
    Ok(())
}

fn strip_env_quotes(value: &str) -> &str {
    let bytes = value.as_bytes();
    if bytes.len() >= 2 {
        let first = bytes[0];
        let last = bytes[bytes.len() - 1];
        if (first == b'\'' && last == b'\'') || (first == b'\"' && last == b'\"') {
            return &value[1..value.len() - 1];
        }
    }
    value
}

fn check_version_list(args: &[String]) -> Result<(), String> {
    if args.len() != 1 {
        return Err(usage());
    }

    let content = read(&args[0])?;
    let versions: Vec<&str> = content
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect();

    if versions.is_empty() {
        return Err("No vsbuild versions were returned".to_string());
    }

    for expected in ["current", "latest", "stable", "2026", "2022", "2019", "2017"] {
        if !versions.iter().any(|version| version == &expected) {
            return Err(format!("Expected {expected} in vsbuild version list"));
        }
    }

    println!("version list contains {} entries", versions.len());
    Ok(())
}
