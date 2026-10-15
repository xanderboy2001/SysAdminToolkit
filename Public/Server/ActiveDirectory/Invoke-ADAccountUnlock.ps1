function Invoke-ADAccountUnlock {
    <#
    .SYNOPSIS
    Unlocks one or more locked Active Directory user accounts.

    .DESCRIPTION
    For each identity, reads the account from Active Directory and unlocks it if it is locked. It never prompts
    for a username, so it can be used in scripts and pipelines. Returns one result object per account.

    - Accounts that are not locked are left alone and reported with Result 'NotLocked'.
    - A warning is written for protected accounts (adminCount = 1), which are often administrative accounts.
    - An identity that does not exist writes a non-terminating error (SysAdminToolkit.UserNotFound) and the
      remaining identities are still processed.
    - A failed unlock writes an error (SysAdminToolkit.UnlockFailed) and returns Result 'Failed'.

    Confirmation uses the standard PowerShell prompt (ConfirmImpact High). Use -Force to skip it, or -WhatIf to
    see which accounts would be unlocked; with -WhatIf nothing is returned for locked accounts.

    For the interactive version that asks for a username, use Start-ToolkitMenu:
    Server > Active Directory > Unlock Account.

    .PARAMETER Identity
    One or more accounts to unlock: sAMAccountName, distinguished name, GUID, or SID. Accepts pipeline input,
    including objects with a SamAccountName property such as the output of Search-ADAccount or Get-ADUser.

    .PARAMETER Force
    Skips the confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    Invoke-ADAccountUnlock -Identity 'jdoe'
    # Asks for confirmation, then unlocks jdoe if the account is locked.

    .EXAMPLE
    Search-ADAccount -LockedOut -UsersOnly | Invoke-ADAccountUnlock -WhatIf
    # Shows which locked accounts would be unlocked, without changing them.

    .EXAMPLE
    'jdoe', 'asmith' | Invoke-ADAccountUnlock -Force | Where-Object Result -EQ 'Unlocked'
    # Unlocks both accounts without prompting and lists the ones that were unlocked.

    .INPUTS
    System.String, or any object with a SamAccountName property.

    .OUTPUTS
    PSCustomObject with SamAccountName, Name, DistinguishedName, WasLocked, and Result
    ('Unlocked', 'NotLocked', or 'Failed').

    .NOTES
    Author: Alexander Christian
    Requires the ActiveDirectory module and the right to unlock the accounts.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SamAccountName')]
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$Identity,

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
        $adProperties = @('LockedOut', 'DisplayName', 'adminCount')
    }

    process {
        foreach ($id in $Identity) {
            try {
                $user = Get-ADUser -Identity $id -Properties $adProperties -ErrorAction Stop
            } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                $errorParams = @{
                    Message        = "No Active Directory user has the identity '$id'."
                    InnerException = $_.Exception
                    ErrorId        = 'UserNotFound'
                    Category       = 'ObjectNotFound'
                    TargetObject   = $id
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
                continue
            } catch {
                $errorParams = @{
                    Message        = "Could not read the account '$id' from Active Directory: " +
                    $_.Exception.Message
                    InnerException = $_.Exception
                    ErrorId        = 'ADQueryFailed'
                    Category       = 'ReadError'
                    TargetObject   = $id
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
                continue
            }

            $samAccountName = [string](& $readProperty $user 'SamAccountName')
            if (-not $samAccountName) {
                $samAccountName = $id
            }
            $name = & $readProperty $user 'Name'
            $isLocked = [bool](& $readProperty $user 'LockedOut')
            $newResult = {
                param([string]$Result)
                [pscustomobject]@{
                    SamAccountName    = $samAccountName
                    Name              = $name
                    DistinguishedName = & $readProperty $user 'DistinguishedName'
                    WasLocked         = $isLocked
                    Result            = $Result
                }
            }

            if (-not $isLocked) {
                Write-Verbose "$samAccountName is not locked."
                & $newResult 'NotLocked'
                continue
            }

            if ((& $readProperty $user 'adminCount') -eq 1) {
                Write-Warning ("'$samAccountName' is or was a member of a protected administrative group " +
                    '(adminCount = 1). Confirm this is really the intended account.')
            }

            $target = if ($name) { "$samAccountName ($name)" } else { $samAccountName }
            if (-not $PSCmdlet.ShouldProcess($target, 'Unlock AD account')) {
                continue
            }

            try {
                Unlock-ADAccount -Identity $samAccountName -ErrorAction Stop
                & $newResult 'Unlocked'
            } catch {
                $errorParams = @{
                    Message        = "Could not unlock ${samAccountName}: $($_.Exception.Message)"
                    InnerException = $_.Exception
                    ErrorId        = 'UnlockFailed'
                    Category       = 'WriteError'
                    TargetObject   = $samAccountName
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
                & $newResult 'Failed'
            }
        }
    }
}
