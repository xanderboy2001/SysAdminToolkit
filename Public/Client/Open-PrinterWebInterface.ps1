function Open-PrinterWebInterface {
    <#
    .SYNOPSIS
    Opens a shared printer's web configuration page in the default browser.

    .DESCRIPTION
    Uses the PrintServer toolkit setting (or prompts for a print server and optionally saves it), prompts for a
    printer name (enter 'l' to list printers), resolves the printer's TCP/IP port address with Get-PrinterPort,
    and opens http://<address> in the default browser. If the port is not a standard TCP/IP port, the port name
    is used as the address.

    .EXAMPLE
    Open-PrinterWebInterface
    # Prompts for a printer and opens its web interface.

    .NOTES
    Author: Alexander Christian
    Requires the PrintManagement module to access the print server.
    #>
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

        # Ask until the answer is clearly yes or no; Enter means yes. Save once, after the loop.
        do {
            $answer = Read-Host -Prompt 'Save this print server to the configuration? [Y/n]'
        } until ($answer -match '^\s*(y|yes|n|no)?\s*$')

        if ($answer -notmatch '^\s*n') {
            $config = Get-ToolkitConfig
            $config['PrintServer'] = $printServer
            try {
                Save-ToolkitConfig -Config $config
            } catch {
                Write-Warning "Could not save PrintServer to the configuration: $($_.Exception.Message)"
            }
        }
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

    $PortName = $printerList | Where-Object { $_.Name -ieq $printerName } |
        Select-Object -ExpandProperty PortName

    # Port names are often 'IP_10.0.0.5' or custom labels; the TCP/IP port's PrinterHostAddress is the real target.
    $printerPort = Get-PrinterPort -ComputerName $printServer -Name $PortName -ErrorAction SilentlyContinue
    $address = if ($printerPort.PrinterHostAddress) {
        $printerPort.PrinterHostAddress
    } else {
        $PortName
    }

    $uri = $null
    if (-not [System.Uri]::TryCreate("http://$address", [System.UriKind]::Absolute, [ref]$uri)) {
        throw "Printer '$printerName' does not have a usable network address (port '$PortName')."
    }

    Start-Process -FilePath $uri.AbsoluteUri
}
