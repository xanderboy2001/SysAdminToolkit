$script:ModuleRoot = $PSScriptRoot

# Load private scripts (helpers)
$PrivatePath = Join-Path $PSScriptRoot 'Private'
$PrivateFunctions = @()
if (Test-Path $PrivatePath) {
    Get-ChildItem -Path $PrivatePath -Recurse -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
        $PrivateFunctions += $_.BaseName
    }
}

# Load public functions and collect their functions
$PublicPath = Join-Path $PSScriptRoot 'Public'
$PublicFunctions = @()
if (Test-Path $PublicPath) {
    Get-ChildItem -Path $PublicPath -Recurse -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
        $PublicFunctions += $_.BaseName
    }
}

try {
    Initialize-ToolkitConfig
} catch {
    Write-Debug "Config init skipped"
}

# Export all public functions
$FunctionList = @($PublicFunctions + $PrivateFunctions)
$FunctionList += "Start-ToolkitMenu"
Export-ModuleMember -Function $FunctionList
