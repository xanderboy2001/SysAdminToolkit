function Restart-ServerAndWait {
    <#
    .SYNOPSIS

        Reboots the specified server and waits for Remote Destop service to start.

    .DESCRIPTION

        This function follows the following procedure:

            1. Check to make sure the specified server is reachable using Test-Connection. If the server is not
               reachable, the function throws an error and exits.

            2. Reboot the server. This function uses the '-Wait' and '-For PowerShell' parameters to pause
               execution until PowerShell is available on the rebooted server. It times out after the time
               specified by the $TimeoutSecs variable defined at the top of the script.

            3. Run the Wait-ForRDMServices function to wait for the 'Remote Desktop Connection Broker' service to
               be fully started on the rebooted server.

            4. Wait an additional 30 seconds to allow for the Remote Desktop databases to fully synchronize
               before continuing.

    .PARAMETER ComputerName
        [string] The name of the broker to reboot. Mandatory

    .EXAMPLE

        PS> Restart-ServerAndWait broker.domain.com

    .EXAMPLE

        PS> Restart-ServerAndWait -ComputerName broker.domain.com

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN or hostname of the broker server to reboot."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(
            Mandatory,
            HelpMessage = "Seconds to wait for PowerShell to become available after reboot."
        )]
        [int]$TimeoutSecs,

        [Parameter(
            Mandatory,
            HelpMessage = "Maximum number of service polling attempts before throwing a timeout error."
        )]
        [int]$MaxRetries
    )

    try {
        Write-Host "Testing connection to $ComputerName..." -ForegroundColor Cyan
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
            Write-Host "$ComputerName is online" -ForegroundColor Green
        } else {
            throw "$ComputerName is not reachable"
        }
    } catch {
        throw "Error when pinging ${ComputerName}: $($_.Exception.Message)"
    }

    if (-not $PSCmdlet.ShouldProcess($ComputerName, 'Restart computer and wait for RDS services')) {
        return
    }
    try {
        Write-Host "Rebooting the inactive broker ($ComputerName)..." -ForegroundColor Cyan
        Restart-Computer -ComputerName $ComputerName -Force -Wait -For PowerShell -Timeout $TimeoutSecs
        Write-Host "$ComputerName has successfully rebooted." -ForegroundColor Green

        Write-Host "Waiting for Remote Desktop services to start..." -ForegroundColor Cyan
        Wait-RDMService -ComputerName $ComputerName -MaxRetries $MaxRetries
        Write-Host "Remote Desktop services have started on $ComputerName." -ForegroundColor Green

        Write-Host "Waiting 30 seconds for database syncronization..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30
        Write-Host "Database sync wait period completed." -ForegroundColor Green
    } catch {
        throw "Fatal error during reboot process: $($_.Exception.Message)"
    }
}
