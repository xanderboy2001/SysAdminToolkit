#Requires -Version 5.1
<#
.SYNOPSIS
  Takes a printer name as input and opens the WebUI for configuration in the browser.

.DESCRIPTION
  This script will ask the user to provide a printer name. The user can also
  enter 'l' to list all printers. Once a printer name has been verified, the
  script will get the port field for the printer using Get-Printer and will
  open the IP address in the web browser.

.EXAMPLE
  PS .\Open-PrinterWebInterface.ps1

.NOTES
  Author: Your Name
#>
[CmdletBinding()]
param ()

function Open-PrinterWebInterface {
    [CmdletBinding()]
    param ()

    $printServer = (Get-ToolkitConfig).PrintServer

    if (-not $printServer) {

        do {
            $printServer = Read-Host -Prompt "Enter the name of the server your printer is connected to"
            Write-Verbose "Verifying connection to $printServer..."
            $serverValid = $(Test-Connection -TargetName $printServer -Count 1 -Quiet)
            if ($serverValid -eq $true) {
                Write-Verbose "$printServer is reachable."
                break
            } else {
                Write-Warning "Invalid server name. Please try again."
            }
        } while (-not $serverValid)

        do {
            $shouldSave = Read-Host -p "Would you like to save this value to the configuration file? [Y/n]"
            if ($shouldSave -notmatch '[Nn].*') {
                $config = Get-ToolkitConfig
                $config['PrintServer'] = $printServer
                Save-ToolkitConfig -Config $config
            }
        } while ($shouldSave -ne '' -and $shouldSave -notmatch '[YyNn].*')
    }



    $printerList = Get-Printer -ComputerName $printServer | Select-Object -Property Name, PortName

    do {
        $prompt = "Enter the name of the printer you wish to configure or enter 'l' to list all printers"
        $printerName = Read-Host -Prompt $prompt
        if ($printerName -ieq 'l') {
            $printerList | Format-Table
        } else {
            Write-Verbose "Validating $printerName..."
            $printerValid = ($printerName -iin ($printerList | Select-Object -ExpandProperty Name))
            if ($printerValid -eq $true) {
                Write-Verbose "$printerName is valid."
                break
            } else {
                Write-Warning "Invalid printer name. Please try again."
            }
        }
    } while (-not $printerValid)

    $ip = $printerList | Where-Object { $_.Name -ieq $printerName } | Select-Object -ExpandProperty PortName
    $url = "http://$ip"

    Start-Process "explorer.exe" $url
}
