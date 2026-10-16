function Set-RDSessionHostMode {
    <#
    .SYNOPSIS
    Allows or blocks new connections on Remote Desktop session hosts.

    .DESCRIPTION
    Sets NewConnectionAllowed to the value you give (Yes or No) on each session host, through the active Connection
    Broker of the deployment. It never prompts for a broker, collection, or host, so it can be used in scripts.
    Running it twice with the same value changes nothing the second time. Returns one result object per host.

    - Hosts already in the requested state are left alone and reported with Result 'Unchanged'.
    - A host that is not found in the searched collections writes a non-terminating error
      (SysAdminToolkit.SessionHostNotFound) and the other hosts are still processed.
    - A failed change writes an error (SysAdminToolkit.SessionHostChangeFailed) and returns Result 'Failed'.

    Changes ask for confirmation (ConfirmImpact Medium) when $ConfirmPreference is Medium or lower; use -Confirm
    to always ask, or -WhatIf to see what would change.

    For the interactive version that lets you pick a collection and hosts from menus, use Start-ToolkitMenu:
    Server > Remote Desktop > Allow or block new connections.

    .PARAMETER SessionHost
    One or more session hosts, as short names ('rds1') or FQDNs. 'rds1' does not match 'rds10'. Accepts
    pipeline input, including objects with a SessionHost property such as the output of Get-RDConnectedUser.

    .PARAMETER NewConnectionAllowed
    Yes to allow new connections, No to block them. Existing sessions are not affected.

    .PARAMETER ConnectionBroker
    Optional. The host name or FQDN of any Connection Broker in the deployment. Defaults to the RDBrokerServer
    configuration value. The active broker of its high-availability group is used.

    .PARAMETER CollectionName
    Optional. The session collections to search for the hosts. Defaults to every Remote Desktop collection.

    .EXAMPLE
    Set-RDSessionHostMode -SessionHost 'rds1', 'rds2' -NewConnectionAllowed No
    # Blocks new connections on rds1 and rds2 before maintenance.

    .EXAMPLE
    Set-RDSessionHostMode -SessionHost 'rds1' -NewConnectionAllowed Yes -WhatIf
    # Shows whether rds1 would change, without changing it.

    .OUTPUTS
    PSCustomObject with SessionHost, CollectionName, PreviousState, NewConnectionAllowed, and Result
    ('Changed', 'Unchanged', or 'Failed').

    .NOTES
    Author: Alexander Christian
    Requires the RemoteDesktop module and WinRM access to the Connection Broker.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$SessionHost,

        [Parameter(Mandatory)]
        [ValidateSet('Yes', 'No')]
        [string]$NewConnectionAllowed,

        [string]$ConnectionBroker,

        [ValidateNotNullOrWhiteSpace()]
        [string[]]$CollectionName
    )

    begin {
        if (-not $ConnectionBroker) {
            $ConnectionBroker = (Get-ToolkitConfig).RDBrokerServer
        }
        if (-not $ConnectionBroker) {
            $errorParams = @{
                Message  = 'No Connection Broker given. Use -ConnectionBroker, or set RDBrokerServer in the ' +
                'toolkit configuration.'
                ErrorId  = 'ConnectionBrokerMissing'
                Category = 'InvalidArgument'
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }

        # Changes go to the active broker, which owns the deployment configuration in a high-availability group.
        $resolvedBroker = Confirm-ConnectionBroker -ConnectionBroker $ConnectionBroker
        $activeBroker = Get-ActiveBroker -BrokerServers $resolvedBroker
        Write-Verbose "Using active Connection Broker $activeBroker."

        if (-not $CollectionName) {
            try {
                $CollectionName = @(Get-RDCollectionName -ConnectionBroker $activeBroker)
            } catch {
                $errorParams = @{
                    Message        = "Could not get the session collections from ${activeBroker}: " +
                    $_.Exception.Message
                    InnerException = $_.Exception
                    ErrorId        = 'CollectionListFailed'
                    Category       = 'ConnectionError'
                    TargetObject   = $activeBroker
                }
                $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
            }
        }

        # Read every host and its current state once; hosts are then looked up by name.
        $knownHosts = [System.Collections.Generic.List[object]]::new()
        foreach ($collection in $CollectionName) {
            try {
                $hostParams = @{
                    ConnectionBroker = $activeBroker
                    CollectionName   = $collection
                    ErrorAction      = 'Stop'
                }
                foreach ($rdHost in Get-RDSessionHost @hostParams) {
                    $state = if ("$($rdHost.NewConnectionAllowed)" -eq 'Yes') { 'Yes' } else { 'No' }
                    $knownHosts.Add([pscustomobject]@{
                            SessionHost    = [string]$rdHost.SessionHost
                            CollectionName = $collection
                            State          = $state
                        })
                }
            } catch {
                $errorParams = @{
                    Message        = "Could not get the session hosts in ${collection}: $($_.Exception.Message)"
                    InnerException = $_.Exception
                    ErrorId        = 'SessionHostListFailed'
                    Category       = 'ConnectionError'
                    TargetObject   = $collection
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
            }
        }
    }

    process {
        foreach ($wanted in $SessionHost) {
            $found = @($knownHosts | Where-Object {
                    $_.SessionHost -eq $wanted -or $_.SessionHost -like "$wanted.*"
                })
            if ($found.Count -eq 0) {
                $errorParams = @{
                    Message      = "Session host '$wanted' was not found in: $($CollectionName -join ', ')."
                    ErrorId      = 'SessionHostNotFound'
                    Category     = 'ObjectNotFound'
                    TargetObject = $wanted
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
                continue
            }

            foreach ($rdHost in $found) {
                $newResult = {
                    param([string]$Result)
                    [pscustomobject]@{
                        SessionHost          = $rdHost.SessionHost
                        CollectionName       = $rdHost.CollectionName
                        PreviousState        = $rdHost.State
                        NewConnectionAllowed = $NewConnectionAllowed
                        Result               = $Result
                    }
                }

                if ($rdHost.State -eq $NewConnectionAllowed) {
                    Write-Verbose ("$($rdHost.SessionHost) already has NewConnectionAllowed = " +
                        "$NewConnectionAllowed.")
                    & $newResult 'Unchanged'
                    continue
                }

                $action = "Set NewConnectionAllowed to '$NewConnectionAllowed'"
                if (-not $PSCmdlet.ShouldProcess($rdHost.SessionHost, $action)) {
                    continue
                }

                try {
                    $setParams = @{
                        ConnectionBroker     = $activeBroker
                        SessionHost          = $rdHost.SessionHost
                        NewConnectionAllowed = $NewConnectionAllowed
                        ErrorAction          = 'Stop'
                    }
                    Set-RDSessionHost @setParams
                    $rdHost.State = $NewConnectionAllowed
                    & $newResult 'Changed'
                } catch {
                    $errorParams = @{
                        Message        = "Could not set NewConnectionAllowed on $($rdHost.SessionHost): " +
                        $_.Exception.Message
                        InnerException = $_.Exception
                        ErrorId        = 'SessionHostChangeFailed'
                        Category       = 'WriteError'
                        TargetObject   = $rdHost.SessionHost
                    }
                    $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
                    & $newResult 'Failed'
                }
            }
        }
    }
}
