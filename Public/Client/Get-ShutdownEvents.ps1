function Get-ShutdownEvents {
    Show-MenuHeader -Title 'Get Shutdown Event Logs'
    Write-Host @'
This script retrieves all shutdown event logs for a specified computer.

Instructions:
1. Enter the computer name when prompted.
2. Enter the number of days to look back for shutdown logs:
    - Example: Enter "7" to pull logs from the past 7 days.
    - Default: Press Enter without typing a num
'@


    Write-Host $ComputerName
}