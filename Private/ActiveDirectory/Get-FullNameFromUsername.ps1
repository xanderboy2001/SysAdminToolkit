function Get-FullNameFromUsername {
    [OutputType([string])]
    param(
        [Parameter(
            Mandatory,
            HelpMessage = "The username of the Active Directory user to lookup."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$UserName
    )

    try {
        Get-ADUser -Identity $UserName | Select-Object -ExpandProperty Name
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        throw "Invalid username: '$UserName'. Exception Message: $($_.Exception.Message)"
    }
}
