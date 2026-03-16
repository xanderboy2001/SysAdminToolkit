function Select-RDSessionCollection {
    <#
    .SYNOPSIS
    Prompts the user to select a Remote Desktop session collection from a list.

    .DESCRIPTION
    Displays a numbered list of the provided session collection names and prompts the user to enter a
    corresponding number. Continues prompting until a valid selection is made. Returns the name of the
    selected collection.

    .PARAMETER Collections
    An array of session collection name strings to present to the user.

    .EXAMPLE
    $collection = Select-RDSessionCollection -Collection @('desktops', 'apps')
    # Displays a numbered list and returns the name of the collection the user selects.
    
    .OUTPUTS
    System.String. The name of the selected session collection.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Collections
    )

    for ($i = 0; $i -lt $Collections.Count; $i++) {
        Write-Host "[$($i + 1)] $($Collections[$i])"
    }
    
    do {
        $SelectedIndex = Read-Host "Select a Remote Desktop Server Collection to manage (1-$($Collections.Count))"
        $SelectedIndex = $SelectedIndex - 1
    } until ($SelectedIndex -ge 0 -and $SelectedIndex -le $Collections.Count)

    return $Collections[$SelectedIndex]
}

function Select-Servers {
    <#
    .SYNOPSIS
    Prompts the user to select one or more Remote Desktop session hosts from a list.

    .DESCRIPTION
    Displays a numbered list of session hosts with their current connection state.
    Hosts with new connections allowed are shown in green; disabled hosts in red.
    The user may enter a comma-separated list of numbers to select multiple hosts.
    Continues prompting until all entered indices are within the valid range.
    Returns an array of the selected server objects.

    .PARAMETER Servers
    An array of objects with SessionHost and NewConnectionAllowed properties, as returned by Get-RDSessionHost
    with computed properties applied.

    .EXAMPLE
    $selected = Select-Servers -Servers $sessionHosts
    # Displays the session host list and returns the objects the user selected.
    
    .OUTPUTS
    System.Object[]. The selected session host objects.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]]$Servers
    )

    for ($i = 0; $i -lt $Servers.Count; $i++) {
        $msg = "[$($i + 1)] $($Servers[$i].SessionHost) (Connections Allowed: " +
        "$($Servers[$i].NewConnectionAllowed))"
        if ($Servers[$i].NewConnectionAllowed) {
            Write-Host $msg -ForegroundColor Green
        }
        else {
            Write-Host $msg -ForegroundColor Red
        }
    }

    do {
        $rawInput = Read-Host "Select one or more Remote Desktop Session Hosts to toggle"
        $indices = $rawInput -split ',' | ForEach-Object { [int]($_.Trim()) - 1 }
    } until ($indices | ForEach-Object { $_ -ge 0 -and $_ -le $Servers.Count })

    return $indices | ForEach-Object { $Servers[$_] }
}

function Set-RDSessionHostMode {
    <#
    .SYNOPSIS
    Toggles the connection acceptance on one or more Remote Desktop session hosts.

    .DESCRIPTION
    Resolves and verifies connectivity to the specified Connection Broker, retrieves all Remote Desktop session
    collections of type 'Remote Desktop', and prompts the user to select a collection and then one or more session
    hosts to toggle. Session hosts that currently allow new connections are disabled, and hosts that are disabled
    are enabled.

    .PARAMETER ConnectionBroker
    Optional. The hostname or FQDN of a Remote Desktop Connection Broker. If not provided, the user is prompted
    to enter one.

    .EXAMPLE
    Set-RDSessionHostMode -ConnectionBroker 'broker01'
    # Connects to broker01 and walks through collection and host selection interactively.
    
    .EXAMPLE
    Set-RDSessionHostMode
    # Prompts for the Connection Broker name, then proceeds interactively.
    
    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param(
        [string]$ConnectionBroker
    )

    if (-not $ConnectionBroker) {
        $ConnectionBroker = Read-Host "Enter the name of one of the connection brokers"
    }
    
    try {
        $ConnectionBrokerFQDN = [System.Net.Dns]::GetHostByName($ConnectionBroker).HostName
        Write-Host "Resolved '$ConnectionBroker' to '$ConnectionBrokerFQDN'" -ForegroundColor DarkGray
    }
    catch {
        throw "Could not resolve $ConnectionBroker"
    }
    Write-Host "Testing connection to $ConnectionBrokerFQDN..." -ForegroundColor Cyan
    if (-not (Test-Connection -TargetName $ConnectionBrokerFQDN -Count 1 -Quiet)) {
        throw "Could not connect to $ConnectionBrokerFQDN"
    }
    Write-Host "Connection to $ConnectionBrokerFQDN verified." -ForegroundColor Green
    
    try {
        Write-Host "Getting list of Remote Desktop Server Collections..." -ForegroundColor Cyan
        $ServerCollections = (
            Get-RDSessionCollection -ConnectionBroker $ConnectionBrokerFQDN |
                Where-Object { $_.ResourceType -eq 'Remote Desktop' } |
                Select-Object -ExpandProperty CollectionName
        ).toLower()
    }
    catch {
        throw "Error when getting list of Remote Desktop Server Collections: $($_.Exception.Message)"
    }
    if ($ServerCollections) {
        Write-Host "Found $($ServerCollections.Count) server collections." -ForegroundColor Green
    }
    else {
        throw "Could not find any server collections"
    }

    $SelectedCollection = Select-RDSessionCollection -Collections $ServerCollections

    try {
        Write-Host "Getting list of Remote Desktop Session Hosts in $SelectedCollection..." -ForegroundColor Cyan
        $SessionHostProperty = @{
            Name="SessionHost"
            Expression= {
                $_.SessionHost.toLower()
            }
        }
        $NewConnectionAllowedProperty = @{
            Name="NewConnectionAllowed"
            Expression= {
                if ($_.NewConnectionAllowed -eq 'Yes') {
                    $true 
                }
                else {
                    $false 
                }
            }
        }
        $Servers = Get-RDSessionHost -ConnectionBroker $ConnectionBrokerFQDN -CollectionName $SelectedCollection |
            Select-Object -Property $SessionHostProperty, $NewConnectionAllowedProperty |
            Sort-Object { [regex]::Replace($_.SessionHost, '\d+', { $args[0].Value.PadLeft(20) }) }
    }
    catch {
        throw "Error when getting list of Remote Desktop Session Hosts in ${SelectedCollection}: " +
        "$($_.Exception.Message)"
    }

    if ($Servers) {
        $EnabledServers = $Servers | Where-Object { $_.NewConnectionAllowed -eq $true }
        $DisabledServers = $Servers | Where-Object { $_.NewConnectionAllowed -eq $false }

        Write-Host "Found $($EnabledServers.Count) enabled servers." -ForegroundColor DarkGray
        Write-Host "Found $($DisabledServers.Count) disabled servers." -ForegroundColor DarkGray
    }
    else {
        throw "Could not find any Remote Desktop Session Hosts in $SelectedCollection"
    }

    $SelectedServers = Select-Servers -Servers $Servers
    
    foreach ($server in $SelectedServers) {
        if ($server.NewConnectionAllowed) {
            try {
                Write-Host "New connections are enabled on $($server.SessionHost). Disabling new connections..." `
                    -ForegroundColor Cyan
                Set-RDSessionHost -ConnectionBroker $ConnectionBrokerFQDN -SessionHost $server.SessionHost `
                    -NewConnectionAllowed 'No'
                Write-Host "Disabled new connections on $($server.SessionHost)" -ForegroundColor Green
            }
            catch {
                throw "Error when disabling new connections on $($server.SessionHost): $($_.Exception.Message)"
            }
        }
        else {
            try {
                Write-Host "New Connections are disabled on $($server.SessionHost). Enabling new connections..." `
                    -ForegroundColor Cyan
                Set-RDSessionHost -ConnectionBroker $ConnectionBrokerFQDN -SessionHost $server.SessionHost `
                    -NewConnectionAllowed 'Yes'
                Write-Host "Enabled new connections on $($server.SessionHost)" -ForegroundColor Green
            }
            catch {
                throw "Error while enabling new connections on $($server.SessionHost): $($_.Exception.Message)"
            }
        }
    }
}
