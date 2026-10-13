function Get-BatteryReport {
    <#
    .SYNOPSIS
    Retrieves battery capacity data from a single computer.

    .DESCRIPTION
    Runs powercfg /batteryreport on each computer through PowerShell remoting and returns one objext per battery.
    All computers are queried in parallel by a single Invoke-Command call.

    - Each report is written to a uniquely named files in the remote temp folder and is always deleted, even
      when reading it fails.
    - A computer without a battery returns one object with status 'NoBattery'.
    - A computer that cannot be reached, or where powercfg fails, writes a non-terminating error naming that
      computer; the other computers are still reported.

    CapacityPercent is FullChargeCapacity / DesignCapacity x 100, rounded to one decimal place. Capacities are
    in milliwatt-hours (mWh)

    .PARAMETER ComputerName
    One or more computers. Accepts pipeline input, including objects with a ComputerName or DNSHostName property
    (for example from Get-ADComputer). If omitted and nothing is piped in, you are prompted for a
    comma-separated list.

    .EXAMPLE
    Get-BatteryReport -ComputerName 'PC-1234'
    # Returns battery capacity data for PC-1234.

    .EXAMPLE
    'PC-1234', 'PC-5678' | Get-BatteryReport | Where-Object CapacityPercent -lt 60
    # Lists batteries below 60& of their design capacity.

    .EXAMPLE
    Get-ADComputer -Filter "Name -like 'L-*'" | Get-BatteryReport -ErrorAction SilentlyContinue |
        Export-Csv .\batteries.csv -NoTypeInformation
    # Reports every laptop that answers; unreachable ones are skipped.

    .INPUTS
    System.String

    .OUTPUTS
    PSCustomObject with ComputerName, BatteryId, Status, DesignCapacity, FullChargeCapacity, CapacityPercent,
    and CycleCount

    .NOTES
    Author: Alexander Christian
    Requires WinRM access to the target computers.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DNSHostName')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName
    )

    begin {
        $computers = [System.Collections.Generic.List[string]]::new()

        if (-not $PSBoundParameters.ContainsKey('ComputerName') -and -not $MyInvocation.ExpectingInput) {
            $answer = Read-Host 'Enter one or more computer names (comma separated)'
            foreach ($name in $answer -split ',' ) {
                if (-not [string]::IsNullOrWhiteSpace($name)) {
                    $computers.Add($name.Trim())
                }
            }
        }

        # Runs on each target computer. Must stay self-contained: only built-in cmdlets and powercfg.
        $batteryScript = {
            $reportPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (
                'batteryreport-{0}.xml' -f [guid]::NewGuid().ToString('N')
            )
            try {
                $null = powercfg.exe /batteryreport /xml /output $reportPath 2>&1
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $reportPath)) {
                    throw "powercfg /batteryreport failed with exit code $LASTEXITCODE."
                }
                [xml]$report = Get-Content -Path $reportPath -ErrorAction Stop
            } finally {
                Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
            }

            # local-name() ignores the report's XML namespace and works when <Batteries> is empty.
            $readValue = {
                param($Node, [string]$Name)
                $child = $Node.SelectSingleNode("*[local-name()='$Name']")
                if ($child) { $child.InnerText } else { $null }
            }

            $batteries = @($report.SelectNodes("//*[local-name()='Batteries']/*[local-name()='Battery']"))
            if ($batteries.Count -eq 0) {
                return [pscustomobject]@{
                    ComputerName       = $env:COMPUTERNAME
                    BatteryId          = $null
                    Status             = 'NoBattery'
                    DesignCapacity     = $null
                    FullChargeCapacity = $null
                    CapacityPercent    = $null
                    CycleCount         = $null
                }
            }

            foreach ($battery in $batteries) {
                $design = (& $readValue $battery 'DesignCapacity') -as [int]
                $full = ( &$readValue $battery 'FullChargeCapacity') -as [int]
                [pscustomobject]@{
                    ComputerName       = $env:COMPUTERNAME
                    BatteryId          = & $readValue $battery 'Id'
                    Status             = 'OK'
                    DesignCapacity     = $design
                    FullChargeCapacity = $full
                    CapacityPercent    = if ($design -gt 0 -and $null -ne $full) {
                        [math]::Round(($full / $design) * 100, 1)
                    } else {
                        $null
                    }
                    CycleCount         = (& $readValue $battery 'CycleCount') -as [int]
                }
            }
        }
    }

    process {
        foreach ($name in $ComputerName) {
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $computers.Add($name.Trim())
            }
        }
    }

    end {
        if ($computers.Count -eq 0) {
            Write-Warning 'No computer names were provided.'
            return
        }

        $remoteErrors = $null
        $invokeParams = @{
            ComputerName  = @($computers | Sort-Object -Unique)
            ScriptBlock   = $batteryScript
            # Errors are collected and re-reported below with the computer name , instead of being hidden.
            ErrorAction   = 'SilentlyContinue'
            ErrorVariable = 'remoteErrors'
        }
        Invoke-Command @invokeParams |
            Select-Object -Property ComputerName, BatteryId, Status, DesignCapacity, FullChargeCapacity,
            CapacityPercent, CycleCount

        foreach ($remoteError in @($remoteErrors)) {
            $target = if ($remoteError.PSObject.Properties['OriginInfo'] -and $remoteError.OriginInfo) {
                $remoteError.OriginInfo.PSComputerName
            } elseif ($remoteError.TargetObject) {
                "$($remoteError.TargetObject)"
            } else {
                $remoteError.CategoryInfo.TargetName
            }
            $errorParams = @{
                Message      = "Battery report failed on ${target}: $($remoteError.Exception.Message)"
                Exception    = $remoteError.Exception
                Category     = $remoteError.CategoryInfo.Category
                ErrorId      = 'SysAdminToolkit.BatteryReportFailed'
                TargetObject = $target
            }
            Write-Error @errorParams
        }
    }
}
