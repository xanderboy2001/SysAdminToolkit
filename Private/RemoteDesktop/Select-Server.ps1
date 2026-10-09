function Select-Server {
    <#
    .SYNOPSIS
    Prompts the user to select one or more Remote Desktop session hosts from a list.

    .DESCRIPTION
    Displays a numbered list of session hosts with their current connection state.
    Hosts with new connections allowed are shown in green; disabled hosts in red.
    The user may enter a comma-separated list of numbers to select multiple hosts.
    Continues prompting until all entered indices are within the valid range.
    Returns an array of the selected server objects.

    .PARAMETER Servers
    An array of objects with SessionHost and NewConnectionAllowed properties, as returned by Get-RDSessionHost
    with computed properties applied.

    .EXAMPLE
    $selected = Select-Server -Servers $sessionHosts
    # Displays the session host list and returns the objects the user selected.

    .OUTPUTS
    System.Object[]. The selected session host objects.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([psobject[]])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "Session host objects with SessionHost and NewConnectionAllowed properties."
        )]
        [PSObject[]]$Servers
    )

    for ($i = 0; $i -lt $Servers.Count; $i++) {
        $msg = "[$($i + 1)] $($Servers[$i].SessionHost) (Connections Allowed: " +
        "$($Servers[$i].NewConnectionAllowed))"
        if ($Servers[$i].NewConnectionAllowed) {
            Write-Host $msg -ForegroundColor Green
        } else {
            Write-Host $msg -ForegroundColor Red
        }
    }

    do {
        $rawInput = Read-Host "Select one or more Remote Desktop Session Hosts to toggle"
        $tokens = @($rawInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $isValid = $tokens.Count -gt 0
        $indicies = foreach ($token in $tokens) {
            $number = 0
            if ([int]::TryParse($token, [ref]$number) -and $number -ge 1 -and $number -le $Servers.Count) {
                $number - 1
            } else {
                $isValid = $false
            }
        }
    } until ($isValid)

    # De-duplicate so that '1,1' does not toggle the same host twice.
    return $indicies | Select-Object -Unique | ForEach-Object { $Servers[$_] }
}
