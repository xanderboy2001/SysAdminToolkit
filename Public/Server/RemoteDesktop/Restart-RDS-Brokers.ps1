#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS

    Automates the maintenance reboot cycle for two Remote Desktop Services (RDS) Connection Brokers configured
    in High Availability

.DESCRIPTION

    This script performs a controlled, staggered reboot of the two RDS Connection Brokers to ensure continuous
    availability during maintenance.

    The script follows the following procedure:

        1. Determines the currently Active and Inactive broker nodes.
        2. Reboots the Inactive broker and waits for the 'Remote Desktop Connection Broker' service to come
           back online.
        3. Switches the Active Management Server role to the newly rebooted (formerly inactive) broker.
        4. Reboots the broker that was originally Active (now the inactive node).

    The script utilizes transcript logging to record all operations and errors to a specific log file. It
    includes error handling to stop execution if critical steps (such as determining the active broker or
    switching roles) fail.

.NOTES

    File Name     : Reboot_RDS_Brokers.ps1
    Author        : Alexander Christian
    Updated       : 02-27-2026
    Prerequisite  : This script must be run with administrative privileges on a server with the RDS PowerShell
                    modules installed.
    Requirements  : 
        - Remote Desktop Services module (for Get-RDConnectionBrokerHighAvailability,
          Set-RDActiveManagementServer).
        - Remote PowerShell (WinRM) access to both broker servers.
        - Administrative rights on both broker servers.

    Configuration : Before running, verify the variables in the 'Configuration' section:
                    - $Broker1FQDN: Fully Qualified Domain Name of the first broker.
                    - $Broker2FQDN: Fully Qualified Domain Name of the second broker.
                    - $LogDir: Directoryy where the transcript log will be saved.
                    - $TimeoutSecs: Timeout for the Restart-Computer command.
                    - $MaxRetries: Retry limit for waiting for services to start.

.EXAMPLE
    PS C:\Scripts\> .\Reboot_RDS_Brokers.ps1

    Runs the maintenance cycle. The script does not accept parameters; it relies on the configuration variables
    defined at the top of the script.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    None.

#>
[CmdletBinding()]
param()

function Get-ActiveBroker {
    <#
    .SYNOPSIS

        Uses Get-RDConnectionBrokerHighAvailability to query RD Connection Broker server information.
        It then returns the FQDN of the active broker.

    .DESCRIPTION

        Since broker1 and broker2 are configured in High Availability, we can use either in the
        '-ConnectionBroker' parameter. This function uses broker1 first, and if that fails for whatever reason,
        the function will try to get the active broker from broker2. If both fail or return nothing, the
        function throws an error.

    .EXAMPLE

        PS> Get-ActiveBroker
        broker.domain.com

    .OUTPUTS

        [System.String]. Returns the FQDN of the active broker.

    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$BrokerServers
    )

    Write-Host "Querying RDS High Availability status..." -ForegroundColor Cyan
    foreach ($server in $BrokerServers) {
        try {
            $ActiveServer = (
                Get-RDConnectionBrokerHighAvailability -ConnectionBroker $server
            ).ActiveManagementServer
            break
        }
        catch {
            Write-Host "Could not get active broker from ${server}: $($_.Exception.Message)" `
                -ForegroundColor Yellow
            continue
        }
    }
    if ($ActiveServer) {
        return $ActiveServer
    }
    else {
        throw "Failed to determine the active broker."
    }
}

function Wait-ForRDMServices {
    <#
    .SYNOPSIS

        Runs Get-Service on the specified computer to query the status of the 'Remote Desktop Connection Broker'
        service. The function returns when the service is started.

    .PARAMETER ComputerName
        [string] Specifies the computer to run the service status check on.

    .EXAMPLE
        
        PS> Wait-ForRDMServices broker.domain.com

    .EXAMPLE
        
        PS> Wait-ForRDMServices -ComputerName broker.domain.com

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        [Parameter(Mandatory)]
        [int]$MaxRetries
    )

    $ServicesReady = $false
    $RetryCount = 0
    $ServiceCheckScript = { 
        Get-Service | Where-Object {
            $_.Name -eq 'rdms' -or `
                $_.Name -eq 'tssdis' -or `
                $_.Name -eq 'tscpubrpc'
        } | Select-Object -Property Name, Status
    }

    do {
        try {
            Start-Sleep -Seconds 30
            $status = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ServiceCheckScript -ErrorAction Stop
            
            # Print status of all services
            Write-Host "Service status on ${ComputerName}:" -ForegroundColor DarkGray
            $status | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Status)" -ForegroundColor DarkGray
            }

            $allRunning = ($status | Where-Object { $_.Status -ne 4 }).Count -eq 0

            if ($allRunning) {
                $ServicesReady = $true
            }
            else {
                $status | Where-Object { $_.Status -ne 4 } | ForEach-Object {
                    Write-Host "Waiting for $($_.Name) to start..." -ForegroundColor Cyan
                }
            }
        }
        catch {
            Write-Host "Unable to query service status on $ComputerName (Attempt $RetryCount):" + `
                "$($_.Exception.Message)" -ForegroundColor Yellow
        }
        $RetryCount++
    } until ($ServicesReady -eq $true -or $RetryCount -gt $MaxRetries)

    if ($ServicesReady) {
        return
    }
    else {
        throw "RDS Service failed to start on $ComputerName within the timeout period."
    }
}

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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        [Parameter(Mandatory)]
        [int]$TimeoutSecs,
        [Parameter(Mandatory)]
        [int]$MaxRetries
    )

    try {
        Write-Host "Testing connection to $ComputerName..." -ForegroundColor Cyan
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
            Write-Host "$ComputerName is online" -ForegroundColor Green
        }
        else {
            throw "$ComputerName is not reachable"
        }
    }
    catch {
        throw "Error when pinging ${ComputerName}: $($_.Exception.Message)"
    }

    try {
        Write-Host "Rebooting the inactive broker ($ComputerName)..." -ForegroundColor Cyan
        Restart-Computer -ComputerName $ComputerName -Force -Wait -For PowerShell -Timeout $TimeoutSecs
        Write-Host "$ComputerName has successfully rebooted." -ForegroundColor Green
        
        Write-Host "Waiting for Remote Desktop services to start..." -ForegroundColor Cyan
        Wait-ForRDMServices $ComputerName -MaxRetries $MaxRetries
        Write-Host "Remote Desktop services have started on $ComputerName." -ForegroundColor Green

        Write-Host "Waiting 30 seconds for database syncronization..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30
        Write-Host "Database sync wait period completed." -ForegroundColor Green
    }
    catch {
        throw "Fatal error during reboot process: $($_.Exception.Message)"    
    }
}

function Switch-ActiveBroker {
    <#
    .SYNOPSIS

        Switches the active broker of RDS from the currently active server to the currently inactive server.
        Throws an error if the switch did not apply after 10 seconds.

    .PARAMETER ActiveBroker
        [string] The FQDN of the currently active broker. Mandatory
    
    .PARAMETER InactiveBroker
        [string] The FQDN of the currently inactive broker. Mandatory.

    .EXAMPLE

        PS> Switch-ActiveBroker broker1.domain.com broker2.domain.com

    .EXAMPLE

        PS> SwitchActiveBroker -ActiveBroker broker1.domain.com -InactiveBroker broker2.domain.com

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ActiveBroker,
        
        [Parameter(Mandatory)]
        [string]$NewActiveBroker,

        [Parameter(Mandatory)]
        [string[]]$BrokerServers
    )

    try {
        Set-RDActiveManagementServer -ManagementServer $NewActiveBroker
        Write-Host "Successfully set $NewActiveBroker as the active broker." -ForegroundColor Green
    }
    catch {
        throw "Fatal error when switching active brokers: $($_.Exception.Message)"
    }

    # Wait, then check if $InactiveBroker was successfully made active.
    Start-Sleep -Seconds 10
    if ((Get-ActiveBroker -BrokerServers $BrokerServers) -ne $NewActiveBroker) {
        throw ("Failed to switch the Active Management Server to $NewActiveBroker." + `
                "Current active is still $ActiveBroker.")
    }
}


function Restart-RDS-Brokers {
    [CmdletBinding()]
    param(
        [string]$BrokerServer,
        [int]$TimeoutSecs = 600,    # 10 minutes
        [int]$MaxRetries = 15
    )

    begin {
        if (-not $BrokerServer) {
            $BrokerServer = Read-Host "Enter the name of one of the Remote Desktop Connection Broker Servers" + `
                " (e.g. 'broker1')"
        }
        $BrokerServerFQDN = [System.Net.Dns]::GetHostByName($BrokerServer).HostName.ToUpper()
        Write-Host "Testing connection to $BrokerServerFQDN..." -ForegroundColor Cyan
        if (-not (Test-Connection -TargetName $BrokerServerFQDN -Count 1 -Quiet)) {
            throw "Could not connect to $BrokerServerFQDN"
        }
        Write-Host "Connection to $BrokerServerFQDN verified." -ForegroundColor Green
        try {
            Write-Host "Getting list of broker servers..." -ForegroundColor Cyan
            $BrokerServers = (Get-RDServer -ConnectionBroker $BrokerServerFQDN -Role RDS-CONNECTION-BROKER).Server
            Write-Host "Retrieved list of broker servers." -ForegroundColor Green
        }
        catch {
            throw "Failed to get list of broker servers."
        }
    }

    process {
        try {
            $ActiveBroker = (Get-ActiveBroker -BrokerServers $BrokerServers).ToUpper()
            $InactiveBrokers = @($BrokerServers | Where-Object { $_ -ne $ActiveBroker })

            Write-Host "Current Active Broker`t: $ActiveBroker" -ForegroundColor DarkGray
            Write-Host "Inactive Broker(s)`t: $($InactiveBrokers -join ', ')" -ForegroundColor DarkGray

            foreach ($broker in $InactiveBrokers) {

                Write-Host "Beginning reboot-and-wait process for $broker..." -ForegroundColor Cyan
                Restart-ServerAndWait -ComputerName $broker -TimeoutSecs $TimeoutSecs -MaxRetries $MaxRetries
                Write-Host "Reboot-and-wait process for $broker completed." -ForegroundColor Green
            }

            $NewActiveBroker = $InactiveBrokers[0]
            Write-Host "Switching active broker from $ActiveBroker to $NewActiveBroker..." -ForegroundColor Cyan
            Switch-ActiveBroker `
                -ActiveBroker $ActiveBroker `
                -NewActiveBroker $NewActiveBroker `
                -BrokerServers $BrokerServers
            Write-Host "Active Broker is now $NewActiveBroker" -ForegroundColor Green

            Write-Host "Beginning the reboot-and-wait process for the original active broker ($ActiveBroker)..." `
                -ForegroundColor Cyan
            Restart-ServerAndWait -ComputerName $ActiveBroker -TimeoutSecs $TimeoutSecs -MaxRetries $MaxRetries
            Write-Host "Reboot-and-wait process for $ActiveBroker completed." -ForegroundColor Green
        }
        catch {
            Write-Error "CRITICAL ERROR during broker maintenance: $($_.Exception.Message)"
        }
    }
}
