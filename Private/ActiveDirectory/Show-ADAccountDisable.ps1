function Show-ADAccountDisable {
    <#
    .SYNOPSIS
    Menu action: asks for a username and disables the account.

    .DESCRIPTION
    Interactive wrapper around Invoke-ADAccountDisable for the toolkit menu. Asks for the account with
    Get-ValidADUser (which also shows the resolved account and warns about protected accounts), then calls
    Invoke-ADAccountDisable, which asks for confirmation.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    Show-MenuHeader -Title 'Disable AD Account'
    Write-Host 'Enter a username. You will be asked to confirm before the account is disabled.' `
        -ForegroundColor Yellow

    $user = Get-ValidADUser
    $samAccountName = $user.SamAccountName

    # Get-ValidADUser has already shown the protected-account warning, so it is not repeated here.
    $result = Invoke-ADAccountDisable -Identity $samAccountName -WarningAction SilentlyContinue
    if (-not $result) {
        return
    }
    switch ($result.Result) {
        'Disabled' {
            Write-Host "Disabled the account $samAccountName ($($result.Name))." -ForegroundColor Green
        }
        'AlreadyDisabled' {
            Write-Warning "$samAccountName is already disabled."
        }
    }
}
