function Get-RDConnectedUsers {
    param(
        [string]$ConnectionBroker
    )

    if (-not $ConnectionBroker) {
        $prompt = "Enter the name of one of the Remote Desktop Connection Broker Servers (e.g. 'broker1')"
        $ConnectionBroker = Read-Host -Prompt $prompt
    }

    $BrokerFQDN = Confirm-ConnectionBroker -ConnectionBroker $ConnectionBroker

    $ActiveServer = Get-ActiveBroker -BrokerServers $BrokerFQDN

    $Collections = Get-RDCollections -ConnectionBroker $ActiveServer
    $result = Show-Menu -Title "Remote Desktop Server Collections" -Options $Collections

    if ($result.Quit) {
        return
    }
    if ($result.Back) {
        Show-RDMenu
    }

    $SelectedCollection = $Collections[$result.Index]
    Write-Host "You have selected '$SelectedCollection'" -ForegroundColor Green

    $Hosts = Get-RDHosts -ConnectionBroker $ActiveServer -CollectionName $SelectedCollection

    $result = Show-Menu -Title "Remote Desktop Hosts in '$SelectedCollection'" -Options $Hosts
    if ($result.Quit) {
        return
    }
    if ($result.Back) {
        Show-RDMenu
    }
    $SelectedHost = $Hosts[$result.Index]
    Write-Host "You have selected '$SelectedHost'" -ForegroundColor Green
    $Users = Get-RDUserSession -ConnectionBroker $ActiveServer -CollectionName $SelectedCollection |
        Where-Object { $_.HostServer -like "${SelectedHost}*" } |
        Select-Object -ExpandProperty UserName

    Write-Host "There are currently $($Users.Count) connected to ${SelectedHost}:" -ForegroundColor Magenta
    foreach ($user in $Users) {
        $FullName = Get-FullNameFromUsername -Username $user
        Write-Host "$FullName ($user)"
    }
}
