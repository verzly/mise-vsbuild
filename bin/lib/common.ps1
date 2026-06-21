#Requires -Version 5.1
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'log.ps1')

function Test-VsBuildCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string] $Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Split-VsBuildList {
    [CmdletBinding()]
    param([AllowNull()][string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return $Value -split '[,;]' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
}

function Get-VsBuildFullPath {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string] $Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Invoke-VsBuildExternal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string[]] $ArgumentList
    )

    Write-VsBuildCommand -FilePath $FilePath -ArgumentList $ArgumentList

    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        throw "Command failed with exit code ${exitCode}: $FilePath"
    }
}

function Get-VsWherePath {
    [CmdletBinding()]
    param()

    $path = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    return $null
}

function Get-VsInstallerPath {
    [CmdletBinding()]
    param()

    $path = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vs_installer.exe'
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    throw 'vs_installer.exe was not found. Visual Studio Installer may not be installed.'
}

function Test-VsBuildInstance {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string] $Path)

    $vcvars64 = Join-Path $Path 'VC\Auxiliary\Build\vcvars64.bat'
    $vsdevcmd = Join-Path $Path 'Common7\Tools\VsDevCmd.bat'

    return (Test-Path -LiteralPath $vcvars64) -and (Test-Path -LiteralPath $vsdevcmd)
}
