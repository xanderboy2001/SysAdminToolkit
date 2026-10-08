#Requires -Version 7.4
<#
.SYNOPSIS
One-off refactor script: moves every function in SysAdminToolkit to its own file (refactor Steps 2-4).

.DESCRIPTION
Run from the repository root on a clean working tree. For each function in $layout:
- If its source file contains only that function, the file is moved with 'git mv' (keeps history).
- If its source file contains several functions, the function text is extracted exactly as written by the
  PowerShell parser and written to its target file; the source file is removed if nothing is left in it.
Afterwards the script re-parses Private/ and Public/ and verifies that every function still exists exactly once
and that its text is unchanged (apart from line endings). Nothing is committed.

Supports -WhatIf to print the plan without touching any file.

.EXAMPLE
pwsh -NoProfile -File ./Move-ToolkitFunction.ps1 -WhatIf

.EXAMPLE
pwsh -NoProfile -File ./Move-ToolkitFunction.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Function name -> target path (relative to the repository root). Every function in Private/ and Public/ must
# appear here exactly once; the script refuses to run otherwise.
$layout = [ordered]@{
    # --- Public: exactly the exported commands --------------------------------------------------------------
    'Start-ToolkitMenu'             = 'Public/Start-ToolkitMenu.ps1'
    'Get-BatteryReport'             = 'Public/Client/Get-BatteryReport.ps1'
    'Open-PrinterWebInterface'      = 'Public/Client/Open-PrinterWebInterface.ps1'
    'Show-ReachabilityMenu'         = 'Public/Client/Show-ReachabilityMenu.ps1'
    'Stop-FileLock'                 = 'Public/Client/Stop-FileLock.ps1'
    'Test-ComputerReachability'     = 'Public/Client/Test-ComputerReachability.ps1'
    'Get-ADDisabledUsers'           = 'Public/Server/ActiveDirectory/Get-ADDisabledUsers.ps1'
    'Invoke-ADAccountDisable'       = 'Public/Server/ActiveDirectory/Invoke-ADAccountDisable.ps1'
    'Invoke-ADAccountUnlock'        = 'Public/Server/ActiveDirectory/Invoke-ADAccountUnlock.ps1'
    'Invoke-ADPasswordReset'        = 'Public/Server/ActiveDirectory/Invoke-ADPasswordReset.ps1'
    'Invoke-ADSync'                 = 'Public/Server/ActiveDirectory/Invoke-ADSync.ps1'
    'Get-RDConnectedUsers'          = 'Public/Server/RemoteDesktop/Get-RDConnectedUsers.ps1'
    'Restart-RDSBroker'             = 'Public/Server/RemoteDesktop/Restart-RDSBroker.ps1'
    'Set-RDSessionHostMode'         = 'Public/Server/RemoteDesktop/Set-RDSessionHostMode.ps1'

    # --- Private: menus (none of these are exported) --------------------------------------------------------
    'Show-ClientMenu'               = 'Private/Menu/Show-ClientMenu.ps1'
    'Show-ConfigMenu'               = 'Private/Menu/Show-ConfigMenu.ps1'
    'Show-ServerMenu'               = 'Private/Menu/Show-ServerMenu.ps1'
    'Show-ADMenu'                   = 'Private/Menu/Show-ADMenu.ps1'
    'Show-RDMenu'                   = 'Private/Menu/Show-RDMenu.ps1'
    'Show-TroubleshootingMenu'      = 'Private/Menu/Show-TroubleshootingMenu.ps1'
    'Show-Menu'                     = 'Private/Menu/Show-Menu.ps1'
    'Show-MenuHeader'               = 'Private/Menu/Show-MenuHeader.ps1'
    'Show-MenuOptions'              = 'Private/Menu/Show-MenuOptions.ps1'
    'Show-MenuInstructions'         = 'Private/Menu/Show-MenuInstructions.ps1'
    'Read-MenuSelection'            = 'Private/Menu/Read-MenuSelection.ps1'
    'Confirm-UserChoice'            = 'Private/Menu/Confirm-UserChoice.ps1'

    # --- Private: configuration ----------------------------------------------------------------------------
    'Get-ToolkitConfig'             = 'Private/Config/Get-ToolkitConfig.ps1'
    'Initialize-ToolkitConfig'      = 'Private/Config/Initialize-ToolkitConfig.ps1'
    'Save-ToolkitConfig'            = 'Private/Config/Save-ToolkitConfig.ps1'
    'Invoke-ViewConfig'             = 'Private/Config/Invoke-ViewConfig.ps1'
    'Invoke-EditConfig'             = 'Private/Config/Invoke-EditConfig.ps1'
    'Invoke-ResetConfig'            = 'Private/Config/Invoke-ResetConfig.ps1'

    # --- Private: Active Directory -------------------------------------------------------------------------
    'Convert-UsernameFormat'        = 'Private/ActiveDirectory/Convert-UsernameFormat.ps1'
    'Read-Username'                 = 'Private/ActiveDirectory/Read-Username.ps1'
    'Read-Password'                 = 'Private/ActiveDirectory/Read-Password.ps1'
    'Get-ValidADUser'               = 'Private/ActiveDirectory/Get-ValidADUser.ps1'
    'Write-ProtectedAccountWarning' = 'Private/ActiveDirectory/Write-ProtectedAccountWarning.ps1'
    'Get-FullNameFromUsername'      = 'Private/ActiveDirectory/Get-FullNameFromUsername.ps1'
    'Get-ExcludedOUPaths'           = 'Private/ActiveDirectory/Get-ExcludedOUPaths.ps1'

    # --- Private: Remote Desktop ---------------------------------------------------------------------------
    'Confirm-ConnectionBroker'      = 'Private/RemoteDesktop/Confirm-ConnectionBroker.ps1'
    'Get-ActiveBroker'              = 'Private/RemoteDesktop/Get-ActiveBroker.ps1'
    'Get-RDCollections'             = 'Private/RemoteDesktop/Get-RDCollections.ps1'
    'Get-RDHosts'                   = 'Private/RemoteDesktop/Get-RDHosts.ps1'
    'Select-RDSessionCollection'    = 'Private/RemoteDesktop/Select-RDSessionCollection.ps1'
    'Select-Server'                 = 'Private/RemoteDesktop/Select-Server.ps1'
    'Wait-RDMService'               = 'Private/RemoteDesktop/Wait-RDMService.ps1'
    'Restart-ServerAndWait'         = 'Private/RemoteDesktop/Restart-ServerAndWait.ps1'
    'Switch-ActiveBroker'           = 'Private/RemoteDesktop/Switch-ActiveBroker.ps1'

    # --- Private: client and network -----------------------------------------------------------------------
    'Get-FileLockProcess'           = 'Private/Client/Get-FileLockProcess.ps1'
    'ConvertTo-TargetList'          = 'Private/Network/ConvertTo-TargetList.ps1'
    'Expand-IPRange'                = 'Private/Network/Expand-IPRange.ps1'
    'Expand-NameRange'              = 'Private/Network/Expand-NameRange.ps1'
    'Invoke-Ping'                   = 'Private/Network/Invoke-Ping.ps1'
    'Test-SingleTarget'             = 'Private/Network/Test-SingleTarget.ps1'
}

$repoRoot = (Get-Location).Path
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'SysAdminToolkit.psd1'))) {
    throw 'Run this script from the repository root.'
}
if (-not $WhatIfPreference -and (git status --porcelain)) {
    throw 'The working tree is not clean. Commit or stash your changes first.'
}

function Get-RelativePath {
    param([string]$Path)
    [System.IO.Path]::GetRelativePath($repoRoot, $Path).Replace('\', '/')
}

function Get-FunctionInventory {
    # Returns one object per top-level function in Private/ and Public/.
    $files = Get-ChildItem -Path (Join-Path $repoRoot 'Private'), (Join-Path $repoRoot 'Public') `
        -Filter '*.ps1' -File -Recurse
    foreach ($file in $files) {
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$null, [ref]$parseErrors
        )
        if ($parseErrors) {
            throw "Parse error in '$($file.FullName)': $($parseErrors[0].Message)"
        }
        $functions = @($ast.FindAll(
                { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false
            ))
        foreach ($function in $functions) {
            [pscustomobject]@{
                Name          = $function.Name
                File          = Get-RelativePath $file.FullName
                FunctionCount = $functions.Count
                # Normalised for comparison: line endings and trailing whitespace on each line ignored.
                Text          = ($function.Extent.Text -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
            }
        }
    }
}

# --- Validate the plan -------------------------------------------------------------------------------------
$before = @(Get-FunctionInventory)

$duplicates = @($before | Group-Object Name | Where-Object Count -gt 1)
if ($duplicates) {
    throw "Functions defined more than once: $($duplicates.Name -join ', ')"
}
$unmapped = @($before.Name | Where-Object { -not $layout.Contains($_) })
if ($unmapped) {
    throw "Functions with no target in `$layout: $($unmapped -join ', ')"
}
$missing = @($layout.Keys | Where-Object { $_ -notin $before.Name })
if ($missing) {
    throw "Functions in `$layout that do not exist: $($missing -join ', ')"
}

$targetPaths = @($layout.Values)
$sourceFiles = @($before.File | Sort-Object -Unique)

# --- Move single-function files with git mv (keeps history) ------------------------------------------------
foreach ($entry in $before | Where-Object FunctionCount -eq 1) {
    $target = $layout[$entry.Name]
    if ($entry.File -eq $target) {
        continue
    }
    if ($PSCmdlet.ShouldProcess("$($entry.File) -> $target", 'git mv')) {
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force
        git mv -- $entry.File $target
        if ($LASTEXITCODE) { throw "git mv failed for '$($entry.File)'." }
    }
}

# --- Extract functions from multi-function files ------------------------------------------------------------
# All text was captured in $before, so overwriting a source file that is also a target is safe.
foreach ($entry in $before | Where-Object FunctionCount -gt 1) {
    $target = $layout[$entry.Name]
    if ($PSCmdlet.ShouldProcess("$($entry.Name) from $($entry.File) -> $target", 'Extract function')) {
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force
        Set-Content -LiteralPath $target -Value $entry.Text -Encoding utf8
    }
}

foreach ($file in ($before | Where-Object FunctionCount -gt 1).File | Sort-Object -Unique) {
    if ($file -notin $targetPaths -and $PSCmdlet.ShouldProcess($file, 'git rm (all functions extracted)')) {
        git rm --quiet -- $file
        if ($LASTEXITCODE) { throw "git rm failed for '$file'." }
    }
}

if ($WhatIfPreference) {
    return
}

# --- Verify: same functions, one per file, correct paths, unchanged text ------------------------------------
$after = @(Get-FunctionInventory)
$problems = [System.Collections.Generic.List[string]]::new()

foreach ($old in $before) {
    $new = @($after | Where-Object Name -eq $old.Name)
    if ($new.Count -ne 1) {
        $problems.Add("$($old.Name): found $($new.Count) definitions after the move")
        continue
    }
    if ($new[0].File -ne $layout[$old.Name]) {
        $problems.Add("$($old.Name): ended up in '$($new[0].File)' instead of '$($layout[$old.Name])'")
    }
    if ($new[0].Text -cne $old.Text) {
        $problems.Add("$($old.Name): function text changed during the move")
    }
}
foreach ($new in $after | Where-Object FunctionCount -ne 1) {
    $problems.Add("$($new.File): contains $($new.FunctionCount) functions")
}
foreach ($new in $after | Where-Object Name -notin $before.Name) {
    $problems.Add("$($new.Name): new function appeared in '$($new.File)'")
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Warning $_ }
    throw ("Verification failed ($($problems.Count) problem(s)). " +
        'Undo with: git reset --hard; git clean -fd Private Public')
}

git add -A -- Private Public
Write-Output "Moved $($before.Count) functions into $($after.Count) files. Verification passed."
Write-Output 'Review with: git status; git diff --cached --stat -M'
