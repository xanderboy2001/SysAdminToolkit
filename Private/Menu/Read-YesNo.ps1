function Read-YesNo {
    <#
    .SYNOPSIS
    Asks a yes/no question and returns $true for yes, $false for no.

    .DESCRIPTION
    Repeats the question until the answer is y, yes, n, or no (any case). There is no default answer, so pressing
    Enter alone asks again.

    .PARAMETER Question
    The question to show, without the [y/n] suffix.

    .EXAMPLE
    if (Read-YesNo -Question 'Unlock the account') { ... }

    .OUTPUTS
    System.Boolean

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Question
    )

    while ($true) {
        $answer = "$(Read-Host -Prompt "${Question}? [y/n]")".Trim()
        if ($answer -match '^(y|yes)$') {
            return $true
        }
        if ($answer -match '^(n|no)$') {
            return $false
        }
        Write-Host "Please enter 'y' or 'n'." -ForegroundColor Yellow
    }
}
