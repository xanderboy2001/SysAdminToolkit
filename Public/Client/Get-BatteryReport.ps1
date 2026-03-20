function Get-BatteryReport {
    <#
    .SYNOPSIS
    Retrieves battery capacity data from a single computer.

    .DESCRIPTION
    Connects to the specified computer via Invoke-Command and uses powercfg to generate a temporary XML battery
    report. The design capacity and full charge capactiy are parsed from the report and returned as a
    PSCustomObject. The temporary report file is removed from the remote machine after parsing.

    CapcityPercent is calculated as (FullChargeCapacity / DesignCapacity) * 100, rounded to 1 decimal place.
    Capacity values are in milliwatt-hours (mWh).

    .PARAMETER ComputerName
    Optional. The name of the computer to collect battery data from. If not provided, the user is prompted to
    enter one.

    .EXAMPLE
    Get-BatteryReport -ComputerName 'L-1234'
    # Returns battery capacity data for L-1234.
    
    .EXAMPLE
    Get-BatteryReport
    # Prompts for a computer name and returns battery capacity data.

    .OUTPUTS
    PSCustomObject with properties: ComputerName, DesignCapacity, FullChargeCapacity, CapacityPercent.

    .NOTES
    Author: Alexander Christian
    Requires powercfg to be available and the executing account to have permission to run it remotely on the
    target machine.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$ComputerName
    )

    begin {
        if (-not $ComputerName) {
            $ComputerName = Read-Host "Enter the name of a computer"
        }

        if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
            throw "Could not establish a connection to $ComputerName"
        }
    }

    process {
        $batteryScript = {
            try {
                $reportPath = Join-Path -Path $env:TEMP -ChildPath 'batteryreport.xml'

                powercfg.exe /batteryreport /xml /output $reportPath 2>$null

                [xml]$report = Get-Content -Path $reportPath -ErrorAction Stop
                Remove-Item -Path $reportPath -Force

                $battery = $report.BatteryReport.Batteries.Battery

                $capacityPercent = $null
                if ($battery.DesignCapacity -and $battery.FullChargeCapacity) {
                    $capacityPercent = [math]::Round(
                        ([int]$battery.FullChargeCapacity / [int]$battery.DesignCapacity) * 100, 1
                    )
                }

                [pscustomobject]@{
                    ComputerName = $env:COMPUTERNAME
                    DesignCapacity = [int]$battery.DesignCapacity
                    FullChargeCapacity = [int]$battery.FullChargeCapacity
                    CapacityPercent = $capacityPercent
                }
            }
            catch {
                Write-Warning "Error on '$env:COMPUTERNAME': $($_.Exception.Message)"
                [pscustomobject]@{
                    ComputerName = $env:COMPUTERNAME
                    DesignCapacity = $null
                    FullChargeCapacity = $null
                    CapacityPercent = $null
                }
            }
        }

        $invokeParams = @{
            ComputerName = $ComputerName
            ScriptBlock = $batteryScript
            ErrorAction = "SilentlyContinue"
        }
        $result = Invoke-Command @invokeParams

        $result | Select-Object -Property ComputerName, DesignCapacity, FullChargeCapacity, CapacityPercent
    }
}
