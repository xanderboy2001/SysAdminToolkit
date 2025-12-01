<#
.SYNOPSIS
SysAdmin Toolkit Powershell module.

.DESCRIPTION
This module loads all menu-related functions for the SysAdmin Toolkit, including:
- Core menu utilities
- Main menu
- Server menus (and Active Directory submenu)
- Client menu

Once imported, it provides the Start-ToolkitMenu function and all supporting menu functions.

.EXAMPLE
Import-Module "$PSScriptRoot/SysAdminToolkit.psm1" -Force
Start-ToolkitMenu
# Loads the module and launches the SysAdmin Toolkit main menu.

.NOTES
Author: Alexander Christian
Module: SysAdminToolkit
#>


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

# Export all public functions
Export-ModuleMember -Function @(
    'Start-ToolkitMenu'
)
