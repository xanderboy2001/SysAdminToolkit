function Invoke-ADAccountDisable {
    <#
    .SYNOPSIS
    Disables one or more Active Directory user accounts.

    .DESCRIPTION
    For each identity, reads the account from Active Directory and disables it if it is enabled. It never prompts
    for a username, so it can be used in scripts and pipelines. Returns one result object per account.

    - Accounts that are already disabled are left alone and reported with Result 'AlreadyDisabled'.
    - A warning is written for protected accounts (adminCount = 1), which are often administrative accounts.
    - An identity that does not exist writes a non-terminating error (SysAdminToolkit.UserNotFound) and the
      remaining identities are still processed.
    - A failed disable writes an error (SysAdminToolkit.DisableFailed) and returns Result 'Failed'.

    Confirmation uses the standard PowerShell prompt (ConfirmImpact High). Use -Force to skip it, or -WhatIf to
    see which accounts would be disabled; with -WhatIf nothing is returned for enabled accounts.

    For the interactive version that asks for a username, use Start-ToolkitMenu:
    Server > Active Directory > Disable User.

    .PARAMETER Identity
    One or more accounts to disable: sAMAccountName, distinguished name, GUID, or SID. Accepts pipeline input,
    including objects with a SamAccountName property such as the output of Get-ADUser.

    .PARAMETER Force
    Skips the confirmation prompt unless -Confirm is also specified.

    .EXAMPLE
    Invoke-ADAccountDisable -Identity 'jdoe'
    # Asks for confirmation, then disables jdoe if the account is enabled.

    .EXAMPLE
    Get-ADUser -Filter "Department -eq 'Leavers'" | Invoke-ADAccountDisable -WhatIf
    # Shows which accounts would be disabled, without changing them.

    .EXAMPLE
    Get-Content .\leavers.txt | Invoke-ADAccountDisable | Export-Csv .\disabled.csv -NoTypeInformation
    # Disables every username in the file, asking for each one, and saves the results.

    .INPUTS
    System.String, or any object with a SamAccountName property.

    .OUTPUTS
    PSCustomObject with SamAccountName, Name, DistinguishedName, WasEnabled, and Result
    ('Disabled', 'AlreadyDisabled', or 'Failed').

    .NOTES
    Author: Alexander Christian
    Requires the ActiveDirectory module and the right to disable the accounts.
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
        $adProperties = @('Enabled', 'DisplayName', 'adminCount')
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
            $isEnabled = [bool](& $readProperty $user 'Enabled')
            $newResult = {
                param([string]$Result)
                [pscustomobject]@{
                    SamAccountName    = $samAccountName
                    Name              = $name
                    DistinguishedName = & $readProperty $user 'DistinguishedName'
                    WasEnabled        = $isEnabled
                    Result            = $Result
                }
            }

            if (-not $isEnabled) {
                Write-Verbose "$samAccountName is already disabled."
                & $newResult 'AlreadyDisabled'
                continue
            }

            if ((& $readProperty $user 'adminCount') -eq 1) {
                Write-Warning ("'$samAccountName' is or was a member of a protected administrative group " +
                    '(adminCount = 1). Confirm this is really the intended account.')
            }

            $target = if ($name) { "$samAccountName ($name)" } else { $samAccountName }
            if (-not $PSCmdlet.ShouldProcess($target, 'Disable AD account')) {
                continue
            }

            try {
                Disable-ADAccount -Identity $samAccountName -ErrorAction Stop
                & $newResult 'Disabled'
            } catch {
                $errorParams = @{
                    Message        = "Could not disable ${samAccountName}: $($_.Exception.Message)"
                    InnerException = $_.Exception
                    ErrorId        = 'DisableFailed'
                    Category       = 'WriteError'
                    TargetObject   = $samAccountName
                }
                $PSCmdlet.WriteError((Get-ToolkitErrorRecord @errorParams))
                & $newResult 'Failed'
            }
        }
    }
}
