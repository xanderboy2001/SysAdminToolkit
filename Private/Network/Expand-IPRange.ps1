function Expand-IPRange {
    <#
    .SYNOPSIS
    Returns every IPv4 address from StartIPAddress to EndIPAddress, inclusive (maximum 5001 addresses).

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$StartIPAddress,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EndIPAddress
    )

    # [long] keeps the math unsigned-safe; [int] goes negative for addresses at or above 128.0.0.0.
    $toNumber = {
        param([string]$Address)
        $parsed = $null
        $isIPv4 = $Address -match '^\d{1,3}(\.\d{1,3}){3}$' -and
        [System.Net.IPAddress]::TryParse($Address, [ref]$parsed) -and
        $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork

        if (-not $isIPv4) {
            throw "'$Address' is not a valid dotted-quad IPv4 address."
        }
        $bytes = $parsed.GetAddressBytes()
        ([long]$bytes[0] -shl 24) -bor ([long]$bytes[1] -shl 16) -bor ([long]$bytes[2] -shl 8) -bor [long]$bytes[3]
    }

    $startValue = & $toNumber $StartIPAddress
    $endValue = & $toNumber $EndIPAddress

    if ($startValue -gt $endValue) {
        throw 'StartIPAddress must be lower than EndIPAddress'
    }
    if (($endValue - $startValue) -gt 5000) {
        throw 'IP range too long'
    }

    for ($value = $startValue; $value -le $endValue; $value++) {
        # Each octet is parenthesized: the comma operator binds tigher than -band.
        '{0}.{1}.{2}.{3}' -f (($value -shr 24) -band 0xFF), (($value -shr 16) -band 0xFF),
        (($value -shr 8) -band 0xFF), ($value -band 0xFF)
    }
}
