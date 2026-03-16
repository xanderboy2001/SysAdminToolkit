#Requires -RunAsAdministrator

$script:ModuleRoot = $PSScriptRoot

# Load private scripts (helpers)
$PrivatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $PrivatePath) {
    Get-ChildItem -Path $PrivatePath -Recurse -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

# Load public functions and collect their functions
$PublicPath = Join-Path $PSScriptRoot 'Public'
if (Test-Path $PublicPath) {
    Get-ChildItem -Path $PublicPath -Recurse -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

Initialize-ToolkitConfig

# Export all public functions
Export-ModuleMember -Function @(
    'Start-ToolkitMenu'
)
