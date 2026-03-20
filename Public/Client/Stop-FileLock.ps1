function Get-BlockingProcesses {
    <#
    .SYNOPSIS
    Returns a list of processes currently holding a lock on the specified file.

    .DESCRIPTION
    Uses Sysinternals Handle.exe to identify processes that have an open handle to the specified file.
    The search is run as a background job, either locally or on a remote computer via Invoke-Command.
    A progress indicator is displayed while the job runs. Results are returned as a collection of parsed objects
    from Handle.exe CSV output.

    .PARAMETER FileName
    The name or path of the file to check for blocking processes.

    .PARAMETER HandleExe
    The full path to the Handle.exe Sysinternals utility.

    .PARAMETER ComputerName
    Optional. The name of the remote computer to run the check on.
    If omitted, the check runs on the local machine.
    .EXAMPLE
    Get-BlockingProcess -FileName 'report.xlsx' -HandleExe '\\live.sysinternals.com\tools\handle.exe'
    # Finds processes on the local machine blocking report.xlsx.

    .EXAMPLE
    Get-BlockingProcess -FileName 'data.csv' -HandleExe 'C:\tools\handle.exe' -ComputerName 'WORKSTATION1'
    # Finds processes on WORKSTATION1 blocking data.csv.

    .OUTPUTS
    System.Object[]. A collection of parsed objects representing blocking processes, each with properties such
    as Process and PID.

    .NOTES
    Author: Alexander Christian
    Requires Sysinternals Handle.exe, The -accepteula flag is passed automatically.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$HandleExe,
        [string]$ComputerName
    )

    $ProcessFinderCommand = {
        param($n, $h)
        & $h -accepteula -nobanner -v "$n"
    }

    if ($ComputerName) {
        $InvokeParams = @{
            ComputerName    = $ComputerName
            ScriptBlock     = $ProcessFinderCommand
            ArgumentList    = $FileName, $HandleExe
            AsJob           = $true
        }
        $job = Invoke-Command @InvokeParams
    }
    else {
        $job = Start-Job -ScriptBlock $ProcessFinderCommand -ArgumentList $FileName, $HandleExe
    }

    $i = 0
    while ($job.State -eq 'Running') {
        $ProgressParams = @{
            Activity        = "Searching for processes holding $FileName"
            Status          = "Please wait..."
            PercentComplete = $i % 100
        }
        Write-Progress @ProgressParams
        $i += 5
        Start-Sleep -Milliseconds 200
    }
    Write-Progress -Activity "Searching for processes holding $FileName" -Completed

    $processes = Receive-Job -Job $job | ConvertFrom-Csv
    Remove-Job -Job $job
    $processes
}

function Stop-FileLock {
    <#
    .SYNOPSIS
    Identifies and terminates processes holding a lock on a specified file.

    .DESCRIPTION
    Prompts for filename and an optional remote computer name, then uses Handl.exe to identify any processes
    with an open handle on that file. If blocking processes are found, they are listed and the user is prompted
    to confirm before each is forcibly terminated with Stop-Process. The Sysinternals path is read from the 
    toolkit configuration via Get-ToolkitConfig.

    .PARAMETER FileName
    Optional. The name or path of the locked file. If not provided, the user is prompted.

    .PARAMETER ComputerName
    Optional. The name of a remote computer to target. If not provided, the user is prompted and may leave blank
    to target the local machine.

    .EXAMPLE
    Stop-FileLock
    # Prompts for a filename and computer name, then unlocks the file if processes are found.

    .NOTES
    Author: Alexander Christian
    Rewuires Sysinternals Handle.exe. The path is read from the SysinternalsPath toolkit config key.
    #>
    [CmdletBinding()]
    param(
        [string]$FileName,
        [string]$ComputerName
    )

    begin {
        $sysinternalsPath = (Get-ToolkitConfig).SysinternalsPath
        $handleExe = Join-Path $sysinternalsPath "handle.exe"

        $FileName = Read-Host "Enter the name of the file being held by a process"
        $ComputerName = Read-Host "Enter the name of the computer to work with (leave blank for local machine)"

        if ($ComputerName -and -not (Test-Connection -ComputerName $ComputerName -Quiet -Count 1)) {
            throw "Could not connect to $ComputerName"
        }
    }

    process {
        if ($ComputerName) {
            $BlockingParams = @{
                ComputerName    = $ComputerName
                FileName        = $FileName
                HandleExe   = $handleExe
            }
            $processes = Get-BlockingProcesses @BlockingParams
        }
        else {
            $processes = Get-BlockingProcesses -FileName $FileName -HandleExe $handleExe
        }

        if ($processes) {
            $processes | ForEach-Object { Write-Host "Found process $($_.Process) ($($_.PID))" }
            $confirmation = Read-Host "End the processes? [Y/n]"
            if ($confirmation -and $confirmation -notlike 'y') {
                return 
            }
            $processes | ForEach-Object {
                $processName = $_.Process
                $processPID = $_.PID
                try {
                    Write-Host "Ending process $processName ($processPID)..." -ForegroundColor Yellow
                    Stop-Process -Id $processPID -Force -ErrorAction Stop
                    Write-Host "Ended process $processName ($processPID)" -ForegroundColor Yellow
                }
                catch {
                    throw "Fatal error when ending process $processName ($processPID): $($_.Exception.Message)"
                }
            }
            Write-Host "Ended all processes holding $FileName" -ForegroundColor Green
        }
        else {
            Write-Host "No processes found."
        }
    }
}
