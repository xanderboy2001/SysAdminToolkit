
function Invoke-ADSync {
    <#
    .SYNOPSIS
    Triggers a delta synchronization cycle on the configured AD Connect server and waits for it to finish.

    .DESCRIPTION
    Resolves and verifies connectivity to the AD Connect server from the toolkit configuration (or prompts for one
    if not configured), then runs Invoke-ADSyncDeltaCycle on that server through Invoke-Command.

    The wait is bounded: if the cycle is still running after TimeoutSeconds, a non-terminating error is written
    and the cycle keeps running on the server. If a cycle is already running, no new cycle is started and a
    warning is shown.

    .PARAMETER TimeoutSeconds
    Maximum time to wait for the cycle to finish. Defaults to the ADSyncTimeoutSecs configuration value.

    .EXAMPLE
    Invoke-ADSync
    # Triggers a delta sync on the configured AD Connect server and waits up to ADSyncTimeoutSecs for completion.

    .EXAMPLE
    Invoke-ADSync -TimeoutSeconds 300 -WhatIf
    # Shows which server would be synchronized without starting a cycle.

    .NOTES
    Author: Alexander Christian
    Requires the ADSync module on the target AD Connect server and WinRM access to it.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive wizard; to be split into core command + UI. See issue #1 (F-21).')]
    param(
        [ValidateRange(0, 86400)]
        [int]$TimeoutSeconds
    )
    Show-MenuHeader -Title 'Run AD Delta Sync'
    Write-Host 'This script triggers an Active Directory Delta sync.' -ForegroundColor Yellow

    $config = Get-ToolkitConfig
    if ($TimeoutSeconds -eq 0) {
        $TimeoutSeconds = $config.ADSyncTimeoutSecs
    }
    if ($TimeoutSeconds -lt 1) {
        # Missing or invalid configuration value: fall back to 30 minutes rather than waiting forever.
        $TimeoutSeconds = 1800
    }
    $ADConnectServer = $config.ADConnectServer

    if (-not $ADConnectServer) {
        $ADConnectServer = Read-Host "Enter the name of the AD Connect Server"
    }

    try {
        $ADConnectServerResolved = [System.Net.Dns]::GetHostByName($ADConnectServer).HostName
    } catch [System.Net.Sockets.SocketException] {
        throw "Could not resolve hostname '$ADConnectServer': $($_.Exception.Message)"
    }
    Write-Verbose "Verifying connection to $ADConnectServerResolved..."
    if (-not (Test-Connection -ComputerName $ADConnectServerResolved -Count 1 -Quiet)) {
        throw "$ADConnectServerResolved is not reachable"
    }
    Write-Host "Connection to $ADConnectServerResolved verified." -ForegroundColor Green

    if (-not $PSCmdlet.ShouldProcess($ADConnectServerResolved, "Start Entra Connect delta sync cycle")) {
        return
    }

    $invokeParams = @{
        ComputerName = $ADConnectServerResolved
        # The function body runs remotely, so it must not depend on anything else in this module.
        ScriptBlock  = ${Function:Invoke-ADSyncDeltaCycle}
        ArgumentList = $TimeoutSeconds
        ErrorAction  = "Stop"
    }
    try {
        Write-Verbose "Beginning delta sync on $ADConnectServerResolved (timeout ${TimeoutSeconds}s)..."
        $result = Invoke-Command @invokeParams
    } catch {
        Write-Error "Fatal error during AD Delta Sync: $($_.Exception.Message)"
        return
    }

    switch ($result.Status) {
        "Completed" {
            Write-Host "AD Sync complete ($($result.ElapsedSeconds)s)." -ForegroundColor Green
        }
        "StartNotObserved" {
            Write-Warning ("The sync cycle was triggered but never observed running. It may have finished " +
                "quickly; confirm in Synchronization Service Manager if needed.")
        }
        "AlreadyRunning" {
            Write-Warning ("A sync cycle is already running on $ADConnectServerResolved. " +
                "No new cycle was started.")
        }
        "TimedOut" {
            Write-Error ("The sync cycle on $ADConnectServerResolved was still running after " +
                "${TimeoutSeconds}s. It continues on the server; check Synchronization Service Manager.")
        }
        default {
            Write-Error "Unexpected result from ${ADConnectServerResolved}: '$($result.Status)'."
        }
    }
}
