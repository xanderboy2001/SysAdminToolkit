function Expand-NameRange {
    param($StartName, $EndName)

    if ($StartName -notmatch '^(?<prefix>.*?)(?<number>\d+)$') {
        throw "Invalid StartName"
    }

    $startPrefix = $Matches.prefix
    $startNumber = [int]$Matches.number
    $padding = $Matches.number.Length

    if ($EndName -notmatch '^(?<prefix>.*?)(?<number>\d+)$') {
        throw "Invalid EndName"
    }

    $endPrefix = $Matches.prefix
    $endNumber = [int]$Matches.number

    if ($startPrefix -ne $endPrefix) {
        throw "Prefixes must match"
    }
    if ($startNumber -gt $endNumber) {
        throw "Invalid range"
    }
    if (($endNumber - $startNumber) -gt 5000) {
        throw "Range too large"
    }

    for ($i = $startNumber; $i -le $endNumber; $i++) {
        "{0}{1}" -f $startPrefix, ($i.ToString("D$padding"))
    }
}
