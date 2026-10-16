function Invoke-ADPasswordReset {
    <#
    .SYNOPSIS
    Resets the password of an Active Directory user account.

    .DESCRIPTION
    Resets the password of one account to NewPassword. It never prompts for a username or password, so it can be
    used in scripts. Returns one result object.

    - With -ChangePasswordAtLogon, the user must choose a new password at the next sign-in.
    - With -Unlock, the account is also unlocked if it is locked. Without -Unlock, a locked account stays locked
      and a warning says so.
    - A warning is written for protected accounts (adminCount = 1), which are often administrative accounts.
    - If the account does not exist or the reset fails, a terminating error is thrown
      (SysAdminToolkit.UserNotFound or SysAdminToolkit.PasswordResetFailed). If the reset works but setting
      ChangePasswordAtLogon or the unlock fails, a non-terminating error is written and the result shows which
      steps were done.

    Confirmation uses the standard PowerShell prompt (ConfirmImpact High). Use -Force to skip it, or -WhatIf to
    see what would change.

    For the interactive version that asks for the username, the password, and whether to unlock the account and
    require a password change, use Start-ToolkitMenu: Server > Active Directory > Reset Password.

    .PARAMETER Identity
    The account to reset: sAMAccountName, distinguished name, GUID, or SID.

    .PARAMETER NewPassword
    The new password, as a SecureString. It must meet the domain's password policy.

    .PARAMETER Unlock
    Also unlocks the account if it is locked.

    .PARAMETER ChangePasswordAtLogon
    Requires the user to change the password at the next sign-in.

    .PARAMETER Force
    Skips the confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    $password = Read-Host -AsSecureString -Prompt 'New password'
    Invoke-ADPasswordReset -Identity 'jdoe' -NewPassword $password -Unlock -ChangePasswordAtLogon
    # Resets jdoe's password, unlocks the account if needed, and requires a change at next sign-in.

    .EXAMPLE
    Invoke-ADPasswordReset -Identity 'jdoe' -NewPassword $password -WhatIf
    # Shows what would change without changing it.

    .OUTPUTS
    PSCustomObject with SamAccountName, Name, PasswordReset, ChangePasswordAtLogon, WasLocked, and Unlocked.

    .NOTES
    Author: Alexander Christian
    Requires the ActiveDirectory module and the right to reset passwords on the account.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('SamAccountName')]
        [ValidateNotNullOrWhiteSpace()]
        [string]$Identity,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [securestring]$NewPassword,

        [switch]$Unlock,

        [switch]$ChangePasswordAtLogon,

        [switch]$Force
    )

    begin {
        if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = 'None'
        }

        # Reads a property that may be missing (mocked or partially loaded objects); strict mode would throw.
        $readProperty = {
            param($Object, [string]$Name)
            $property = $Object.PSObject.Properties[$Name]
            if ($property) { $property.Value } else { $null }
        }
    }

    process {
        if ($NewPassword.Length -eq 0) {
            $errorParams = @{
                Message      = 'The new password cannot be empty.'
                ErrorId      = 'PasswordEmpty'
                Category     = 'InvalidArgument'
                TargetObject = $Identity
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }

        try {
            $user = Get-ADUser -Identity $Identity -Properties 'LockedOut', 'adminCount' -ErrorAction Stop
        } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            $errorParams = @{
                Message        = "No Active Directory user has the identity '$Identity'."
                InnerException = $_.Exception
                ErrorId        = 'UserNotFound'
                Category       = 'ObjectNotFound'
                TargetObject   = $Identity
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }

        $samAccountName = [string](& $readProperty $user 'SamAccountName')
        if (-not $samAccountName) {
            $samAccountName = $Identity
        }
        $name = & $readProperty $user 'Name'
        $wasLocked = [bool](& $readProperty $user 'LockedOut')

        if ((& $readProperty $user 'adminCount') -eq 1) {
            Write-Warning ("'$samAccountName' is or was a member of a protected administrative group " +
                '(adminCount = 1). Confirm this is really the intended account.')
        }

        $steps = @('reset the password')
        if ($ChangePasswordAtLogon) {
            $steps += 'require a change at next sign-in'
        }
        if ($Unlock -and $wasLocked) {
            $steps += 'unlock the account'
        }
        $target = if ($name) { "$samAccountName ($name)" } else { $samAccountName }
        if (-not $PSCmdlet.ShouldProcess($target, ($steps -join ', '))) {
            return
        }

        try {
            Set-ADAccountPassword -Identity $samAccountName -Reset -NewPassword $NewPassword -ErrorAction Stop
        } catch {
            $errorParams = @{
                Message        = "Could not reset the password of ${samAccountName}: $($_.Exception.Message)"
                InnerException = $_.Exception
                ErrorId        = 'PasswordResetFailed'
                Category       = 'WriteError'
                TargetObject   = $samAccountName
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }

        $changeSet = $false
        if ($ChangePasswordAtLogon) {
            try {
                Set-ADUser -Identity $samAccountName -ChangePasswordAtLogon $true -ErrorAction Stop
                $changeSet = $true
            } catch {
                $errorParams = @{
                    Message        = "The password of $samAccountName was reset, but requiring a change at next " +
                    "sign-in failed: $($_.Exception.Message)"
                    InnerException = $_.Exception
                    ErrorId        = 'ChangePasswordAtLogonFailed'
                    Category       = 'WriteError'
                    TargetObject   = $samAccountName
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
            }
        }

        $unlocked = $false
        if ($wasLocked -and $Unlock) {
            try {
                Unlock-ADAccount -Identity $samAccountName -ErrorAction Stop
                $unlocked = $true
            } catch {
                $errorParams = @{
                    Message        = "The password of $samAccountName was reset, but the unlock failed: " +
                    $_.Exception.Message
                    InnerException = $_.Exception
                    ErrorId        = 'UnlockFailed'
                    Category       = 'WriteError'
                    TargetObject   = $samAccountName
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
            }
        } elseif ($wasLocked) {
            Write-Warning "$samAccountName is locked and was not unlocked. Use -Unlock, or Invoke-ADAccountUnlock."
        }

        [pscustomobject]@{
            SamAccountName        = $samAccountName
            Name                  = $name
            PasswordReset         = $true
            ChangePasswordAtLogon = $changeSet
            WasLocked             = $wasLocked
            Unlocked              = $unlocked
        }
    }
}
