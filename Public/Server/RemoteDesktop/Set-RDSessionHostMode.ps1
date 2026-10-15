function Set-RDSessionHostMode {
    <#
    .SYNOPSIS
    Toggles the connection acceptance on one or more Remote Desktop session hosts.

    .DESCRIPTION
    Resolves and verifies connectivity to the specified Connection Broker, finds the active broker of its
    high-availability group, retrieves all Remote Desktop session collections of type 'Remote Desktop' from it,
    and prompts the user to select a collection and then one or more session hosts to toggle. All changes are
    sent to the active broker. Session hosts that currently allow new connections are disabled, and hosts that
    are disabled are enabled.

    .PARAMETER ConnectionBroker
    Optional. The hostname or FQDN of a Remote Desktop Connection Broker. If not provided, the user is prompted
    to enter one.

    .EXAMPLE
    Set-RDSessionHostMode -ConnectionBroker 'broker01' -WhatIf
    # Connects to broker01 and walks through collection and host selection interactively without making changes.

    .EXAMPLE
    Set-RDSessionHostMode
    # Prompts for the Connection Broker name, then proceeds interactively.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive wizard; to be split into core command + UI. See issue #1 (F-21).')]
    param(
        [string]$ConnectionBroker
    )

    if (-not $ConnectionBroker) {
        $ConnectionBroker = Read-Host "Enter the name of one of the connection brokers"
    }

    # Changes are sent to the active broker, which owns the deployment configuration in a high-availability
    # group; the broker you name may be the passive one.
    $resolvedBroker = Confirm-ConnectionBroker -ConnectionBroker $ConnectionBroker
    $ConnectionBrokerFQDN = Get-ActiveBroker -BrokerServers $resolvedBroker
    Write-Host "Using active Connection Broker $ConnectionBrokerFQDN." -ForegroundColor Green

    try {
        Write-Host "Getting list of Remote Desktop Server Collections..." -ForegroundColor Cyan
        $ServerCollections = (
            Get-RDSessionCollection -ConnectionBroker $ConnectionBrokerFQDN -ErrorAction Stop |
                Where-Object { $_.ResourceType -eq 'Remote Desktop' } |
                Select-Object -ExpandProperty CollectionName
        ).toLower()
    } catch {
        $errorParams = @{
            Message        = 'Could not get the Remote Desktop session collections from ' +
            "${ConnectionBrokerFQDN}: $($_.Exception.Message)"
            InnerException = $_.Exception
            ErrorId        = 'CollectionListFailed'
            Category       = 'ConnectionError'
            TargetObject   = $ConnectionBrokerFQDN
        }
        $PSCmdlet.ThrowTerminatingError((New-ToolkitErrorRecord @errorParams))
    }
    if ($ServerCollections) {
        Write-Host "Found $($ServerCollections.Count) server collections." -ForegroundColor Green
    } else {
        throw "Could not find any server collections"
    }

    $SelectedCollection = Select-RDSessionCollection -Collections $ServerCollections

    try {
        Write-Host "Getting list of Remote Desktop Session Hosts in $SelectedCollection..." -ForegroundColor Cyan
        $SessionHostProperty = @{
            Name       = "SessionHost"
            Expression = {
                $_.SessionHost.toLower()
            }
        }
        $NewConnectionAllowedProperty = @{
            Name       = "NewConnectionAllowed"
            Expression = {
                if ($_.NewConnectionAllowed -eq 'Yes') {
                    $true
                } else {
                    $false
                }
            }
        }
        $SessionHostParams = @{
            ConnectionBroker = $ConnectionBrokerFQDN
            CollectionName   = $SelectedCollection
            ErrorAction      = 'Stop'
        }
        $Servers = Get-RDSessionHost @SessionHostParams |
            Select-Object -Property $SessionHostProperty, $NewConnectionAllowedProperty |
            Sort-Object { [regex]::Replace($_.SessionHost, '\d+', { $args[0].Value.PadLeft(20) }) }
    } catch {
        $errorParams = @{
            Message        = "Could not get the session hosts in ${SelectedCollection}: $($_.Exception.Message)"
            InnerException = $_.Exception
            ErrorId        = 'SessionHostListFailed'
            Category       = 'ConnectionError'
            TargetObject   = $SelectedCollection
        }
        $PSCmdlet.ThrowTerminatingError((New-ToolkitErrorRecord @errorParams))
    }

    if ($Servers) {
        $EnabledServers = $Servers | Where-Object { $_.NewConnectionAllowed -eq $true }
        $DisabledServers = $Servers | Where-Object { $_.NewConnectionAllowed -eq $false }

        Write-Host "Found $($EnabledServers.Count) enabled servers." -ForegroundColor DarkGray
        Write-Host "Found $($DisabledServers.Count) disabled servers." -ForegroundColor DarkGray
    } else {
        throw "Could not find any Remote Desktop Session Hosts in $SelectedCollection"
    }

    $SelectedServers = Select-Server -Servers $Servers

    foreach ($server in $SelectedServers) {
        $newState = if ($server.NewConnectionAllowed) {
            'No'
        } else {
            'Yes'
        }
        if (-not $PSCmdlet.ShouldProcess($server.SessionHost, "Set NewConnectionAllowed to '$newState'")) {
            continue
        }
        if ($server.NewConnectionAllowed) {
            try {
                $msg = "New connections are enabled on $($server.SessionHost). Disabling new connections..."
                Write-Host $msg -ForegroundColor Cyan
                $SetRDHostParams = @{
                    ConnectionBroker     = $ConnectionBrokerFQDN
                    SessionHost          = $server.SessionHost
                    NewConnectionAllowed = 'No'
                    ErrorAction          = 'Stop'
                }
                Set-RDSessionHost @SetRDHostParams
                Write-Host "Disabled new connections on $($server.SessionHost)" -ForegroundColor Green
            } catch {
                $errorParams = @{
                    Message        = "Could not disable new connections on $($server.SessionHost): " +
                    $_.Exception.Message
                    InnerException = $_.Exception
                    ErrorId        = 'SessionHostChangeFailed'
                    Category       = 'WriteError'
                    TargetObject   = $server.SessionHost
                }
                $PSCmdlet.ThrowTerminatingError((New-ToolkitErrorRecord @errorParams))
            }
        } else {
            try {
                $msg = "New Connections are disabled on $($server.SessionHost). Enabling new connections..."
                Write-Host $msg -ForegroundColor Cyan
                $SetRDHostParams = @{
                    ConnectionBroker     = $ConnectionBrokerFQDN
                    SessionHost          = $server.SessionHost
                    NewConnectionAllowed = 'Yes'
                    ErrorAction          = 'Stop'
                }
                Set-RDSessionHost @SetRDHostParams
                Write-Host "Enabled new connections on $($server.SessionHost)" -ForegroundColor Green
            } catch {
                $errorParams = @{
                    Message        = "Could not enable new connections on $($server.SessionHost): " +
                    $_.Exception.Message
                    InnerException = $_.Exception
                    ErrorId        = 'SessionHostChangeFailed'
                    Category       = 'WriteError'
                    TargetObject   = $server.SessionHost
                }
                $PSCmdlet.ThrowTerminatingError((New-ToolkitErrorRecord @errorParams))
            }
        }
    }
}
