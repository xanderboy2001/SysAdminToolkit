
function Invoke-ADSync {
    [CmdletBinding()]
    param(
        [string]$ADConnectServer
    )
    Show-MenuHeader -Title 'Run AD Delta Sync'
    Write-Host 'This script triggers an Active Directory Delta sync.' -ForegroundColor Yellow

    if (-not $ADConnectServer) {
        $ADConnectServer = Read-Host "Enter the name of the AD Connect Server"
    }

    $ADConnectServerResolved = [System.Net.Dns]::GetHostByName($ADConnectServer).HostName
    Write-Host "Verifying connection to $ADConnectServerResolved..." -ForegroundColor Cyan
    if (-not (Test-Connection -TargetName $ADConnectServerResolved -Count 1 -Quiet)) {
        throw "$ADConnectServerResolved is not reachable"
    }
    Write-Host "Connection to $ADConnectServerResolved verified." -ForegroundColor Green

    try{
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
        } | Out-Null
    } catch {
        Write-Host "Fatal error during AD Delta Sync: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
