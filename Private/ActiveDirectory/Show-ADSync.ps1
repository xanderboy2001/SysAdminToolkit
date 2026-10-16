function Show-ADSync {
    <#
    .SYNOPSIS
    Menu action: runs an Entra Connect delta sync and shows the result.

    .DESCRIPTION
    Interactive wrapper around Invoke-ADSync for the toolkit menu. Uses the ADConnectServer configuration value,
    or asks for the server when it is not set, then shows the result in colour. Warnings and errors from
    Invoke-ADSync (already running, timed out) are shown as they happen.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    Show-MenuHeader -Title 'Run AD Delta Sync'

    $server = (Get-ToolkitConfig).ADConnectServer
    if (-not $server) {
        $server = Read-Host -Prompt 'Enter the name of the AD Connect server'
    }
    if ([string]::IsNullOrWhiteSpace($server)) {
        Write-Warning 'No AD Connect server given.'
        return
    }

    Write-Host "Starting a delta sync on $server..." -ForegroundColor Yellow
    $result = Invoke-ADSync -ComputerName $server
    if ($result -and $result.Status -eq 'Completed') {
        $message = "AD sync complete on $($result.ComputerName) ($($result.ElapsedSeconds)s)."
        Write-Host $message -ForegroundColor Green
    }
}
