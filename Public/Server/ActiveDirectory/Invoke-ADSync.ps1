
function Invoke-ADSync {
    Show-MenuHeader -Title 'Run AD Delta Sync'
    Write-Host 'This script triggers an Active Directory Delta sync.' -ForegroundColor Yellow

    Write-Host "Connecting to 'ADConnect' server and starting sync..."

    Invoke-Command -ComputerName 'ADConnect' -ScriptBlock {
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
}