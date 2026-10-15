function Get-FullNameFromUsername {
    <#
    .SYNOPSIS
    Returns the Name of the Active Directory user with the given sAMAccountName.

    .PARAMETER
    The sAMAccountName to look up.

    .OUTPUTS
    System.String

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
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
        $errorParams = @{
            Message        = "No Active Directory user has the username '$UserName'."
            InnerException = $_.Exception
            ErrorId        = 'UserNotFound'
            Category       = 'ObjectNotFound'
            TargetObject   = $UserName
        }
        $PSCmdlet.ThrowTerminatingError((New-ToolkitErrorRecord @errorParams))
    }
}
