function Invoke-ADAccountDisable {
    <#
    .SYNOPSIS
    Disables an Active Directory user account.

    .DESCRIPTION
    Prompts for a valid Active Directory username and disables the corresponding account.
    Uses Get-ValidADUser to resolve and validate the account before calling Disable-ADAccount.
    Displays a success or failure message depending on the outcome.

    Confirmation uses the standard PowerShell prompt (ConfirmImpact High). Use -Force to skip it, or -WhatIf to
    see which account would be disabled.

    .PARAMETER Force
    Skips the confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    Invoke-ADAccountDisable
    # Prompts for a username and disables the corresponding Active Directory account.

    .EXAMPLE
    Invoke-ADAccountDisable -WhatIf
    # Shows which account would be disabled without changing it.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive wizard; to be split into core command + UI. See issue #1 (F-21).')]
    param(
        [switch]$Force
    )
    process {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }
        Show-MenuHeader -Title 'Disable AD Account'
        $msg = 'This script takes an Active Directory account username as input and disables the account.'
        Write-Host $msg -ForegroundColor Yellow

        $userAccount = Get-ValidADUser
        $username = $userAccount.SamAccountName

        try {
            if ($PSCmdlet.ShouldProcess($username, 'Disable AD account')) {
                Disable-ADAccount -Identity $username -ErrorAction Stop
                Write-Host "Disabled AD account for $username ($($userAccount.Name))"
            }
        } catch {
            $msg = "Failed to disable AD account for $username ($($userAccount.Name)): $($_.Exception.Message)"
            Write-Error $msg
        }
    }
}
