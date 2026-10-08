function Get-FileLockProcess {
    <#
    .SYNOPSIS
    Returns the processes that hold an open file handle matching the specified name.

    .DESCRIPTION
    Runs Sysinternals Handle.exe on the target computer (locally through Start-Job, remotely through
    Invoke-Command -AsJob) and returns one object per distinct process. Before Handle.exe is executed,
    its Authenticode signature is validated on the machine that will run it; unsigned or non-Microsoft
    binaries are refused. PIDs 0 and 4 (Idle/System) and the PID of the PowerShell host that runs the
    search are excluded.

    .PARAMETER FileName
    The file name or path to search for. Handle.exe performs a case-insensitive substring match, so a full path
    produces the most precise results.

    .PARAMETER HandleExe
    Full path to handle.exe, as seen from the computer that will run it.

    .PARAMETER ComputerName
    Optional. The remote computer to search. If omitted, the local computer is searched.

    .OUTPUTS
    PSCustomObject with ComputerName, ProcessName, PID, and Path.

    .NOTES
    Author: Alexander Christian
    The CSV column names other than Process and PID are read defensively because they are not verified
    against every Handle.exe version.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HandleExe,

        [string]$ComputerName
    )

    $processFinder = {
        param($Name, $HandlePath)

        $signature = Get-AuthenticodeSignature -FilePath $HandlePath -ErrorAction Stop
        $isMicrosoftSigned = $signature.Status -eq 'Valid' -and
        $signature.SignerCertificate.Subject -match '(^|,\s*)O=Microsoft Corporation(,|$)'
        if (-not $isMicrosoftSigned) {
            $message = "Refusing to run '$HandlePath': it does not carry a valid Microsoft Authenticode " +
            "signature (status: $($signature.Status))."
            throw $message
        }

        $excludedIds = @(0, 4, $PID)
        & $HandlePath -accepteula -nobanner -v $Name |
            ConvertFrom-Csv |
            Where-Object { ($_.PID -as [int]) -and ([int]$_.PID -notin $excludedIds) } |
            Where-Object { -not $_.PSObject.Properties['Type'] -or $_.Type -eq 'File' } |
            ForEach-Object {
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    ProcessName = $_.Process
                    PID = [int]$_.PID
                    Path = if ($_.PSObject.Properties['Name']) {
                        $_.Name
                    } else {
                        $null
                    }
                }
            }
    }

    if ($ComputerName) {
        $invokeParams = @{
            ComputerName = $ComputerName
            ScriptBlock = $processFinder
            ArgumentList = $FileName, $HandleExe
            AsJob = $true
        }
        $job = Invoke-Command @invokeParams
    } else {
        $job = Start-Job -ScriptBlock $processFinder -ArgumentList $FileName, $HandleExe
    }

    try {
        $activity = "Searching for processes holding '$FileName'"
        $tick = 0
        # 'NotStarted' must be included; a freshly created job can report it before it begins running.
        while ($job.State -in 'NotStarted', 'Running') {
            Write-Progress -Activity $activity -Status "Please wait..." -PercentComplete ($tick % 100)
            $tick += 5
            Start-Sleep -Milliseconds 200
        }
        Write-Progress -Activity $activity -Completed

        Receive-Job -Job $job -ErrorAction Stop |
            Select-Object -Property ComputerName, ProcessName, PID, Path |
            Sort-Object -Property PID -Unique
    } finally {
        Remove-Job -Job $job -Force
    }
}

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
        try {
            $null = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
        } catch {
            throw "Could not reach WinRM on '$ComputerName': $($_.Exception.Message)"
        }
    }

    $sysinternalsPath = (Get-ToolkitConfig).SysinternalsPath
    if (-not $sysinternalsPath) {
        throw "The SysinternalsPath setting is empty. Set it in the toolkit configuration."
    }
    $handleExe = Join-Path -Path $sysinternalsPath -ChildPath 'handle.exe'

    $lockParams = @{
        FileName = $FileName
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
                    ScriptBlock = $processStopper
                    ArgumentList = $lock.PID, $lock.ProcessName
                    ErrorAction = 'Stop'
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
            ProcessName = $lock.ProcessName
            PID = $lock.PID
            Path = $lock.Path
            Result = $result
        }
    }
}

