<#
.SYNOPSIS
    Fixes markdownlint errors in PlatyPS-generated documentation.

.DESCRIPTION
    Processes all .md files in the target docs folder and corrects the following
    issues introduced by PlatyPS output:

    - MD022: Inserts missing blank lines above and below headings.
    - MD026: Removes trailing periods from heading text.
    - MD031: Inserts missing blank lines around fenced code blocks.
    - MD040: Adds 'powershell' language specifier to bare opening fences.

    Intended to be run after `docs:gen` or `docs:update` to keep generated docs
    lint-clean without manual editing.

.PARAMETER DocsPath
    Path to the folder containing the generated .md files. Defaults to './docs'.

.EXAMPLE
    .\scripts\Repair-DocsFencing.ps1
    # Fixes all .md files in ./docs with default settings.

.EXAMPLE
    .\scripts\Repair-DocsFencing.ps1 -DocsPath './docs/generated'
    # Fixes all .md files in a custom output folder.

.NOTES
    Author: Alexander Christian
    Safe to re-run — already-correct files are left unchanged.
#>
param(
    [string]$DocsPath = './docs'
)

Get-ChildItem -Path $DocsPath -Filter '*.md' | ForEach-Object {
    $lines = Get-Content $_.FullName
    $result = [System.Collections.Generic.List[string]]::new()
    $inBlock = $false
    $inFrontMatter = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $prev = if ($result.Count -gt 0) {
            $result[$result.Count - 1] 
        } else {
            $null 
        }
        $next = if ($i + 1 -lt $lines.Count) {
            $lines[$i + 1] 
        } else {
            $null 
        }

        # Pass front matter through unchanged
        if ($i -eq 0 -and $line -eq '---') {
            $inFrontMatter = $true
            $result.Add($line)
            continue
        }
        if ($inFrontMatter) {
            $result.Add($line)
            if ($line -eq '---') {
                $inFrontMatter = $false 
            }
            continue
        }

        # Fenced code blocks
        if ($line -match '^```') {
            if ($inBlock) {
                # Closing fence — ensure blank line follows
                $inBlock = $false
                $result.Add($line)
                if ($null -ne $next -and $next -ne '') {
                    $result.Add('')
                }
            } else {
                # Opening fence — fix missing language and ensure blank line precedes
                $inBlock = $true
                if ($line -eq '```') {
                    $line = '```powershell' 
                }
                if ($null -ne $prev -and $prev -ne '') {
                    $result.Add('')
                }
                $result.Add($line)
            }
            continue
        }

        if ($inBlock) {
            $result.Add($line)
            continue
        }

        # Headings — fix trailing punctuation and ensure surrounding blank lines
        if ($line -match '^#{1,6} ') {
            $line = $line -replace '\.$', ''
            if ($null -ne $prev -and $prev -ne '') {
                $result.Add('')
            }
            $result.Add($line)
            if ($null -ne $next -and $next -ne '') {
                $result.Add('')
            }
            continue
        }

        $result.Add($line)
    }

    $result | Set-Content $_.FullName -Encoding UTF8
}
