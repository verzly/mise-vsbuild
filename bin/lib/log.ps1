#Requires -Version 5.1
Set-StrictMode -Version Latest

$script:VSBUILD_LOG_VERBOSE = $false
$script:VSBUILD_LOG_QUIET = $false

function Set-VsBuildLogOptions {
    [CmdletBinding()]
    param(
        [switch] $VerboseOutput,
        [switch] $Quiet
    )

    $script:VSBUILD_LOG_VERBOSE = [bool] $VerboseOutput
    $script:VSBUILD_LOG_QUIET = [bool] $Quiet
}

function Write-VsBuildLog {
    [CmdletBinding()]
    param(
        [ValidateSet('Header', 'Step', 'Note', 'Tip', 'Success', 'Warning', 'Error', 'Command', 'Section')]
        [string] $Type = 'Step',

        [string] $Name = '',
        [string] $Message = ''
    )

    if ($script:VSBUILD_LOG_QUIET -and $Type -notin @('Error', 'Warning')) {
        return
    }

    switch ($Type) {
        'Header' {
            Write-Host ''
            Write-Host ('  {0} {1}' -f [char]0x1F9F0, $Message)
            Write-Host '  ────────────────────────────────────────────────────'
            return
        }
        'Section' {
            Write-Host ''
            Write-Host ('  {0}' -f $Message)
            Write-Host '  ────────────────────────────────────────────────────'
            return
        }
        'Step' {
            Write-Host ('  {0,-14} {1}' -f $Name, $Message)
            return
        }
        'Note' {
            Write-Host ('  Note: {0}' -f $Message)
            return
        }
        'Tip' {
            Write-Host ('  {0} Tip: {1}' -f [char]0x1F4A1, $Message)
            return
        }
        'Success' {
            Write-Host ('  {0} {1}' -f [char]0x2705, $Message)
            return
        }
        'Warning' {
            Write-Warning $Message
            return
        }
        'Error' {
            Write-Error $Message
            return
        }
        'Command' {
            if ($script:VSBUILD_LOG_VERBOSE) {
                Write-Host ('> {0}' -f $Message)
            }
            return
        }
    }
}

function Write-VsBuildCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $ArgumentList = @()
    )

    $command = $FilePath
    if ($ArgumentList.Count -gt 0) {
        $command += ' ' + (($ArgumentList | ForEach-Object { Format-VsBuildArgument $_ }) -join ' ')
    }

    Write-VsBuildLog -Type Command -Message $command
}

function Format-VsBuildArgument {
    [CmdletBinding()]
    param([AllowNull()][string] $Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }

    return $Value
}
