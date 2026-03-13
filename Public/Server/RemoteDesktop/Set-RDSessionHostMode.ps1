function Select-RDSessionCollection {
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
