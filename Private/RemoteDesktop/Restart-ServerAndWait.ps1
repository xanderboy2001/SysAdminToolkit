function Restart-ServerAndWait {
    <#
    .SYNOPSIS
        Reboots a Connection Broker and waits until its RDS services are running again.

    .DESCRIPTION
    1. Checks that the server answers a ping. If not, throws before rebooting anything.
    2. Reboots the server and waits until PowerShell remoting is available again (Restart-Computer -Wait
       -For PowerShell), for up to TimeoutSecs.
    3. Waits for the RDS broker services with Wait-RDMService.
    4. Waits 30 more seconds so the broker databases can synchronize.

    A failure in steps 2-4 throws an error that names the server and the step that failed, with the original
    error as the inner exception.

    .PARAMETER ComputerName
    The broker to reboot.

    .PARAMETER TimeoutSecs
    Seconds to wait for PowerShell remoting to be available after the reboot.

    .PARAMETER MaxRetries
    Number of service checks passed to Wait-RDMService.

    .EXAMPLE
    Restart-ServerAndWait -ComputerName broker2.domain.com -TimeoutSecs 600 -MaxRetries 15

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, HelpMessage = "The FQDN or hostname of the broker server to reboot.")]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory, HelpMessage = "Seconds to wait for PowerShell to become available after reboot.")]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSecs,

        [Parameter(Mandatory, HelpMessage = "Number of service checks before throwing a timeout error.")]
        [ValidateRange(1, 1000)]
        [int]$MaxRetries
    )

    Write-Information "Testing connection to $ComputerName..."
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        throw "$ComputerName is not reachable. It was not rebooted."
    }

    if (-not $PSCmdlet.ShouldProcess($ComputerName, 'Restart computer and wait for RDS services')) {
        return
    }

    $step = "reboot"
    try {
        Write-Information "Rebooting $ComputerName (waiting up to ${TimeoutSecs}s for it to come back)..."
        # -ErrorAction Stop: a reboot that times out must stop the procedure, not just print the error.
        $restartParams = @{
            ComputerName = $ComputerName
            Force = $true
            Wait = $true
            For = "PowerShell"
            Timeout = $TimeoutSecs
            ErrorAction = "Stop"
        }
        Restart-Computer @restartParams
        Write-Information "$ComputerName is back online."

        $step = "wait for RDS services"
        Write-Information "Waiting for Remote Desktop services to start on $ComputerName..."
        Wait-RDMService -ComputerName $ComputerName -MaxRetries $MaxRetries
        Write-Information "Remote Desktop services are running on $ComputerName."

        $step = "database synchronization wait"
        Write-Information "Waiting 30 seconds for database synchronization..."
        Start-Sleep -Seconds 30
    } catch {
        throw [System.InvalidOperationException]::new(
            "$ComputerName failed during step '$step': $($_.Exception.Message)", $_.Exception
        )
    }
}
