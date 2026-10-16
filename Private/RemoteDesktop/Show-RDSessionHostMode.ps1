function Show-RDSessionHostMode {
    <#
    .SYNOPSIS
    Menu action: choose a collection and hosts, then allow or block new connections on them.

    .DESCRIPTION
    Interactive wrapper around Set-RDSessionHostMode for the toolkit menu:
    1. Uses the RDBrokerServer configuration value, or asks for a Connection Broker.
    2. Lets you pick a session collection, then shows its hosts with their current state and lets you pick one
       or more of them.
    3. Asks whether new connections should be allowed (y) or blocked (n) on the selected hosts.
    4. Calls Set-RDSessionHostMode with -Confirm and shows the results as a table.
    Back or Quit in the collection menu returns without changing anything.

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

    $servers = @(
        Get-RDSessionHost -ConnectionBroker $activeBroker -CollectionName $collection -ErrorAction Stop |
            ForEach-Object {
                [pscustomobject]@{
                    SessionHost          = ([string]$_.SessionHost).ToLower()
                    NewConnectionAllowed = "$($_.NewConnectionAllowed)" -eq 'Yes'
                }
            } |
            Sort-Object { [regex]::Replace($_.SessionHost, '\d+', { $args[0].Value.PadLeft(20) }) }
    )
    if ($servers.Count -eq 0) {
        Write-Warning "No session hosts were found in '$collection'."
        return
    }
    $selected = @(Select-Server -Servers $servers)

    $allow = Read-YesNo -Question 'Allow new connections on the selected hosts (n blocks them)'
    $setParams = @{
        SessionHost          = $selected.SessionHost
        NewConnectionAllowed = if ($allow) { 'Yes' } else { 'No' }
        ConnectionBroker     = $activeBroker
        CollectionName       = $collection
        Confirm              = $true
    }
    Set-RDSessionHostMode @setParams |
        Select-Object -Property SessionHost, PreviousState, NewConnectionAllowed, Result |
        Format-Table -AutoSize |
        Out-Host
}
