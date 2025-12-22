#TODO Connect to ADConnect with Enter-PSSession -ComputerName "ADConnect" -Credential (Get-Credential)
#TODO Start ADSync with Start-ADSyncSyncCycle
#TODO Wait until (Get-ADSyncConnectorRunStatus).RunState != 'Busy'
#TODO report end of AD Sync and exit PS Session with Exit-PSSession