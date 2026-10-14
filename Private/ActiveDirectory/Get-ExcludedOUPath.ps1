function Get-ExcludedOUPath {
    <#
    .SYNOPSIS
    Prompts for the OUs to leave out of Get-ADDisabledUser.

    .DESCRIPTION
    Accepts one or more OU or container distinguished names separated by semicolons. Enter 'l' to list the OUs in
    the domain. Press Enter without typing anything to leave nothing out. Re-prompts until every entry is a valid
    distinguished name (see Test-ADDistinguishedName).

    .OUTPUTS
    System.String. Zero or more distinguished names.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    while ($true) {
        $writeParams = @{ ForegroundColor = 'Yellow' }
        Write-Host 'Enter the OU or OUs to leave out of this search, for example:' @writeParams
        Write-Host "  OU=Disabled,OU=Users,DC=contoso,DC=com" @writeParams
        Write-Host "Separate several OUs with a semicolon (;). Enter 'l' to list the OUs." @writeParams
        Write-Host 'Press Enter without typing anything to include every OU.' @writeParams

        $rawInput = Read-Host 'OUs to exclude'

        if ($rawInput -ieq 'l') {
            Get-ADOrganizationalUnit -Filter '*' | Select-Object -Property Name, DistinguishedName |
                Format-Table | Out-Host
            continue
        }

        $exclusions = @($rawInput -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $invalid = @($exclusions | Where-Object { -not (Test-ADDistinguishedName -DistinguishedName $_) })
        if ($invalid.Count -eq 0) {
            return [string[]]$exclusions
        }
        foreach ($entry in $invalid) {
            Write-Warning "'$entry' is not a valid OU or container distinguished name."
        }
    }
}
