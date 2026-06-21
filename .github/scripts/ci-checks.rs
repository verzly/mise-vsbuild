use std::collections::HashMap;
use std::env;
use std::fs;
use std::process::{Command, Stdio};

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
        "dry-run" => check_dry_run(&args),
        "powershell-script" => check_powershell_script(&args),
        _ => Err(usage()),
    }
}

fn usage() -> String {
    "Usage:\n  ci-checks static\n  ci-checks env-options <mise-env-file>\n  ci-checks version-list <versions-file>\n  ci-checks dry-run <dry-run-json-file>\n  ci-checks powershell-script <script-path> [args...]".to_string()
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

    require_contains(&changelog, "## [0.1.0]", "CHANGELOG initial release")?;
    require_contains(&changelog, "release workflow", "CHANGELOG release workflow entry")?;
    require_contains(&changelog, "CI tests", "CHANGELOG CI tests entry")?;

    require_contains(&license, "GNU AFFERO GENERAL PUBLIC LICENSE", "AGPL license text")?;

    for path in [
        ".github/workflows/test.yml",
        ".github/workflows/publish.yaml",
        ".github/workflows/latest.yml",
        ".github/scripts/ci-checks.rs",
        "bin/install-vsbuild.ps1",
        "bin/update-vsbuild.ps1",
        "bin/uninstall-vsbuild.ps1",
        "bin/list-vsbuild.ps1",
        "bin/lib/log.ps1",
        "bin/lib/common.ps1",
        "bin/lib/helpers.ps1",
    ] {
        fs::metadata(path).map_err(|err| format!("Expected {path} to exist: {err}"))?;
    }

    require_contains(&read("bin/install-vsbuild.ps1")?, "Write-VsBuildLog", "installer shared logging")?;
    require_contains(&read("bin/update-vsbuild.ps1")?, "Write-VsBuildLog", "updater shared logging")?;
    require_contains(&read("bin/uninstall-vsbuild.ps1")?, "Write-VsBuildLog", "uninstaller shared logging")?;
    require_contains(&read("bin/list-vsbuild.ps1")?, "Write-VsBuildLog", "list shared logging")?;
    require_contains(&read("bin/lib/log.ps1")?, "function Write-VsBuildLog", "shared log function")?;

    check_emoji_policy()?;

    println!("static repository checks passed");
    Ok(())
}

fn check_emoji_policy() -> Result<(), String> {
    let allowed = ["lib/messages.lua", "bin/lib/log.ps1"];
    let emoji_markers = ["\u{1F4A1}", "\u{1F9F0}", "\u{2705}", "\u{1F504}", "\u{1F9F9}"];

    for path in collect_repo_files(".")? {
        if path.contains(".git/") || path.ends_with(".zip") {
            continue;
        }

        let normalized = path.trim_start_matches("./").replace('\\', "/");
        if allowed.contains(&normalized.as_str()) {
            continue;
        }

        let content = match fs::read_to_string(&path) {
            Ok(content) => content,
            Err(_) => continue,
        };

        for marker in emoji_markers {
            if content.contains(marker) {
                return Err(format!(
                    "Emoji marker {marker:?} is only allowed in shared message/log helpers, found in {normalized}"
                ));
            }
        }
    }

    Ok(())
}

fn collect_repo_files(root: &str) -> Result<Vec<String>, String> {
    let mut out = Vec::new();
    collect_repo_files_inner(root, &mut out)?;
    Ok(out)
}

fn collect_repo_files_inner(root: &str, out: &mut Vec<String>) -> Result<(), String> {
    for entry in fs::read_dir(root).map_err(|err| format!("Failed to read directory {root}: {err}"))? {
        let entry = entry.map_err(|err| format!("Failed to read directory entry: {err}"))?;
        let path = entry.path();
        let path_string = path.to_string_lossy().replace('\\', "/");

        if path_string.contains("/.git") {
            continue;
        }

        if path.is_dir() {
            collect_repo_files_inner(&path_string, out)?;
        } else {
            out.push(path_string);
        }
    }

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

fn check_dry_run(args: &[String]) -> Result<(), String> {
    if args.len() != 1 {
        return Err(usage());
    }

    let content = read(&args[0])?;

    for needle in [
        "\"version\"",
        "\"2022\"",
        "\"installMethod\"",
        "\"winget\"",
        "Microsoft.VisualStudio.2022.BuildTools",
        "Microsoft.VisualStudio.Workload.VCTools",
        "Microsoft.VisualStudio.Component.VC.CMake.Project",
        "--installPath",
        "--includeRecommended",
    ] {
        require_contains(&content, needle, "dry-run output")?;
    }

    println!("dry-run output looks valid");
    Ok(())
}

fn check_powershell_script(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err(usage());
    }

    let script = &args[0];
    let script_args: Vec<&str> = args.iter().skip(1).map(String::as_str).collect();

    let executable = if cfg!(windows) { "powershell" } else { "pwsh" };
    let status = Command::new(executable)
        .arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-File")
        .arg(script)
        .args(script_args)
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .map_err(|err| format!("Failed to execute {executable}: {err}"))?;

    if !status.success() {
        return Err(format!("PowerShell script failed: {script}"));
    }

    Ok(())
}
