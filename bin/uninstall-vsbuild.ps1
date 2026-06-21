#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $InstallPath,

    [switch] $KeepDirectory,
    [switch] $VerboseOutput
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string] $Name, [string] $Message)
    Write-Host ('  {0,-14} {1}' -f $Name, $Message)
}

function Get-VsInstallerPath {
    $path = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    throw 'vs_installer.exe was not found. Visual Studio Installer may not be installed.'
}

$InstallPath = [System.IO.Path]::GetFullPath($InstallPath)
$vsInstaller = Get-VsInstallerPath

Write-Host ''
Write-Host '  🧹 Visual Studio Build Tools Uninstaller for mise'
Write-Host '  ────────────────────────────────────────────────────'
Write-Step 'path' $InstallPath

$args = @('uninstall', '--installPath', $InstallPath, '--quiet', '--norestart')
if ($VerboseOutput) {
    Write-Host ('> {0} {1}' -f $vsInstaller, ($args -join ' '))
}

$process = Start-Process -FilePath $vsInstaller -ArgumentList $args -Wait -PassThru
if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
    throw "Visual Studio Installer uninstall failed with exit code $($process.ExitCode)."
}

if (!$KeepDirectory -and (Test-Path -LiteralPath $InstallPath)) {
    Write-Step 'cleanup' 'removing mise install directory'
    Start-Sleep -Seconds 2
    Remove-Item -LiteralPath $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '  ────────────────────────────────────────────────────'
Write-Host '  Visual Studio Build Tools uninstall complete'
Write-Host ''
