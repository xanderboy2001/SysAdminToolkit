function Get-ValidADComputer {
    while ($true) {
        $Prompt = "Enter the computer name whose logs you wish to pull. Press enter to pull the logs of your host machine ($env:COMPUTERNAME)"
        $ComputerName = Read-Host -Prompt $Prompt
        if (-not $ComputerName) {
            $ComputerName = $env:COMPUTERNAME
        }
        try {
            $ADComputer = Get-ADComputer -Identity $ComputerName -ErrorAction Stop
            return $ADComputer
        }
        catch {
            Write-Host "No computer named $ComputerName was found in Active Directory." -ForegroundColor Red
            Write-Host 'Please verify the hostname and try again.' -ForegroundColor Yellow
        }
    }
}