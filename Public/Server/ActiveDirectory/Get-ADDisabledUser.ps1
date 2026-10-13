function Get-ADDisabledUser {
    <#
    .SYNOPSIS
    Lists disabled Active Directory user accounts, optionally leaving out accounts in specific OUs.

    .DESCRIPTION
    Returns every disabled user account, or only those under SearchBase. Accounts in any of the Exclusions OUs, or
    in OUs below them, are left out; this is typically used to hide an OU that already holds disabled accounts.

    If Exclusions is not supplied, you are prompted for one or more OU distinguished names, separated by
    semicolons. Enter 'l' at the prompt to list the OUs in the domain.

    .PARAMETER Exclusions
    Distinguished names of OUs to leave out, for example 'OU=Disabled,OU=Users,DC=contoso,DC=com'. Accounts in
    sub-OUs are left out as well. If omitted, you are prompted.

    .PARAMETER SearchBase
    Optional. Distinguished name of the OU or container to search. Defaults to the whole domain.

    .EXAMPLE
    Get-ADDisabledUser -Exclusions 'OU=Disabled,OU=Users,DC=contoso,DC=com'
    # Lists disabled accounts that are not in the Disabled OU.

    .EXAMPLE
    Get-ADDisabledUser -Exclusions 'OU=Disabled,DC=contoso,DC=com' -SearchBase 'OU=Staff,DC=contoso,DC=com' |
        Select-Object -Property Name, SamAccountName, DistinguishedName
    # Lists disabled accounts under the Staff OU as a short table.

    .EXAMPLE
    Get-ADDisabledUser
    # Prompts for the OUs to exclude, then lists the disabled accounts.

    .OUTPUTS
    Microsoft.ActiveDirectory.Management.ADUser

    .NOTES
    Author: Alexander Christian
    Requires the ActiveDirectory module. The old name Get-ADDisabledUsers still works as an alias.
    #>
    [CmdletBinding()]
    [Alias('Get-ADDisabledUsers')]
    param(
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$Exclusions,

        [ValidateNotNullOrWhiteSpace()]
        [string]$SearchBase
    )

    if (-not $Exclusions) {
        $Exclusions = Get-ExcludedOUPath
    }

    $GetADUserParams = @{
        Filter = "Enabled -eq 'False'"
    }

    if ($SearchBase) {
        $GetADUserParams["SearchBase"] = $SearchBase
    }

    Get-ADUser @GetADUserParams | Where-Object {
        $dn = $_.DistinguishedName
        -not ($Exclusions | Where-Object { $dn -like "*,$_" })
    }
}
