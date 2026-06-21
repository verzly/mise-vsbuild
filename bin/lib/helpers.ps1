#Requires -Version 5.1
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'common.ps1')

function Copy-VsBuildSupportScripts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceBin,

        [Parameter(Mandatory = $true)]
        [string] $TargetBin
    )

    foreach ($file in @('uninstall-vsbuild.ps1', 'update-vsbuild.ps1', 'list-vsbuild.ps1')) {
        $source = Join-Path $SourceBin $file
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $TargetBin $file) -Force
        }
    }

    $sourceLib = Join-Path $SourceBin 'lib'
    $targetLib = Join-Path $TargetBin 'lib'
    if (Test-Path -LiteralPath $sourceLib) {
        if (Test-Path -LiteralPath $targetLib) {
            Remove-Item -LiteralPath $targetLib -Recurse -Force
        }
        Copy-Item -LiteralPath $sourceLib -Destination $targetLib -Recurse -Force
    }
}

function New-VsBuildCmd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Content
    )

    Set-Content -LiteralPath $Path -Encoding ASCII -Value $Content
}

function New-VsBuildHelperScripts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $VsVersion,

        [Parameter(Mandatory = $true)]
        [string] $SourceBin
    )

    $bin = Join-Path $Path 'bin'
    New-Item -ItemType Directory -Force -Path $bin | Out-Null
    Copy-VsBuildSupportScripts -SourceBin $SourceBin -TargetBin $bin

    New-VsBuildCmd -Path (Join-Path $bin 'vsdevcmd.cmd') -Content @"
@echo off
call "%~dp0..\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 %*
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vcvars64.cmd') -Content @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" %*
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-run.cmd') -Content @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
%*
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-shell.cmd') -Content @"
@echo off
cmd /k ""%~dp0..\VC\Auxiliary\Build\vcvars64.bat""
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-cl.cmd') -Content @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
cl.exe %*
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-cmake.cmd') -Content @"
@echo off
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
cmake.exe %*
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-info.cmd') -Content @"
@echo off
echo VSBUILD_HOME=%~dp0..
echo VSBUILD_VERSION=$VsVersion
if exist "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" echo vcvars64=present
if exist "%~dp0..\Common7\Tools\VsDevCmd.bat" echo VsDevCmd=present
call "%~dp0..\VC\Auxiliary\Build\vcvars64.bat" >nul
where cl
cl
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-uninstall.cmd') -Content @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall-vsbuild.ps1" -InstallPath "%~dp0.." %*
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-update.cmd') -Content @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-vsbuild.ps1" -InstallPath "%~dp0.." %*
"@

    New-VsBuildCmd -Path (Join-Path $bin 'vsbuild-list.cmd') -Content @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0list-vsbuild.ps1" %*
"@
}
