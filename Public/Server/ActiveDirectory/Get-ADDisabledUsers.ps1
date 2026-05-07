function Get-ExcludedOUPaths {
    [OutputType([string[]])]

    $OUPattern = '^((OU=[^,]+,)+)(DC=[^,]+,DC=[^,]+)$'

    do {
        $WriteParams = @{ ForegroundColor = 'yellow' }
        Write-Host "Enter the paths for the any OU or OUs you would like to exclude from this search." @WriteParams
        Write-Host "Each path be in format: 'OU=Disabled,OU=Users,DC=company,DC=com'" @WriteParams
        Write-Host "Separate multiple OU paths with a semicolon: ';'" @WriteParams
        Write-Host "Enter 'l' to list the OUs in Active Directory"

        $RawInput = Read-Host "Disabled OU Path"

        if ($RawInput -ieq 'l') {
            Get-ADOrganizationalUnit -Filter '*' | Select-Object Name, DistinguishedName | Format-Table | Out-Host
            continue
        }

        $Exclusions = $RawInput -split ';' |
            Where-Object { $_ -Match '\S' } |
            ForEach-Object { $_.Trim() }

        $AllValid = $true

        if ($Exclusions.Count -eq 0) {
            Write-Warning "No input provided. Please enter at lease one OU path."
            $AllValid = $false
        } else {
            foreach ($OU in $Exclusions) {
                if ($OU -notmatch $OUPattern) {
                    Write-Warning "'$OU' is an invalid OU path format."
                    $AllValid = $false
                }
            }
        }
    }
    until ($AllValid)

    return $Exclusions
}

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
