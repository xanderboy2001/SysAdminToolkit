function Get-BlockingProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName,
        [string]$ComputerName
    )

    $ProcessFinderCommand = {
        param($n)
        \\live.sysinternals.com\tools\handle.exe -accepteula -nobanner -v "$n"
    }

    if ($ComputerName) {
        $job = Invoke-Command -ComputerName $ComputerName `
            -ScriptBlock $ProcessFinderCommand -ArgumentList $FileName -AsJob
    }
    else {
        $job = Start-Job -ScriptBlock $ProcessFinderCommand -ArgumentList $FileName
    }

    $i = 0
    while ($job.State -eq 'Running') {
        Write-Progress -Activity "Searching for processes holding $FileName" `
            -Status "Please wait..." -PercentComplete ($i % 100)
        $i += 5
        Start-Sleep -Milliseconds 200
    }
    Write-Progress -Activity "Searching for processes holding $FileName" -Completed

    $processes = Receive-Job $job | ConvertFrom-Csv
    Remove-Job $job
    return $processes
}

function Stop-FileLock {
    [CmdletBinding()]
    param(
        [string]$FileName,
        [string]$ComputerName
    )

    begin {
        if (-not (Test-Path -Path \\live.sysinternals.com\tools\handle.exe)) {
            throw "Could not reach Sysinternals live share"
        }

        $FileName = Read-Host "Enter the name of the file being held by a process"
        $ComputerName = Read-Host "Enter the name of the computer to work with (leave blank for local machine)"

        if ($ComputerName -and -not (Test-Connection -TargetName $ComputerName -Quiet -Count 1)) {
            throw "Could not connect to $ComputerName"
        }
    }

    process {
        if ($ComputerName) {
            $processes = Get-BlockingProcesses -ComputerName $ComputerName -FileName $FileName
        }
        else {
            $processes = Get-BlockingProcesses -FileName $FileName
        }

        if ($processes) {
            $processes | ForEach-Object { Write-Host "Found process $($_.Process) ($($processes.PID))" }
            $confirmation = Read-Host "End the processes? [Y/n]"
            if ($confirmation -and $confirmation -notlike 'y') {
                return 
            }
            $processes | ForEach-Object {
                $processName = $_.Process
                $processPID = $_.PID
                try {
                    Write-Host "Ending process $processName ($processPID)..." -ForegroundColor Yellow
                    Stop-Process -Id $_.PID -Force
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
