function Get-ADDisabledUser {
    <#
    .SYNOPSIS
    Lists disabled Active Directory user accounts, optionally leaving out accounts in specific OUs.

    .DESCRIPTION
    Returns every disabled user account, or only those under SearchBase. Accounts in any of the Exclusions OUs, or
    in OUs below them, are left out; this is typically used to hide an OU that already holds disabled accounts.

    If neither Exclusions nor NoExclusion is supplied, you are prompted for one or more OU distinguished names,
    separated by semicolons. Enter 'l' at the prompt to list the OUs in the domain, or press Enter to leave
    nothing out.

    .PARAMETER Exclusions
    Distinguished names of OUs to leave out, for example 'OU=Disabled,OU=Users,DC=contoso,DC=com'. Accounts in
    sub-OUs are left out as well. Containers (CN=...) and domains with any number of DC= parts are accepted.
    Matching is exact (case-insensitive); characters such as [ ] * ? in OU names have no special meaning.

    .PARAMETER NoExclusion
    Returns every disabled account without prompting. Use this in scripts.

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
    Get-ADDisabledUser -NoExclusion | Export-Csv .\disabled-users.csv -NoTypeInformation
    # Exports every disabled account without prompting.

    .EXAMPLE
    Get-ADDisabledUser
    # Prompts for the OUs to exclude, then lists the disabled accounts.

    .OUTPUTS
    Microsoft.ActiveDirectory.Management.ADUser

    .NOTES
    Author: Alexander Christian
    Requires the ActiveDirectory module. The old name Get-ADDisabledUsers still works as an alias.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Prompt')]
    [Alias('Get-ADDisabledUsers')]
    [OutputType('Microsoft.ActiveDirectory.Management.ADUser')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Exclusions')]
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$Exclusions,

        [Parameter(Mandatory, ParameterSetName = 'NoExclusion')]
        [switch]$NoExclusion,

        [ValidateNotNullOrWhiteSpace()]
        [string]$SearchBase
    )

    # A separate variable: assigning to $Exclusions would re-run its validation, which rejects an empty list.
    if ($NoExclusion) {
        $excludedOUs = @()
    } elseif ($PSBoundParameters.ContainsKey('Exclusions')) {
        $invalid = @($Exclusions | Where-Object { -not (Test-ADDistinguishedName -DistinguishedName $_) })
        if ($invalid.Count -gt 0) {
            throw "Not a valid OU or container distinguished name: $($invalid -join '; ')"
        }
        $excludedOUs = @($Exclusions)
    } else {
        $excludedOUs = @(Get-ExcludedOUPath)
    }

    $GetADUserParams = @{
        Filter = "Enabled -eq 'False'"
    }

    if ($SearchBase) {
        $GetADUserParams["SearchBase"] = $SearchBase
    }

    # EndsWith instead of -like: OU names may contain [ ] * ?, which -like would treat as wildcards.
    $suffixes = @($excludedOUs | ForEach-Object { ",$_" })
    Get-ADUser @GetADUserParams | Where-Object {
        $dn = $_.DistinguishedName
        $excluded = $false
        foreach ($suffix in $suffixes) {
            if ($dn.EndsWith($suffix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $excluded = $true
                break
            }
        }
        -not $excluded
    }
}
