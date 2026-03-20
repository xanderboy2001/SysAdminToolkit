#Requires -Version 5.1
#Requires -RunAsAdministrator
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

    .PARAMETER BrokerServers
    An array of Connection Broker FQDNs or hostnames to query in order. The first server that responds
    successfully determines the active broker.

    .EXAMPLE
    Get-ActiveBroker -BrokerServers @('broker1.domain.com', 'broker2.domain.com')
    broker.domain.com

    .OUTPUTS
    [System.String]. Returns the FQDN of the active broker.

    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "One or more Connection Broker FQDNs or hostnames to query in order."
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$BrokerServers
    )

    Write-Verbose "Querying RDS High Availability status..."
    foreach ($server in $BrokerServers) {
        try {
            $ActiveServer = (
                Get-RDConnectionBrokerHighAvailability -ConnectionBroker $server -ErrorAction Stop
            ).ActiveManagementServer
            break
        }
        catch {
            $msg = "Could not get active broker from ${server}: $($_.Exception.Message)"
            Write-Warning $msg
            continue
        }
    }
    if ($ActiveServer) {
        $ActiveServer
    }
    else {
        throw "Failed to determine the active broker."
    }
}

function Wait-RDMService {
    <#
    .SYNOPSIS
    Runs Get-Service on the specified computer to query the status of the 'Remote Desktop Connection Broker'
    service. The function returns when the service is started.

    .PARAMETER ComputerName
    [string] Specifies the computer to run the service status check on.

    .EXAMPLE
    Wait-RDMService -ComputerName broker.domain.com
    # Polls until all RDS services are running on broker.domain.com

    .EXAMPLE    
    Wait-RDMService -ComputerName broker.domain.com -MaxRetries 20
    # Polls up to 20 times before throwing a timeout error.

    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN or hostname of the broker server to poll for service status."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(
            Mandatory,
            HelpMessage = "Maximum number of polling attempts before throwing a timeout error."
        )]
        [int]$MaxRetries
    )

    $ServicesReady = $false
    $RetryCount = 0
    $ServiceCheckScript = { 
        Get-Service | Where-Object {
            $_.Name -eq 'rdms' -or
            $_.Name -eq 'tssdis' -or
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
                $running = [System.ServiceProcess.ServiceControllerStatus]::Running
                $status | Where-Object { $_.Status -ne $running } | ForEach-Object {
                    Write-Host "Waiting for $($_.Name) to start..." -ForegroundColor Cyan
                }
            }
        }
        catch {
            Write-Host ("Unable to query service status on $ComputerName (Attempt $RetryCount):" +
                "$($_.Exception.Message)") -ForegroundColor Yellow
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
        Wait-RDMService -ComputerName $ComputerName -MaxRetries $MaxRetries
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
        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN of the currently active Connection Broker."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ActiveBroker,
        
        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN of the broker to promote as the new active Connection Broker."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$NewActiveBroker,

        [Parameter(
            Mandatory,
            HelpMessage = "All Connection Broker FQDNs in the HA group, used to verify the switch."
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$BrokerServers
    )

    try {
        Set-RDActiveManagementServer -ManagementServer $NewActiveBroker -ErrorAction Stop
        Write-Host "Successfully set $NewActiveBroker as the active broker." -ForegroundColor Green
    }
    catch {
        throw "Fatal error when switching active brokers: $($_.Exception.Message)"
    }

    # Wait, then check if $InactiveBroker was successfully made active.
    Start-Sleep -Seconds 10
    if ((Get-ActiveBroker -BrokerServers $BrokerServers) -ne $NewActiveBroker) {
        throw ("Failed to switch the Active Management Server to $NewActiveBroker." +
            "Current active is still $ActiveBroker.")
    }
}


function Restart-RDSBroker {
    <#
    .SYNOPSIS
    Performs a staggered maintenance reboot of all RDS Connection Brokers in a High Availability group.
 
    .DESCRIPTION
    Resolves the Connection Broker server, retrieves all broker nodes in the HA group, and performs
    a controlled reboot sequence:
 
        1. Identifies the currently active and inactive brokers.
        2. Reboots each inactive broker and waits for RDS services to come back online.
        3. Promotes an inactive broker to active via Switch-ActiveBroker.
        4. Reboots the originally active broker.
 
    Timeout and retry values are read from the toolkit configuration if not supplied as parameters.
    The Connection Broker is also read from configuration if not provided.
 
    .PARAMETER BrokerServer
    Optional. The hostname or FQDN of any broker in the HA group. If not provided and not set in
    the toolkit configuration, the user is prompted.
 
    .PARAMETER TimeoutSecs
    Optional. Seconds to wait for a broker to respond after reboot. Defaults to the RDTimeoutSecs
    configuration value if 0 or not supplied.
 
    .PARAMETER MaxRetries
    Optional. Maximum number of service polling attempts per broker. Defaults to the RDMaxRetries
    configuration value if 0 or not supplied.
 
    .EXAMPLE
    Restart-RDS-Brokers -BrokerServer 'broker01'
    # Reboots all brokers in the HA group reachable via broker01.
 
    .EXAMPLE
    Restart-RDS-Brokers
    # Reads the broker server from toolkit config and performs the full reboot cycle.
 
    .NOTES
    Author: Alexander Christian
    Requires the RemoteDesktop PowerShell module and WinRM access to all broker servers.
    #>
    [CmdletBinding()]
    param(
        [string]$BrokerServer,
        [int]$TimeoutSecs,
        [int]$MaxRetries
    )

    begin {
        $config = Get-ToolkitConfig
        if ($TimeoutSecs -eq 0) {
            $TimeoutSecs = $config.RDTimeoutSecs 
        }
        if ($MaxRetries -eq 0) {
            $MaxRetries = $config.RDMaxRetries 
        }
        if (-not $BrokerServer) {
            if (-not $config.RDBrokerServer) { 
                $BrokerServer = Read-Host ("Enter the name of one of the " +
                    "Remote Desktop Connection Broker Servers (e.g. 'broker1')")
            }
            else {
                $BrokerServer = $config.RDBrokerServer
            }
        }
        try {
            $BrokerServerFQDN = [System.Net.Dns]::GetHostByName($BrokerServer).HostName.ToUpper()
        }
        catch [System.Net.Sockets.SocketException] {
            throw "Could not resolve hostname '$BrokerServer': $($_.Exception.Message)"
        }
        Write-Host "Testing connection to $BrokerServerFQDN..." -ForegroundColor Cyan
        if (-not (Test-Connection -ComputerName $BrokerServerFQDN -Count 1 -Quiet)) {
            throw "Could not connect to $BrokerServerFQDN"
        }
        Write-Host "Connection to $BrokerServerFQDN verified." -ForegroundColor Green
        try {
            Write-Host "Getting list of broker servers..." -ForegroundColor Cyan
            $ServerParams = @{
                ConnectionBroker    = $BrokerServerFQDN
                Role                = 'RDS-CONNECTION-BROKER'
                ErrorAction         = 'Stop'
            }
            $BrokerServers = (Get-RDServer @ServerParams).Server
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
            $SwitchParams = @{
                ActiveBroker = $ActiveBroker
                NewActiveBroker = $NewActiveBroker
                BrokerServers = $BrokerServers
            }
            Switch-ActiveBroker @SwitchParams
            Write-Host "Active Broker is now $NewActiveBroker" -ForegroundColor Green

            $msg = "Beginning the reboot-and-wait process for the original active broker ($ActiveBroker)..."
            Write-Host $msg -ForegroundColor Cyan
            Restart-ServerAndWait -ComputerName $ActiveBroker -TimeoutSecs $TimeoutSecs -MaxRetries $MaxRetries
            Write-Host "Reboot-and-wait process for $ActiveBroker completed." -ForegroundColor Green
        }
        catch {
            Write-Error "CRITICAL ERROR during broker maintenance: $($_.Exception.Message)"
        }
    }
}
