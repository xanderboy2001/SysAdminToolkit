function Show-RDSBrokerRestart {
    <#
    .SYNOPSIS
    Menu action: reboots all Connection Brokers one at a time and shows a summary.

    .DESCRIPTION
    Interactive wrapper around Restart-RDSBroker for the toolkit menu. Uses the RDBrokerServer configuration
    value, or asks for a Connection Broker when it is not set. Restart-RDSBroker shows its plan and asks for
    confirmation before anything is rebooted, and shows its progress while it runs.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    Show-MenuHeader -Title 'Reboot RDS Connection Brokers'

    $broker = (Get-ToolkitConfig).RDBrokerServer
    if (-not $broker) {
        $broker = Read-Host -Prompt "Enter the name of a Remote Desktop Connection Broker (e.g. 'broker1')"
    }
    if ([string]::IsNullOrWhiteSpace($broker)) {
        Write-Warning 'No Connection Broker given.'
        return
    }

    $result = Restart-RDSBroker -BrokerServer $broker
    if (-not $result) {
        return
    }
    $duration = $result.Duration.ToString('hh\:mm\:ss')
    Write-Host "Rebooted $($result.RebootedBrokers -join ', ') in $duration." -ForegroundColor Green
    $message = "Active broker: $($result.ActiveBroker) (was $($result.PreviousActiveBroker))."
    Write-Host $message -ForegroundColor Green
}
