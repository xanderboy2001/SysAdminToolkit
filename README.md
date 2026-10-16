# SysAdmin Toolkit

[![GitHub issues](https://img.shields.io/github/issues/xanderboy2001/SysAdminToolkit?style=for-the-badge)](https://github.com/xanderboy2001/SysAdminToolkit/issues)
[![GitHub license](https://img.shields.io/github/license/xanderboy2001/SysAdminToolkit?style=for-the-badge)](https://github.com/xanderboy2001/SysAdminToolkit/blob/main/LICENSE.md)

A menu-driven PowerShell module for day-to-day administration of a hybrid Windows environment: Active Directory
accounts, Entra Connect sync, Remote Desktop Services, and Windows clients.

## Table of contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Commands](#commands)
5. [Configuration](#configuration)
6. [Securing the configuration](#securing-the-configuration)
7. [Development](#development)
8. [License](#license)
9. [Contact](#contact)

## Requirements

- Windows with **PowerShell 7.4 or later**. Windows PowerShell 5.1 is not supported.
- The **ActiveDirectory** module (RSAT). The module will not import without it.
- The **RemoteDesktop** module, for the Remote Desktop commands. It is available on Windows Server with the
  Remote Desktop Services tools installed.
- **WinRM** (PowerShell remoting) access to the computers you manage.
- The **ADSync** module on the Entra Connect server, for `Invoke-ADSync`.
- Sysinternals **handle.exe**, for `Stop-FileLock`. See [Sysinternals](#sysinternals).
- Rights in Active Directory and on the servers for the tasks you run. The toolkit runs everything with your own
  account.

## Installation

The module is meant to be installed on one admin server and used from administrator accounts.

1. From an elevated session, copy the repository to a location only administrators can write to, keeping the
   folder name `SysAdminToolkit`:

   ```powershell
   git clone https://github.com/xanderboy2001/SysAdminToolkit.git "C:\Program Files\PowerShell\Modules\SysAdminToolkit"
   ```

2. Open an **elevated** PowerShell 7 session (Run as administrator) and import the module once. This creates the
   configuration folder with administrator-only write access:

   ```powershell
   Import-Module SysAdminToolkit
   ```

3. Set your servers through the menu: **Config** > **Edit Config** (still in the elevated session). See
   [Configuration](#configuration).

4. From then on, any session can use the toolkit:

   ```powershell
   Start-ToolkitMenu
   ```

To update, run `git pull` in the module folder from an elevated session, then `Import-Module SysAdminToolkit
-Force`.

## Usage

`Start-ToolkitMenu` opens the main menu:

```text
SysAdmin Toolkit
├── Server
│   ├── Active Directory   Reset Password · Unlock Account · Disable User · Start AD Sync · Get Disabled Users
│   └── Remote Desktop     Reboot Connection Brokers · Toggle New Connections on Server · List connected users
├── Client                 Unlock a file · Battery report · Printer web interface · Test computer reachability
└── Config                 View Config · Edit Config · Reset Config to Defaults
```

- Enter the number of an option.
- `B` or `Back` returns to the previous menu.
- `Q`, `Quit`, `E`, `Exit`, `C`, or `Cancel` leaves the toolkit from any menu.
- After an action finishes, the same menu is shown again. If an action fails, its error is shown and the menu
  comes back.

Every command can also be run on its own. Use `Get-Help <command> -Full` for details and examples.

## Commands

| Command | What it does | Changes anything? |
|---|---|---|
| `Start-ToolkitMenu` | Opens the toolkit menu | No |
| `Invoke-ADPasswordReset` | Resets an AD user's password; optionally unlocks and forces a change at sign-in | Yes: asks for confirmation |
| `Invoke-ADAccountUnlock` | Unlocks locked AD accounts; accepts pipeline input | Yes: asks for confirmation |
| `Invoke-ADAccountDisable` | Disables AD accounts; accepts pipeline input | Yes: asks for confirmation |
| `Invoke-ADSync` | Runs an Entra Connect delta sync, waits for it, and returns the result | Yes: supports `-WhatIf` |
| `Get-ADDisabledUser` | Lists disabled AD accounts, leaving out chosen OUs | No |
| `Restart-RDSBroker` | Reboots all Connection Brokers one at a time, moving the active role between them | Yes: asks for confirmation |
| `Set-RDSessionHostMode` | Switches new connections on or off (toggles) for chosen session hosts | Yes: supports `-WhatIf` |
| `Get-RDConnectedUser` | Returns the user sessions on session hosts, with full names from AD | No |
| `Stop-FileLock` | Finds and stops the processes holding a file open, locally or on another computer | Yes: asks for each process |
| `Get-BatteryReport` | Reports battery capacity for one or more computers | No |
| `Open-PrinterWebInterface` | Opens a shared printer's web page | No |
| `Test-ComputerReachability` | Pings a list, a numbered name range, or an IP range in parallel | No |
| `Show-ReachabilityMenu` | Opens the reachability menu on its own | No |

The interactive commands prompt for anything you do not pass as a parameter. Most of them print their results
instead of returning objects; changing that is tracked in
[issue #1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1). `Get-BatteryReport`,
`Test-ComputerReachability`, `Get-ADDisabledUser`, `Get-RDConnectedUser`, `Invoke-ADAccountUnlock`,
`Invoke-ADAccountDisable`, `Invoke-ADPasswordReset`, `Invoke-ADSync`, and `Stop-FileLock` return objects you can
pipe and export.

Examples:

```powershell
# Unlock every locked user account, after confirming each one.
Search-ADAccount -LockedOut -UsersOnly | Invoke-ADAccountUnlock

# Who is connected to rds1, and in what state?
Get-RDConnectedUser -SessionHost rds1 | Select-Object -Property FullName, UserName, SessionState

# Preview a broker reboot without changing anything.
Restart-RDSBroker -WhatIf

# Laptops whose batteries hold less than 60% of their design capacity.
Get-ADComputer -Filter "Name -like 'LAPTOP*'" | Get-BatteryReport -ErrorAction SilentlyContinue |
    Where-Object CapacityPercent -lt 60

# Which processes on FS01 would be stopped?
Stop-FileLock -FileName 'D:\Shares\Finance\Budget.xlsx' -ComputerName FS01 -WhatIf
```

## Configuration

Settings are stored in one machine-wide file, `C:\ProgramData\SysAdminToolkit\Config\config.psd1`, shared by
every administrator on the server. View them with **Config** > **View Config**. Change them with
**Config** > **Edit Config** from an elevated session.

| Setting | Default | Used by |
|---|---|---|
| `ADConnectServer` | *(empty)* | `Invoke-ADSync`: the Entra Connect server (the menu prompts if empty) |
| `ADSyncTimeoutSecs` | `1800` | `Invoke-ADSync`: how long to wait for a sync cycle |
| `RDBrokerServer` | *(empty: you are prompted)* | Remote Desktop commands: any Connection Broker |
| `RDMaxRetries` | `15` | `Restart-RDSBroker`: service checks per broker, 30 seconds apart |
| `RDTimeoutSecs` | `600` | `Restart-RDSBroker`: how long to wait for a broker to restart |
| `SysinternalsPath` | `C:\Program Files\Sysinternals` | `Stop-FileLock`: the folder containing `handle.exe` |
| `PrintServer` | *(not set: you are prompted)* | `Open-PrinterWebInterface`: added when you choose to save it |
| `ReportsPath` | `C:\ProgramData\SysAdminToolkit\Reports` | Not used yet |

New settings added by later versions are filled in with their defaults automatically.

## Securing the configuration

SysAdminToolkit uses one machine-wide configuration file:
`C:\ProgramData\SysAdminToolkit\Config\config.psd1`. It decides which executable `Stop-FileLock` runs and
which servers the toolkit contacts and reboots, so only administrators may change it.

On import, the module checks the folder and the file. If anyone other than Administrators, SYSTEM, or
TrustedInstaller owns them or can change them, the file is **not loaded**: the module uses default settings,
refuses to save, and shows a warning.

- **Reading** settings works in any session.
- **Saving** settings (Config menu, `Open-PrinterWebInterface`) requires an elevated session
  (Run as administrator).
- **New server:** import the module once from an elevated session. The folder is created with the correct
  permissions automatically.

### Repairing an existing folder

Folders created by earlier versions inherit permissions from `C:\ProgramData`, which let standard users create
and change files. To repair one, open an **elevated** PowerShell session on the server and:

1. Check the current settings. Someone may have changed them; confirm every value is what you expect:

   ```powershell
   Get-Content "$env:ProgramData\SysAdminToolkit\Config\config.psd1"
   ```

2. Apply the permissions:

   ```powershell
   Import-Module SysAdminToolkit -WarningAction SilentlyContinue
   & (Get-Module SysAdminToolkit) { Protect-ToolkitConfigDirectory -Path (Split-Path $script:ConfigPath) }
   ```

3. Confirm: `Import-Module SysAdminToolkit -Force` shows no warning, and
   `icacls "$env:ProgramData\SysAdminToolkit\Config"` lists only Administrators and SYSTEM with full control (F)
   and Users with read & execute (RX).

### Where to install the module

Install the module where only administrators can write, for example
`C:\Program Files\PowerShell\Modules\SysAdminToolkit`. Protecting the configuration does not help if a
standard user can edit the module's own code.

### Sysinternals

The default `SysinternalsPath` is `C:\Program Files\Sysinternals`. Copy `handle.exe` there (it must carry a
valid Microsoft signature). Existing configurations keep their current value; change it through the Config menu
in an elevated session.

For `Stop-FileLock -ComputerName`, `handle.exe` runs on the target computer, so it must exist at the same path
there.

## Development

Run the tests and the analyzer, and write a shareable report, from the repository root:

```powershell
pwsh -NoProfile -File ./Tools/Export-TestReport.ps1 -IncludeIntegration
```

This writes `TestReport.md` and `ScriptAnalyzer.csv` and exits with code 1 if any test fails or the analyzer
cannot check a file. It needs Pester 5.5 or later and PSScriptAnalyzer. One test changes folder permissions and
only runs in an elevated session.

Every pull request to `main` runs the same checks in GitHub Actions and must pass with no analyzer findings and
no formatting differences. Format a file with:

```powershell
Invoke-Formatter -ScriptDefinition (Get-Content -Raw .\Path\To\File.ps1) -Settings .\PSScriptAnalyzerSettings.psd1
```

Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

Distributed under the GNU General Public License v3.0. See [LICENSE.md](LICENSE.md).

## Contact

- **Alexander Christian**: <alexanderechristian@gmail.com>
- Project: <https://github.com/xanderboy2001/SysAdminToolkit>
