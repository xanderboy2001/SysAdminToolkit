function Resolve-ToolkitHost {
    <#
    .SYNOPSIS
    Resolves a computer name in DNS and, optionally, checks that it accepts PowerShell remoting.

    .DESCRIPTION
    Replaces the old "resolve, then ping" checks. A ping says nothing about whether a server can be managed:
    Windows Firewall blocks ICMP by default, and a server can answer pings while WinRM is down.

    1. Resolves Name in DNS and returns the fully qualified host name. An IP address is returned unchanged,
       because reverse DNS is often not configured.
    2. With -RequireWinRM, runs Test-WSMan against that host.

    Either failure throws a terminating error that keeps the original exception as its inner exception:
    'SysAdminToolkit.HostNotResolved' or 'SysAdminToolkit.WinRMUnavailable'.

    .PARAMETER Name
    A host name, FQDN, or IP address.

    .PARAMETER RequireWinRM
    Also checks that the host accepts PowerShell remoting (WinRM).

    .EXAMPLE
    $broker = Resolve-ToolkitHost -Name 'broker01' -RequireWinRM
    # Returns 'broker01.contoso.com', or throws if the name does not resolve or WinRM does not answer.

    .OUTPUTS
    System.String. The resolved host name.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string]$Name,

        [switch]$RequireWinRM
    )

    $target = $Name.Trim()
    $address = $null
    if ([System.Net.IPAddress]::TryParse($target, [ref]$address)) {
        $hostName = $target
    } else {
        try {
            $hostName = [System.Net.Dns]::GetHostEntry($target).HostName
        } catch {
            # .NET method failures arrive wrapped in a MethodInvocationException; report the real cause.
            $cause = $_.Exception.InnerException ?? $_.Exception
            $errorParams = @{
                Message        = "Could not resolve '$target' in DNS : $($cause.Message)"
                InnerException = $cause
                ErrorId        = 'HostNotResolved'
                Category       = 'ObjectNotFound'
                TargetObject   = $target
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }
    }
    Write-Verbose "Resolved '$target' to '$hostName'."

    if ($RequireWinRM) {
        try {
            $null = Test-WSMan -ComputerName $hostName -ErrorAction Stop
        } catch {
            $errorParams = @{
                Message        = "'$hostName' does not accept PowerShell remoting (WinRM): $($_.Exception.Message)"
                InnerException = $_.Exception
                ErrorId        = 'WinRMUnavailable'
                Category       = 'ConnectionError'
                TargetObject   = $hostName
            }
            $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord @errorParams))
        }
        Write-Verbose "WinRM is available on '$hostName'."
    }

    $hostName
}
