
function Invoke-ADSync {
    <#
    .SYNOPSIS
    Triggers a delta synchronization cycle on the configured AD Connect server.

    .DESCRIPTION
    Resolves and verifies connectivity to the AD Connect server specified in the toolkit configuration
    (or prompts for one if not configured). Connects to the server via Invoke-Command and runs
    Start-ADSyncSyncCycle with the Delta policy type. Waits for the sync cycle to begin and then polls until
    it completes before returning.

    .EXAMPLE
    Invoke-ADSync
    # Triggers a delta AD sync on the configured AD Connect server and waits for completion.
    
    .NOTES
    Author: Alexander Christian
    Requires the ADSync module to be installed on the target AD Connect server.
    The ADConnectServer value is read from the toolkit configuration via Get-ToolkitConfig.
    #>
    [CmdletBinding()]
    param()
    Show-MenuHeader -Title 'Run AD Delta Sync'
    Write-Host 'This script triggers an Active Directory Delta sync.' -ForegroundColor Yellow

    $ADConnectServer = (Get-ToolkitConfig).ADConnectServer

    if (-not $ADConnectServer) {
        $ADConnectServer = Read-Host "Enter the name of the AD Connect Server"
    }

    try {
        $ADConnectServerResolved = [System.Net.Dns]::GetHostByName($ADConnectServer).HostName
    }
    catch [System.Net.Sockets.SocketException] {
        throw "Could not resolve hostname '$ADConnectServer': $($_.Exception.Message)"
    }
    Write-Host "Verifying connection to $ADConnectServerResolved..." -ForegroundColor Cyan
    if (-not (Test-Connection -TargetName $ADConnectServerResolved -Count 1 -Quiet)) {
        throw "$ADConnectServerResolved is not reachable"
    }
    Write-Host "Connection to $ADConnectServerResolved verified." -ForegroundColor Green

    try {
        Write-Host "Beginning delta sync on $ADConnectServerResolved..." -ForegroundColor Cyan
        Invoke-Command -ComputerName $ADConnectServerResolved -ScriptBlock {
            Import-Module ADSync
            Start-ADSyncSyncCycle -PolicyType Delta
            Write-Host 'Waiting for sync to start' -NoNewline -ForegroundColor Yellow
            do {
                Write-Host '...' -NoNewline -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } while ((Get-ADSyncConnectorRunStatus).RunState -ne 'Busy')

            Write-Host "`nAD sync started. Waiting until completion" -NoNewline -ForegroundColor Yellow
            do {
                Write-Host '...' -NoNewline -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } while ((Get-ADSyncConnectorRunStatus).RunState -eq 'Busy')
            Write-Host "`nAD Sync complete" -ForegroundColor Green
        } -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Fatal error during AD Delta Sync: $($_.Exception.Message)"
        return
    }
}
