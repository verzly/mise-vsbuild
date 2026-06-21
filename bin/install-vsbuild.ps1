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
    [switch] $VerboseOutput,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/helpers.ps1')

Set-VsBuildLogOptions -VerboseOutput:$VerboseOutput

Write-VsBuildLog -Type Header -Message 'Visual Studio Build Tools Installer for mise'

if ($env:OS -ne 'Windows_NT' -and !$DryRun) {
    throw 'Visual Studio Build Tools can only be installed on Windows.'
}

$InstallPath = Get-VsBuildFullPath $InstallPath
if (!$DryRun) {
    New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
}

Write-VsBuildLog -Type Step -Name 'version' -Message "Visual Studio Build Tools $Version"
Write-VsBuildLog -Type Step -Name 'path' -Message $InstallPath

$workloadList = Split-VsBuildList $Workloads
$componentList = Split-VsBuildList $Components

if ($workloadList.Count -eq 0 -and $componentList.Count -eq 0) {
    $workloadList = @('Microsoft.VisualStudio.Workload.VCTools')
}

if (Test-VsBuildInstance -Path $InstallPath) {
    Write-VsBuildLog -Type Step -Name 'existing' -Message 'valid Build Tools instance found, refreshing helper scripts only'
    New-VsBuildHelperScripts -Path $InstallPath -VsVersion $Version -SourceBin $PSScriptRoot
    Write-VsBuildLog -Type Success -Message 'Visual Studio Build Tools helpers refreshed'
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

if ($DryRun) {
    $override = ($vsArgs | ForEach-Object { Format-VsBuildArgument $_ }) -join ' '
    $command = if ($InstallMethod -eq 'winget') {
        @('winget', 'install', '-e', '--id', $WingetId, '--override', $override, '--accept-package-agreements', '--accept-source-agreements')
    } else {
        @($BootstrapperUrl) + $vsArgs
    }

    [ordered]@{
        version = $Version
        installPath = $InstallPath
        wingetId = $WingetId
        bootstrapperUrl = $BootstrapperUrl
        workloads = $workloadList
        components = $componentList
        installMethod = $InstallMethod
        includeRecommended = [bool]$IncludeRecommended
        includeOptional = [bool]$IncludeOptional
        vsArgs = $vsArgs
        command = $command
    } | ConvertTo-Json -Depth 8

    exit 0
}

if ($InstallMethod -eq 'winget' -and (Test-VsBuildCommand winget)) {
    if ([string]::IsNullOrWhiteSpace($WingetId)) {
        throw 'WinGet install method requires a WinGet package ID.'
    }

    Write-VsBuildLog -Type Step -Name 'installer' -Message "winget package $WingetId"
    $override = ($vsArgs | ForEach-Object { Format-VsBuildArgument $_ }) -join ' '
    $args = @(
        'install',
        '-e',
        '--id', $WingetId,
        '--override', $override,
        '--accept-package-agreements',
        '--accept-source-agreements'
    )
    Invoke-VsBuildExternal -FilePath 'winget' -ArgumentList $args
} else {
    if ([string]::IsNullOrWhiteSpace($BootstrapperUrl)) {
        throw 'Direct install method requires a known bootstrapper URL. Use WinGet for current/future versions or set VSBUILD_BOOTSTRAPPER_URL.'
    }

    Write-VsBuildLog -Type Step -Name 'installer' -Message "direct bootstrapper $BootstrapperUrl"
    $bootstrapperPath = Join-Path $env:TEMP ("vs_BuildTools_$Version.exe")

    if (!(Test-Path -LiteralPath $bootstrapperPath)) {
        Write-VsBuildLog -Type Step -Name 'download' -Message $bootstrapperPath
        Invoke-WebRequest -Uri $BootstrapperUrl -OutFile $bootstrapperPath
    }

    Write-VsBuildCommand -FilePath $bootstrapperPath -ArgumentList $vsArgs
    $process = Start-Process -FilePath $bootstrapperPath -ArgumentList $vsArgs -Wait -PassThru
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "Visual Studio bootstrapper failed with exit code $($process.ExitCode)."
    }
}

if (!(Test-VsBuildInstance -Path $InstallPath)) {
    throw "Visual Studio Build Tools installation did not produce a usable instance at: $InstallPath"
}

New-VsBuildHelperScripts -Path $InstallPath -VsVersion $Version -SourceBin $PSScriptRoot

Write-VsBuildLog -Type Step -Name 'helpers' -Message (Join-Path $InstallPath 'bin')
Write-VsBuildLog -Type Success -Message 'Visual Studio Build Tools installation complete'
Write-VsBuildLog -Type Tip -Message 'Run vsbuild-info to verify the active toolchain.'
Write-Host ''
