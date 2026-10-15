function Stop-FileLock {
    <#
    .SYNOPSIS
    Identifies and terminates processes holding a lock on a specified file.

    .DESCRIPTION
    Uses Sysinternals Handle.exe (path from the Sysinternals toolkit setting) to find processes with an open
    handle to the file, then stops each one after confirmation. Processes are always stopped on the same computer
    on which they were found. Before stopping a process, its name is re-checked against the PID to avoid killing
    an unrelated process if the PID was reused.
    When FileName is not supplied, the function runs interactively and prompts for the file name and computer.

    .PARAMETER FileName
    The file name or path of the locked file. A full path is strongly recommended because
    Handle.exe matches substrings.

    .PARAMETER ComputerName
    Optional. The remote computer to target. Requires WinRM. If omitted, the local computer is targeted.

    .PARAMETER Force
    Suppresses the per-process confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    Stop-FileLock
    # Prompts for a file name and computer, then asks for confirmation before stopping each process.

    .EXAMPLE
    Stop-FileLock -FileName 'D:\Shares\Finance\Budget.xlsx' -ComputerName 'FS01' -WhatIf
    # Shows which processes on FS01 would be stopped without stopping them.

    .OUTPUTS
    PSCustomObject with ComputerName, ProcessName, PID, Path, and Result for every process that was confirmed.

    .NOTES
    Author: Alexander Christian
    Requires Sysinternals Handle.exe. Handle.exe is refused unless it has a valid Microsoft signature.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [string]$FileName,

        [string]$ComputerName,

        [switch]$Force
    )

    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
        $ConfirmPreference = 'None'
    }

    if (-not $PSBoundParameters.ContainsKey('FileName')) {
        $FileName = Read-Host "Enter the name or full path of the file being held by a process"
        if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
            $ComputerName = Read-Host "Enter the computer to work with (leave blank for the local machine)"
        }
    }

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        throw "A file name is required."
    }

    if ($ComputerName) {
        # The name itself is kept for the remote session; this only checks DNS and WinRM before anything runs.
        $null = Resolve-ToolkitHost -Name $ComputerName -RequireWinRM
    }

    $sysinternalsPath = (Get-ToolkitConfig).SysinternalsPath
    if (-not $sysinternalsPath) {
        throw "The SysinternalsPath setting is empty. Set it in the toolkit configuration."
    }
    $handleExe = Join-Path -Path $sysinternalsPath -ChildPath 'handle.exe'

    $lockParams = @{
        FileName  = $FileName
        HandleExe = $handleExe
    }
    if ($ComputerName) {
        $lockParams['ComputerName'] = $ComputerName
    }
    $locks = @(Get-FileLockProcess @lockParams)

    if ($locks.Count -eq 0) {
        Write-Warning "No processes found holding '$FileName'."
        return
    }

    $processStopper = {
        param([int]$ProcessId, [string]$ExpectedName)

        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if (-not $process) {
            return 'NotRunning'
        }
        $expectedBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ExpectedName)
        if ($process.ProcessName -ne $expectedBaseName) {
            return "Skipped: PID now belongs to '$($process.ProcessName)'"
        }
        Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        'Stopped'
    }

    foreach ($lock in $locks) {
        $target = "$($lock.ProcessName) (PID $($lock.PID)) on $($lock.ComputerName)"
        if ($lock.Path) {
            $target += " holding '$($lock.Path)'"
        }

        if (-not $PSCmdlet.ShouldProcess($target, 'Stop process')) {
            continue
        }

        try {
            if ($ComputerName) {
                $stopParams = @{
                    ComputerName = $ComputerName
                    ScriptBlock  = $processStopper
                    ArgumentList = $lock.PID, $lock.ProcessName
                    ErrorAction  = 'Stop'
                }
                $result = Invoke-Command @stopParams
            } else {
                $result = & $processStopper $lock.PID $lock.ProcessName
            }
        } catch {
            $result = "Failed: $($_.Exception.Message)"
            Write-Error -ErrorRecord $_
        }

        [PSCustomObject]@{
            ComputerName = $lock.ComputerName
            ProcessName  = $lock.ProcessName
            PID          = $lock.PID
            Path         = $lock.Path
            Result       = $result
        }
    }
}
