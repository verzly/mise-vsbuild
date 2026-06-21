#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch] $InstalledOnly,
    [switch] $RemoteOnly,
    [switch] $VerboseOutput
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/common.ps1')

Set-VsBuildLogOptions -VerboseOutput:$VerboseOutput

if (!$RemoteOnly) {
    Write-VsBuildLog -Type Section -Message 'Installed Visual Studio Build Tools instances'
    $vswhere = Get-VsWherePath
    if ($null -eq $vswhere) {
        Write-VsBuildLog -Type Step -Name 'vswhere' -Message 'not found'
    } else {
        & $vswhere -products Microsoft.VisualStudio.Product.BuildTools -format table
    }
}

if (!$InstalledOnly) {
    Write-VsBuildLog -Type Section -Message 'WinGet Visual Studio Build Tools packages'
    if ($null -eq (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-VsBuildLog -Type Step -Name 'winget' -Message 'not found'
    } else {
        winget search --source winget --id Microsoft.VisualStudio --accept-source-agreements |
            Select-String -Pattern 'Microsoft\.VisualStudio(\.\d{4})?\.BuildTools' |
            ForEach-Object { '  ' + $_.Line }
    }
}

Write-Host ''
