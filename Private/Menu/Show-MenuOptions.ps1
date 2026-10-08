function Show-MenuOptions {
    <#
    .SYNOPSIS
    Displays a numbered list of menu options in green.

    .DESCRIPTION
    Outputs each string in the provided $Options array as a numbered menu item,
    aligning numbers and option text for a clean display.

    .PARAMETER Options
    An array of strings representing the menu options to display.

    .EXAMPLE
    Show-MenuOptions -Options @('Option1','Option2','Option3')
    # Displays the options as a numbered list in green.

    .NOTES
    Author: Alexander Christian
    #>
    param(
        [String[]]$Options
    )

    # Determine max width of option numbers (for padding)
    $maxIndexLength = ($Options.Count).ToString().Length

    # Determine max length of option text (optional, for nice spacing)
    $maxOptionLength = ($Options | Measure-Object -Maximum Length).Maximum

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $IndexStr = ($i + 1).ToString().PadLeft($maxIndexLength)
        $optionStr = $Options[$i].PadRight($maxOptionLength)
        Write-Host "$IndexStr. $OptionStr" -ForegroundColor Green
    }
}
