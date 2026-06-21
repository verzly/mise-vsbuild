#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [string] $InstallPath,

    [Parameter(Mandatory = $true)]
    [string] $WingetId,

    [string] $BootstrapperUrl = '',

    [string] $Workloads = 'Microsoft.VisualStudio.Workload.VCTools',
    [string] $Components = '',

    [ValidateSet('winget', 'direct')]
    [string] $InstallMethod = 'winget',

    [switch] $IncludeRecommended,
    [switch] $IncludeOptional,
    [switch] $VerboseOutput
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string] $Name, [string] $Message)
    Write-Host ('  {0,-14} {1}' -f $Name, $Message)
}

function Test-Command {
    param([string] $Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Split-List {
    param([string] $Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return $Value -split '[,;]' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
}

function Quote-Argument {
    param([string] $Value)
    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }

    return $Value
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string[]] $ArgumentList
    )

    if ($VerboseOutput) {
        Write-Host ('> {0} {1}' -f $FilePath, (($ArgumentList | ForEach-Object { Quote-Argument $_ }) -join ' '))
    }

    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath"
    }
}

function Get-VsWherePath {
    $path = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    return $null
}

function Test-VsInstance {
    param([string] $Path)

    $vcvars64 = Join-Path $Path 'VC\Auxiliary\Build\vcvars64.bat'
    $vsdevcmd = Join-Path $Path 'Common7\Tools\VsDevCmd.bat'

    return (Test-Path -LiteralPath $vcvars64) -and (Test-Path -LiteralPath $vsdevcmd)
}

function New-HelperScripts {
    param(
        [string] $Path,
        [string] $VsVersion
    )

    $bin = Join-Path $Path 'bin'
    New-Item -ItemType Directory -Force -Path $bin | Out-Null

    $sourceUninstall = Join-Path $PSScriptRoot 'uninstall-vsbuild.ps1'
    $sourceUpdate = Join-Path $PSScriptRoot 'update-vsbuild.ps1'
    if (Test-Path -LiteralPath $sourceUninstall) {
        Copy-Item -LiteralPath $sourceUninstall -Destination (Join-Path $bin 'uninstall-vsbuild.ps1') -Force
    }
    if (Test-Path -LiteralPath $sourceUpdate) {
        Copy-Item -LiteralPath $sourceUpdate -Destination (Join-Path $bin 'update-vsbuild.ps1') -Force
    }

    $sourceList = Join-Path $PSScriptRoot 'list-vsbuild.ps1'
    if (Test-Path -LiteralPath $sourceList) {
        Copy-Item -LiteralPath $sourceList -Destination (Join-Path $bin 'list-vsbuild.ps1') -Force
    }

    $vsdevcmd = Join-Path $bin 'vsdevcmd.cmd'
    Set-Content -LiteralPath $vsdevcmd -Encoding ASCII -Value @"
@echo off
call "%~dp0..\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 %*
"@

    $vcvars64 = Join-Path $bin 'vcvars64.cmd'
    Set-Content -LiteralPath $vcvars64 -Encoding ASCII -Value @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" %*
"@

    $run = Join-Path $bin 'vsbuild-run.cmd'
    Set-Content -LiteralPath $run -Encoding ASCII -Value @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
%*
"@

    $shell = Join-Path $bin 'vsbuild-shell.cmd'
    Set-Content -LiteralPath $shell -Encoding ASCII -Value @"
@echo off
cmd /k ""%~dp0..\VC\Auxiliary\Build\vcvars64.bat""
"@

    $cl = Join-Path $bin 'vsbuild-cl.cmd'
    Set-Content -LiteralPath $cl -Encoding ASCII -Value @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
cl.exe %*
"@

    $cmake = Join-Path $bin 'vsbuild-cmake.cmd'
    Set-Content -LiteralPath $cmake -Encoding ASCII -Value @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
cmake.exe %*
"@

    $info = Join-Path $bin 'vsbuild-info.cmd'
    Set-Content -LiteralPath $info -Encoding ASCII -Value @"
@echo off
echo VSBUILD_HOME=%~dp0..
echo VSBUILD_VERSION=$VsVersion
if exist "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" echo vcvars64=present
if exist "%~dp0..\Common7\Tools\VsDevCmd.bat" echo VsDevCmd=present
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
where cl
cl
"@

    $uninstall = Join-Path $bin 'vsbuild-uninstall.cmd'
    Set-Content -LiteralPath $uninstall -Encoding ASCII -Value @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\bin\uninstall-vsbuild.ps1" -InstallPath "%~dp0.." %*
"@

    $update = Join-Path $bin 'vsbuild-update.cmd'
    Set-Content -LiteralPath $update -Encoding ASCII -Value @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\bin\update-vsbuild.ps1" -InstallPath "%~dp0.." %*
"@

    $list = Join-Path $bin 'vsbuild-list.cmd'
    Set-Content -LiteralPath $list -Encoding ASCII -Value @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\bin\list-vsbuild.ps1" %*
"@
}

Write-Host ''
Write-Host '  🧰 Visual Studio Build Tools Installer for mise'
Write-Host '  ────────────────────────────────────────────────────'

if ($env:OS -ne 'Windows_NT') {
    throw 'Visual Studio Build Tools can only be installed on Windows.'
}

$InstallPath = [System.IO.Path]::GetFullPath($InstallPath)
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

Write-Step 'version' "Visual Studio Build Tools $Version"
Write-Step 'path' $InstallPath

$workloadList = Split-List $Workloads
$componentList = Split-List $Components

if ($workloadList.Count -eq 0 -and $componentList.Count -eq 0) {
    $workloadList = @('Microsoft.VisualStudio.Workload.VCTools')
}

if (Test-VsInstance -Path $InstallPath) {
    Write-Step 'existing' 'valid Build Tools instance found, refreshing helper scripts only'
    New-HelperScripts -Path $InstallPath -VsVersion $Version
    exit 0
}

$vsArgs = @(
    '--wait',
    '--quiet',
    '--norestart',
    '--installPath', $InstallPath
)

foreach ($workload in $workloadList) {
    $vsArgs += @('--add', $workload)
}

foreach ($component in $componentList) {
    $vsArgs += @('--add', $component)
}

if ($IncludeRecommended) {
    $vsArgs += '--includeRecommended'
}

if ($IncludeOptional) {
    $vsArgs += '--includeOptional'
}

if ($InstallMethod -eq 'winget' -and (Test-Command winget)) {
    if ([string]::IsNullOrWhiteSpace($WingetId)) {
        throw 'WinGet install method requires a Winget package ID.'
    }

    Write-Step 'installer' "winget package $WingetId"
    $override = ($vsArgs | ForEach-Object { Quote-Argument $_ }) -join ' '
    $args = @(
        'install',
        '-e',
        '--id', $WingetId,
        '--override', $override,
        '--accept-package-agreements',
        '--accept-source-agreements'
    )
    Invoke-External -FilePath 'winget' -ArgumentList $args
} else {
    if ([string]::IsNullOrWhiteSpace($BootstrapperUrl)) {
        throw 'Direct install method is only supported for known Visual Studio release lines with known bootstrapper URLs. Use winget for current/future versions or set VSBUILD_BOOTSTRAPPER_URL.'
    }

    Write-Step 'installer' "direct bootstrapper $BootstrapperUrl"
    $bootstrapperPath = Join-Path $env:TEMP ("vs_BuildTools_$Version.exe")

    if (!(Test-Path -LiteralPath $bootstrapperPath)) {
        Write-Step 'download' $bootstrapperPath
        Invoke-WebRequest -Uri $BootstrapperUrl -OutFile $bootstrapperPath
    }

    $process = Start-Process -FilePath $bootstrapperPath -ArgumentList $vsArgs -Wait -PassThru
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "Visual Studio bootstrapper failed with exit code $($process.ExitCode)."
    }
}

if (!(Test-VsInstance -Path $InstallPath)) {
    throw "Visual Studio Build Tools installation did not produce a usable instance at: $InstallPath"
}

New-HelperScripts -Path $InstallPath -VsVersion $Version

Write-Step 'helpers' (Join-Path $InstallPath 'bin')
Write-Host '  ────────────────────────────────────────────────────'
Write-Host '  Visual Studio Build Tools installation complete'
Write-Host '  Try: vsbuild-info'
Write-Host ''
