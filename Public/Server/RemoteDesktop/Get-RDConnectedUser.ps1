function Get-RDConnectedUser {
    <#
    .SYNOPSIS
    Returns the user sessions on Remote Desktop session hosts.

    .DESCRIPTION
    Finds the active Connection Broker of the deployment, reads the user sessions of the chosen session
    collections, and returns one object per session. It never prompts, so it can be used in scripts and pipelines.

    - Without -CollectionName, every collection of type 'Remote Desktop' is read.
    - Without -SessionHost, sessions on every host are returned. A host can be given as a short name ('rds1') or
      an FQDN; 'rds1' does not match 'rds10'.
    - FullName is looked up in Active Directory once per user. It is empty for users not found in AD.

    A collection whose sessions cannot be read writes a non-terminating error and the other collections are still
    returned.

    For the interactive version that lets you pick a collection and a host from menus, use Start-ToolkitMenu:
    Server > Remote Desktop > List connected users.

    .PARAMETER ConnectionBroker
    Optional. The host name or FQDN of any Connection Broker in the deployment. Defaults to the RDBrokerServer
    configuration value. The active broker of its high-availability group is used.

    .PARAMETER CollectionName
    Optional. One or more session collection names to read.

    .PARAMETER SessionHost
    Optional. One or more session hosts to return sessions for.

    .EXAMPLE
    Get-RDConnectedUser -SessionHost 'rds1' | Select-Object -Property FullName, UserName, SessionState
    # Who is connected to rds1, using the broker from the toolkit configuration.

    .EXAMPLE
    Get-RDConnectedUser -ConnectionBroker 'broker01' | Group-Object -Property SessionHost | Sort-Object Count
    # Number of sessions on each host in every collection.

    .EXAMPLE
    Get-RDConnectedUser -CollectionName 'Desktops' | Where-Object SessionState -EQ 'STATE_DISCONNECTED'
    # Disconnected sessions in the Desktops collection.

    .OUTPUTS
    PSCustomObject with SessionHost, CollectionName, UserName, DomainName, FullName, SessionState, and SessionId.

    .NOTES
    Author: Alexander Christian
    Requires the RemoteDesktop and ActiveDirectory modules. The old name Get-RDConnectedUsers still works as an
    alias.
    #>
    [CmdletBinding()]
    [Alias('Get-RDConnectedUsers')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string]$ConnectionBroker,

        [ValidateNotNullOrWhiteSpace()]
        [string[]]$CollectionName,

        [ValidateNotNullOrWhiteSpace()]
        [string[]]$SessionHost
    )

    if (-not $ConnectionBroker) {
        $ConnectionBroker = (Get-ToolkitConfig).RDBrokerServer
    }
    if (-not $ConnectionBroker) {
        $errorParams = @{
            Message  = 'No Connection Broker given. Use -ConnectionBroker, or set RDBrokerServer in the toolkit ' +
            'configuration.'
            ErrorId  = 'ConnectionBrokerMissing'
            Category = 'InvalidArgument'
        }
        $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
    }

    $resolvedBroker = Confirm-ConnectionBroker -ConnectionBroker $ConnectionBroker
    $activeBroker = Get-ActiveBroker -BrokerServers $resolvedBroker
    Write-Verbose "Using active Connection Broker $activeBroker."

    if (-not $CollectionName) {
        $CollectionName = @(Get-RDCollectionName -ConnectionBroker $activeBroker)
    }

    # Reads a property that may be missing on some RemoteDesktop module versions; strict mode would throw.
    $readProperty = {
        param($Object, [string]$Name)
        $property = $Object.PSObject.Properties[$Name]
        if ($property) { $property.Value } else { $null }
    }

    $fullNames = @{}
    foreach ($collection in $CollectionName) {
        try {
            $sessionParams = @{
                ConnectionBroker = $activeBroker
                CollectionName   = $collection
                ErrorAction      = 'Stop'
            }
            $sessions = @(Get-RDUserSession @sessionParams)
        } catch {
            $errorParams = @{
                Message        = "Could not read the sessions of collection '$collection': $($_.Exception.Message)"
                InnerException = $_.Exception
                ErrorId        = 'SessionListFailed'
                Category       = 'ConnectionError'
                TargetObject   = $collection
            }
            $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
            continue
        }

        foreach ($session in $sessions) {
            $hostServer = [string](& $readProperty $session 'HostServer')
            if ($SessionHost) {
                $isMatch = $false
                foreach ($wanted in $SessionHost) {
                    if ($hostServer -eq $wanted -or $hostServer -like "$wanted.*") {
                        $isMatch = $true
                        break
                    }
                }
                if (-not $isMatch) {
                    continue
                }
            }

            $userName = [string](& $readProperty $session 'UserName')
            if ($userName -and -not $fullNames.ContainsKey($userName)) {
                try {
                    $fullNames[$userName] = Get-FullNameFromUsername -UserName $userName
                } catch {
                    Write-Verbose "No Active Directory user found for '$userName'."
                    $fullNames[$userName] = $null
                }
            }

            [pscustomobject]@{
                SessionHost    = $hostServer
                CollectionName = $collection
                UserName       = $userName
                DomainName     = & $readProperty $session 'DomainName'
                FullName       = if ($userName) { $fullNames[$userName] } else { $null }
                SessionState   = [string](& $readProperty $session 'SessionState')
                SessionId      = & $readProperty $session 'UnifiedSessionId'
            }
        }
    }
}
