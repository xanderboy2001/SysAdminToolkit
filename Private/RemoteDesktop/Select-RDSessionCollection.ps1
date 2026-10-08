function Select-RDSessionCollection {
    <#
    .SYNOPSIS
    Prompts the user to select a Remote Desktop session collection from a list.

    .DESCRIPTION
    Displays a numbered list of the provided session collection names and prompts the user to enter a
    corresponding number. Continues prompting until a valid selection is made. Returns the name of the
    selected collection.

    .PARAMETER Collections
    An array of session collection name strings to present to the user.

    .EXAMPLE
    $collection = Select-RDSessionCollection -Collection @('desktops', 'apps')
    # Displays a numbered list and returns the name of the collection the user selects.

    .OUTPUTS
    System.String. The name of the selected session collection.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "An array of session collection names to present for user selection."
        )]
        [string[]]$Collections
    )

    for ($i = 0; $i -lt $Collections.Count; $i++) {
        Write-Host "[$($i + 1)] $($Collections[$i])"
    }

    $selection = 0
    do {
        $rawInput = Read-Host "Select a Remote Desktop Server Collection to manage (1-$($Collections.Count))"
        $isNumber = [int]::TryParse($rawInput, [ref]$selection)
    } until ($isNumber -and $selection -ge 1 -and $selection -le $Collections.Count)

    return $Collections[$selection - 1]
}
