function Test-AdministratorSession {
    <#
    .SYNOPSIS
    Returns $true when the current session is elevated (running as administrator).

    .NOTES
    Author: Alexander Christian
    Separate function so tests can mock elevation.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
