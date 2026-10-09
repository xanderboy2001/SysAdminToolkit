function Wait-RDMService {
    <#
    .SYNOPSIS
    Runs Get-Service on the specified computer to query the status of the 'Remote Desktop Connection Broker'
    service. The function returns when the service is started.

    .PARAMETER ComputerName
    [string] Specifies the computer to run the service status check on.

    .EXAMPLE
    Wait-RDMService -ComputerName broker.domain.com
    # Polls until all RDS services are running on broker.domain.com

    .EXAMPLE
    Wait-RDMService -ComputerName broker.domain.com -MaxRetries 20
    # Polls up to 20 times before throwing a timeout error.

    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The FQDN or hostname of the broker server to poll for service status."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(
            Mandatory,
            HelpMessage = "Maximum number of polling attempts before throwing a timeout error."
        )]
        [int]$MaxRetries
    )

    $ServicesReady = $false
    $RetryCount = 0
    $ServiceCheckScript = {
        Get-Service | Where-Object {
            $_.Name -eq 'rdms' -or
            $_.Name -eq 'tssdis' -or
            $_.Name -eq 'tscpubrpc'
        } | Select-Object -Property Name, Status
    }

    do {
        try {
            Start-Sleep -Seconds 30
            $status = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ServiceCheckScript -ErrorAction Stop

            # Print status of all services
            Write-Verbose "Service status on ${ComputerName}:"
            $status | ForEach-Object {
                Write-Verbose "  $($_.Name): $($_.Status)"
            }

            $allRunning = ($status | Where-Object { $_.Status -ne 4 }).Count -eq 0

            if ($allRunning) {
                $ServicesReady = $true
            } else {
                $running = [System.ServiceProcess.ServiceControllerStatus]::Running
                $status | Where-Object { $_.Status -ne $running } | ForEach-Object {
                    Write-Information "Waiting for $($_.Name) to start..."
                }
            }
        } catch {
            Write-Warning ("Unable to query service status on $ComputerName (Attempt $RetryCount):" +
                "$($_.Exception.Message)")
        }
        $RetryCount++
    } until ($ServicesReady -eq $true -or $RetryCount -gt $MaxRetries)

    if ($ServicesReady) {
        return
    } else {
        throw "RDS Service failed to start on $ComputerName within the timeout period."
    }
}
