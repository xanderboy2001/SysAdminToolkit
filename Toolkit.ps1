<#
.SYNOPSIS
Entry point for the SysAdmin Toolkit

.DESCRIPTION
This script loads the SysAdmin Toolkit module and launches the main menu.
It serves as the primary entry pont for users to access server and client menus.

.EXAMPLE
.\Toolkit.ps1
# Launches the SysAdmin Toolkit main menu

.NOTES
Author: Alexander Christian
Module: SysAdminToolkit
#>

Import-Module "$PSScriptRoot/Modules/SysAdminToolkit/SysAdminToolkit.psm1" -Force

Show-MainMenu