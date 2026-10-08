function ConvertTo-TargetList {
    <#
    .SYNOPSIS
    Trims, drops blank entries, and removes case-insensitive duplicates while preserving input order.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]$InputObject
    )

    begin {
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    process {
        foreach ($item in $InputObject) {
            if ([string]::IsNullOrWhiteSpace($item)) {
                continue
            }
            $trimmed = $item.Trim()
            if ($seen.Add($trimmed)) {
                $trimmed
            }
        }
    }
}
