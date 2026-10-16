function Invoke-ADSync {
    <#
    .SYNOPSIS
    Runs an Entra Connect (AD Connect) delta sync cycle and waits for it to finish.

    .DESCRIPTION
    Checks that the AD Connect server resolves and accepts PowerShell remoting, then runs Invoke-ADSyncDeltaCycle
    on it through Invoke-Command. It never prompts, so it can be used in scripts and scheduled tasks. Returns one
    result object.

    Result Status values:
    - Completed        : the cycle ran and finished.
    - StartNotObserved : the cycle was triggered but never seen running; it may have finished quickly. A warning
                         is written.
    - AlreadyRunning   : a cycle was already running, so no new cycle was started. A warning is written.
    - TimedOut         : the cycle was still running after TimeoutSeconds. It keeps running on the server. A
                         non-terminating error (SysAdminToolkit.SyncTimedOut) is written.

    If the server cannot be reached or the remote command fails, a terminating error is thrown
    (SysAdminToolkit.SyncFailed, or the error from Resolve-ToolkitHost) that keeps the original exception.

    For the interactive version, use Start-ToolkitMenu: Server > Active Directory > Start AD Sync.

    .PARAMETER ComputerName
    Optional. The AD Connect server. Defaults to the ADConnectServer configuration value. If neither is set, the
    command fails with a clear error.

    .PARAMETER TimeoutSeconds
    Optional. Maximum time to wait for the cycle to finish. Defaults to the ADSyncTimeoutSecs configuration value,
    or 1800 seconds if that is not set.

    .EXAMPLE
    Invoke-ADSync
    # Runs a delta sync on the configured AD Connect server and returns the result.

    .EXAMPLE
    Invoke-ADSync -ComputerName 'adconnect01' -TimeoutSeconds 300 -WhatIf
    # Shows which server would be synchronized without starting a cycle.

    .EXAMPLE
    if ((Invoke-ADSync).Status -ne 'Completed') { Write-Warning 'Delta sync did not complete.' }
    # Use in a script.

    .OUTPUTS
    PSCustomObject with ComputerName, Status, and ElapsedSeconds.

    .NOTES
    Author: Alexander Christian
    Requires the ADSync module on the AD Connect server and WinRM access to it.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string]$ComputerName,

        [ValidateRange(0, 86400)]
        [int]$TimeoutSeconds
    )

    $config = Get-ToolkitConfig
    if (-not $ComputerName) {
        $ComputerName = $config.ADConnectServer
    }
    if (-not $ComputerName) {
        $errorParams = @{
            Message  = 'No AD Connect server given. Use -ComputerName, or set ADConnectServer in the toolkit ' +
            'configuration.'
            ErrorId  = 'ADConnectServerMissing'
            Category = 'InvalidArgument'
        }
        $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
    }

    if ($TimeoutSeconds -eq 0) {
        $TimeoutSeconds = $config.ADSyncTimeoutSecs
    }
    if ($TimeoutSeconds -lt 1) {
        # Missing or invalid configuration value: fall back to 30 minutes rather than waiting forever.
        $TimeoutSeconds = 1800
    }

    $server = Resolve-ToolkitHost -Name $ComputerName -RequireWinRM

    if (-not $PSCmdlet.ShouldProcess($server, 'Start Entra Connect delta sync cycle')) {
        return
    }

    $invokeParams = @{
        ComputerName = $server
        # The function body runs remotely, so it must not depend on anything else in this module.
        ScriptBlock  = ${function:Invoke-ADSyncDeltaCycle}
        ArgumentList = $TimeoutSeconds
        ErrorAction  = 'Stop'
    }
    try {
        Write-Verbose "Starting a delta sync on $server (timeout ${TimeoutSeconds}s)..."
        $remote = Invoke-Command @invokeParams
    } catch {
        $errorParams = @{
            Message        = "The delta sync on $server failed: $($_.Exception.Message)"
            InnerException = $_.Exception
            ErrorId        = 'SyncFailed'
            Category       = 'OperationStopped'
            TargetObject   = $server
        }
        $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
    }

    $status = [string]$remote.Status
    switch ($status) {
        'StartNotObserved' {
            Write-Warning ('The sync cycle was triggered but never observed running. It may have finished ' +
                'quickly; confirm in Synchronization Service Manager if needed.')
        }
        'AlreadyRunning' {
            Write-Warning "A sync cycle is already running on $server. No new cycle was started."
        }
        'TimedOut' {
            $errorParams = @{
                Message      = "The sync cycle on $server was still running after ${TimeoutSeconds}s. It " +
                'continues on the server; check Synchronization Service Manager.'
                ErrorId      = 'SyncTimedOut'
                Category     = 'OperationTimeout'
                TargetObject = $server
            }
            $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
        }
        'Completed' { }
        default {
            $errorParams = @{
                Message      = "Unexpected result from ${server}: '$status'."
                ErrorId      = 'SyncUnexpectedResult'
                Category     = 'InvalidResult'
                TargetObject = $server
            }
            $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
        }
    }

    [pscustomobject]@{
        ComputerName   = $server
        Status         = $status
        ElapsedSeconds = $remote.ElapsedSeconds
    }
}
