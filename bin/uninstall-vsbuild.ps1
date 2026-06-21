#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $InstallPath,

    [switch] $KeepDirectory,
    [switch] $VerboseOutput,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/common.ps1')

Set-VsBuildLogOptions -VerboseOutput:$VerboseOutput

$InstallPath = Get-VsBuildFullPath $InstallPath
if ($DryRun) {
    $args = @('uninstall', '--installPath', $InstallPath, '--quiet', '--norestart')
    [ordered]@{
        installPath = $InstallPath
        operation = 'uninstall'
        args = $args
    } | ConvertTo-Json -Depth 4
    exit 0
}

$vsInstaller = Get-VsInstallerPath

Write-VsBuildLog -Type Header -Message 'Visual Studio Build Tools Uninstaller for mise'
Write-VsBuildLog -Type Step -Name 'path' -Message $InstallPath

$args = @('uninstall', '--installPath', $InstallPath, '--quiet', '--norestart')
Write-VsBuildCommand -FilePath $vsInstaller -ArgumentList $args
$process = Start-Process -FilePath $vsInstaller -ArgumentList $args -Wait -PassThru
if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
    throw "Visual Studio Installer uninstall failed with exit code $($process.ExitCode)."
}

if (!$KeepDirectory -and (Test-Path -LiteralPath $InstallPath)) {
    Write-VsBuildLog -Type Step -Name 'cleanup' -Message 'removing mise install directory'
    Start-Sleep -Seconds 2
    Remove-Item -LiteralPath $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-VsBuildLog -Type Success -Message 'Visual Studio Build Tools uninstall complete'
Write-Host ''
