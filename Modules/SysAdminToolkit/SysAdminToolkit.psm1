<#
.SYNOPSIS
SysAdmin Toolkit Powershell module.

.DESCRIPTION
This module loads all menu-related functions for the SysAdmin Toolkit, including:
- Core menu utilities
- Main menu
- Server menus (and Active Directory submenu)
- Client menu

Once imported, it provides the Show-MainMenu function and all supporting menu functions.

.EXAMPLE
Import-Module "$PSScriptRoot/SysAdminToolkit.psm1" -Force
Show-MainMenu
# Loads the module and launches the SysAdmin Toolkit main menu.

.NOTES
Author: Alexander Christian
Module: SysAdminToolkit
#>

# Core Menu Utilities
. $PSScriptRoot/MenuCore.ps1

# Main Menu
. $PSScriptRoot/MainMenu.ps1

# Server Menus
. $PSScriptRoot/Server/ServerMenu.ps1
. $PSScriptRoot/Server/ActiveDirectory/ADMenu.ps1

# Client Menus
. $PSScriptRoot/Client/ClientMenu.ps1