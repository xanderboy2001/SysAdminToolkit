function Get-ADDisabledUsers {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrWhiteSpace()]
        [string[]]$Exclusions,

        [ValidateNotNullOrWhiteSpace()]
        [string]$SearchBase
    )

    if (-not $Exclusions) {
        $Exclusions = Get-ExcludedOUPaths
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
