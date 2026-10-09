function Invoke-ADSyncDeltaCycle {
    <#
    .SYNOPSIS
    Starts an Entra Connect delta sync cycle and waits for it to finish, with time limits.

    .DESCRIPTION
    Runs ON the Entra Connect (AD Connect) server. Invoke-ADSync sends this function's script block there through
    Invoke-Command, so it must stay self-contained: it may only call built-in cmdlets and the ADSync module.

    Uses (Get-ADSyncScheduler).SyncCycleInProgress, a single boolean for the whole cycle, instead of per-connector
    run states. Returns one object whose Status is:
    - Completed        : the cycle was seen running and then finished.
    - StartNotObserved : the cycle was triggered but never seen running within StartTimeoutSeconds. It may have
                         finished between two polls; check Synchronization Service Manager if in doubt.
    - AlreadyRunning   : a cycle was already in progress, so no new cycle was started.
    - TimedOut         : the cycle was still running after TimeoutSeconds. It keeps running on the server.

    Polling is counted in iterations rather than wall-clock time so the logic is deterministic under test.

    .PARAMETER TimeoutSeconds
    Maximum time to wait for a running cycle to finish.

    .PARAMETER StartTimeoutSeconds
    Maximum time to wait for a triggered cycle to show as running.

    .PARAMETER PollSeconds
    Delay between status checks.

    .OUTPUTS
    PSCustomObject with ComputerName, Status, and ElapsedSeconds.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 1800,

        [ValidateRange(1, 3600)]
        [int]$StartTimeoutSeconds = 60,

        [ValidateRange(1, 60)]
        [int]$PollSeconds = 2
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $activity = "Entra Connect delta sync on $env:COMPUTERNAME"

    $newResult = {
        param([string]$Status)
        [pscustomobject]@{
            ComputerName   = $env:COMPUTERNAME
            Status         = $Status
            ElapsedSeconds = [int]$stopwatch.Elapsed.TotalSeconds
        }
    }

    Import-Module -Name ADSync -ErrorAction Stop

    if ((Get-ADSyncScheduler -ErrorAction Stop).SyncCycleInProgress) {
        return & $newResult 'AlreadyRunning'
    }

    $null = Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop

    # Phase 1: wait for the cycle to show as running.
    $started = $false
    $maxStartPolls = [math]::Ceiling($StartTimeoutSeconds / $PollSeconds)
    for ($poll = 1; $poll -le $maxStartPolls; $poll++) {
        if ((Get-ADSyncScheduler -ErrorAction Stop).SyncCycleInProgress) {
            $started = $true
            break
        }
        Write-Progress -Activity $activity -Status "Waiting for the cycle to start..."
        Start-Sleep -Seconds $PollSeconds
    }
    if (-not $started) {
        Write-Progress -Activity $activity -Completed
        return & $newResult "StartNotObserved"
    }

    # Phase 2: wait for the cycle to finish.
    $maxRunPolls = [math]::Ceiling($TimeoutSeconds / $PollSeconds)
    for ($poll = 1; $poll -le $maxRunPolls; $poll++) {
        Write-Progress -Activity $activity -Status "Running ($([int]$stopwatch.Elapsed.TotalSeconds)s)..."
        Start-Sleep -Seconds $PollSeconds
        if (-not (Get-ADSyncScheduler -ErrorAction Stop).SyncCycleInProgress) {
            Write-Progress -Activity $activity -Completed
            return & $newResult "Completed"
        }
    }

    Write-Progress -Activity $activity -Completed
    & $newResult "TimedOut"
}
