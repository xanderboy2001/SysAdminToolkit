function Show-MenuHeader {
    <#
    .SYNOPSIS
    Displays a centered menu header with '=' framing.

    .DESCRIPTION
    Outputs the given title centered within a row of '=' characters.
    The total width of the header can be adjusted using the MenuWidth parameter.

    .PARAMETER Title
    The text to display as the menu header.

    .PARAMETER MenuWidth
    Optional. Total width of the header line. Defaults to 72 characters.
    If the specified width is less than the title length + padding, it is automatically adjusted.

    .EXAMPLE
    Show-MenuHeader -Title 'Active Directory Menu'
    # Displays a centered header with '=' framing in cyan.

    .NOTES
    Author: Alexander Christian
    #>
    param(
        [String]$Title,
        [int]$MenuWidth = 72 # default width; can be adjusted
    )

    # Ensure total width is at least the length of the title + padding
    if ($MenuWidth -lt ($Title.Length + 4)) {
        $MenuWidth = $Title.Length + 4
    }

    # Center the title
    $padding = ($MenuWidth - $Title.Length - 2) / 2
    $titleLine = '=' * [math]::Floor($padding) + " $Title " + '=' * [math]::Ceiling($padding)

    # Output
    Write-Host $titleLine -ForegroundColor Cyan
}
