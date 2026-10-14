function Test-ADDistinguishedName {
    <#
    .SYNOPSIS
    Returns $true when a string looks like the distinguished name of an OU or container.

    .DESCRIPTION
    Accepts one or more OU= or CN= parts followed by one or more DC= parts, for example
    'OU=Disabled,OU=Users,DC=contoso,DC=com' or 'CN=Users,DC=corp,DC=contoso,DC=com'. Escaped commas (\,) inside
    a name are allowed. This is a format check only; it does not query Active Directory.

    .PARAMETER DistinguishedName
    The string to check.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$DistinguishedName
    )

    # A name part is any run of characters that are not a comma or backslash, or a backslash-escaped character.
    $namePart = '(?:[^,\\]|\\.)+'
    $pattern = "^(?:(?:OU|CN)=$namePart,)+DC=$namePart(?:,DC=$namePart)*$"
    $DistinguishedName -match $pattern
}
