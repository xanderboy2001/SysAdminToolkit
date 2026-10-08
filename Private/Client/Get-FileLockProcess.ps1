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
