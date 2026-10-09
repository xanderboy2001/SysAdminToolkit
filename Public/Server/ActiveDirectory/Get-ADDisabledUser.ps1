function Get-ADDisabledUser {
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
