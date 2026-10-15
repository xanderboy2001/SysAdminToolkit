function Show-RDConnectedUser {
    <#
    .SYNOPSIS
    Menu action: choose a session collection and a host, then show who is connected to it.

    .DESCRIPTION
    Interactive wrapper around Get-RDConnectedUser for the toolkit menu. Uses the RDBrokerServer configuration
    value, or prompts for a Connection Broker when it is not set. Back or Quit in either picker returns to the
    menu without showing anything.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    param()

    $broker = (Get-ToolkitConfig).RDBrokerServer
    if (-not $broker) {
        $broker = Read-Host -Prompt "Enter the name of a Remote Desktop Connection Broker (e.g. 'broker1')"
    }
    if ([string]::IsNullOrWhiteSpace($broker)) {
        Write-Warning 'No Connection Broker given.'
        return
    }

    $activeBroker = Get-ActiveBroker -BrokerServers (Confirm-ConnectionBroker -ConnectionBroker $broker)

    $collections = @(Get-RDCollectionName -ConnectionBroker $activeBroker)
    if ($collections.Count -eq 0) {
        Write-Warning "No Remote Desktop session collections were found on $activeBroker."
        return
    }
    do {
        $result = Show-Menu -Title 'Remote Desktop Server Collections' -Options $collections
    } until ($result.Quit -or $result.Back -or $null -ne $result.Index)
    if ($result.Quit -or $result.Back) {
        return
    }
    $collection = $collections[$result.Index]

    $hosts = @(Get-RDHostName -ConnectionBroker $activeBroker -CollectionName $collection)
    if ($hosts.Count -eq 0) {
        Write-Warning "No session hosts were found in '$collection'."
        return
    }
    do {
        $result = Show-Menu -Title "Remote Desktop Hosts in '$collection'" -Options $hosts
    } until ($result.Quit -or $result.Back -or $null -ne $result.Index)
    if ($result.Quit -or $result.Back) {
        return
    }
    $sessionHost = $hosts[$result.Index]

    $queryParams = @{
        ConnectionBroker = $activeBroker
        CollectionName   = $collection
        SessionHost      = $sessionHost
    }
    $sessions = @(Get-RDConnectedUser @queryParams)
    Show-MenuHeader -Title "$($sessions.Count) user(s) connected to $sessionHost"
    if ($sessions.Count -gt 0) {
        $sessions |
            Select-Object -Property @{ Name = 'FullName'; Expression = { $_.FullName ?? '(not found in AD)' } },
            UserName, SessionState |
            Sort-Object -Property FullName |
            Format-Table -AutoSize |
            Out-Host
    }
}
