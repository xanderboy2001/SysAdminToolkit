function Expand-IPRange {
    param($StartIPAddress, $EndIPAddress)

    function ConvertTo-Int($ip) {
        $bytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
        $result = 0

        foreach ($b in $bytes) {
            $result = ($result -shl 8) + $b
        }
        return $result
    }

    function ConvertTo-IP($int) {
        @(
            ($int -shr 24) -band 0xFF,
            ($int -shr 16) -band 0XFF,
            ($int -shr 8) -band 0xFF,
            $int -band 0xFF
        ) -join '.'
    }

    $startInt = ConvertTo-Int $StartIPAddress
    $endInt = ConvertTo-Int $EndIPAddress

    if ($startInt -gt $endInt) {
        throw "StartIPAddress must be lower than EndIPAddress"
    }

    if (($endInt - $startInt) -gt 5000) {
        throw "IP range too large"
    }

    for ($i = $startInt; $i -le $endInt; $i++) {
        ConvertTo-IP $i
    }
}
