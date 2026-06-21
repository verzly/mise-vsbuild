#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch] $InstalledOnly,
    [switch] $RemoteOnly
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string] $Title)
    Write-Host ''
    Write-Host ('  {0}' -f $Title)
    Write-Host '  ────────────────────────────────────────────────────'
}

function Get-VsWherePath {
    $path = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $path) {
        return $path
    }
    return $null
}

if (!$RemoteOnly) {
    Write-Section 'Installed Visual Studio Build Tools instances'
    $vswhere = Get-VsWherePath
    if ($null -eq $vswhere) {
        Write-Host '  vswhere.exe not found'
    } else {
        & $vswhere -products Microsoft.VisualStudio.Product.BuildTools -format table
    }
}

if (!$InstalledOnly) {
    Write-Section 'WinGet Visual Studio Build Tools packages'
    if ($null -eq (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '  winget not found'
    } else {
        winget search --source winget --id Microsoft.VisualStudio --accept-source-agreements |
            Select-String -Pattern 'Microsoft\.VisualStudio(\.\d{4})?\.BuildTools' |
            ForEach-Object { '  ' + $_.Line }
    }
}

Write-Host ''
