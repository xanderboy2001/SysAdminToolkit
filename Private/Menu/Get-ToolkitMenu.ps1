function Get-ToolkitMenu {
    <#
    .SYNOPSIS
    Returns the definition of every toolkit menu.

    .DESCRIPTION
    Each key is a menu name. Each menu has a Title and an ordered list of Items. An item has a Label and exactly
    one of:
    - Menu   : the name of another menu to open (Back returns here).
    - Action : a script block to run; the menu is shown again when it finishes.

    Invoke-ToolkitMenu walks this structure, so adding a menu option is a data change, not new navigation code.

    .OUTPUTS
    System.Collections.Hashtable

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        Main            = @{
            Title = 'SysAdmin Toolkit'
            Items = @(
                @{ Label = 'Server'; Menu = 'Server' }
                @{ Label = 'Client'; Menu = 'Client' }
                @{ Label = 'Config'; Menu = 'Config' }
            )
        }
        Server          = @{
            Title = 'Server Menu'
            Items = @(
                @{ Label = 'Active Directory'; Menu = 'ActiveDirectory' }
                @{ Label = 'Remote Desktop'; Menu = 'RemoteDesktop' }
                @{ Label = 'Troubleshooting'; Menu = 'Troubleshooting' }
            )
        }
        ActiveDirectory = @{
            Title = 'Active Directory Menu'
            Items = @(
                @{ Label = 'Reset Password'; Action = { Invoke-ADPasswordReset } }
                @{ Label = 'Unlock Account'; Action = { Invoke-ADAccountUnlock } }
                @{ Label = 'Disable User'; Action = { Invoke-ADAccountDisable } }
                @{ Label = 'Start AD Sync'; Action = { Invoke-ADSync } }
                @{ Label = 'Get Disabled Users'; Action = { Get-ADDisabledUser } }
            )
        }
        RemoteDesktop   = @{
            Title = 'Remote Desktop Menu'
            Items = @(
                @{
                    Label  = 'Reboot Connection Brokers'
                    Action = { Restart-RDSBroker -BrokerServer (Get-ToolkitConfig).RDBrokerServer }
                }
                @{
                    Label  = 'Toggle New Connections on Server'
                    Action = { Set-RDSessionHostMode -ConnectionBroker (Get-ToolkitConfig).RDBrokerServer }
                }
                @{
                    Label  = 'List connected users'
                    Action = { Get-RDConnectedUser -ConnectionBroker (Get-ToolkitConfig).RDBrokerServer }
                }
            )
        }
        Troubleshooting = @{
            Title = 'Server Troubleshooting Menu'
            Items = @(
                # Placeholder until Get-ServerDiskType exists (F-12).
                @{
                    Label  = 'Query Server Disk Type'
                    Action = { Write-Warning "'Query Server Disk Type' is not implemented yet." }
                }
            )
        }
        Client          = @{
            Title = 'Client Menu'
            Items = @(
                @{ Label = 'Unlock a file being held by a process'; Action = { Stop-FileLock } }
                @{ Label = 'Get battery report of a computer'; Action = { Get-BatteryReport } }
                @{ Label = "Open a Printer's Web Interface"; Action = { Open-PrinterWebInterface } }
                @{ Label = 'Test computer reachability'; Menu = 'Reachability' }
            )
        }
        Reachability    = @{
            Title = 'Reachability Menu'
            Items = @(
                @{ Label = 'Test list of computer names / IPs'; Action = { Invoke-ReachabilityPrompt -Mode List } }
                @{ Label = 'Test device naming range'; Action = { Invoke-ReachabilityPrompt -Mode NameRange } }
                @{ Label = 'Test IP address range'; Action = { Invoke-ReachabilityPrompt -Mode IPRange } }
            )
        }
        Config          = @{
            Title = 'Configuration'
            Items = @(
                @{ Label = 'View Config'; Action = { Invoke-ViewConfig } }
                @{ Label = 'Edit Config'; Action = { Invoke-EditConfig } }
                @{ Label = 'Reset Config to Defaults'; Action = { Invoke-ResetConfig } }
            )
        }
    }
}
