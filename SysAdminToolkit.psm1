$script:ModuleRoot = $PSScriptRoot
$script:ConfigPath = Join-Path -Path $env:ProgramData -ChildPath "SysAdminToolkit\Config\config.psd1"
$script:DefaultConfigPath = Join-Path $script:ModuleRoot "Config\config.defaults.psd1"
Set-StrictMode -Version 3.0

# Load private helpers first, then public commands. A file that fails to load fails the import loudly instead
# of leaving the module half-loaded
foreach ($folderName in 'Private', 'Public') {
    $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folderName
    if (-not (Test-Path -LiteralPath $folderPath)) {
        continue
    }
    foreach ($file in Get-ChildItem -LiteralPath $folderPath -Filter "*.ps1" -File -Recurse) {
        try {
            . $file.FullName
        } catch {
            throw "SysAdminToolkit: failed to load '$($file.FullName)': $($_.Exception.Message)"
        }
    }
}

try {
    Initialize-ToolkitConfig
} catch {
    Write-Warning "SysAdminToolkit: configuration could not be initialized: $($_.Exception.Message)"
}
