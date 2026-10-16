# Changelog

All notable changes to SysAdminToolkit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). While the version is below 1.0.0, minor versions
may contain breaking changes; they are listed under **Breaking** in each entry.

## [Unreleased]

### Breaking

- `Invoke-ADPasswordReset` requires `-Identity` and `-NewPassword` (a SecureString) and never prompts. It no
  longer unlocks the account automatically: use `-Unlock`. It returns one object (`SamAccountName`, `Name`,
  `PasswordReset`, `ChangePasswordAtLogon`, `WasLocked`, `Unlocked`). The interactive version is now only in
  the menu (**Server > Active Directory > Reset Password**), which asks whether to unlock a locked account and
  whether to require a password change at the next sign-in
  ([#1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1)).
- `Invoke-ADSync` never prompts and returns one object (`ComputerName`, `Status`, `ElapsedSeconds`). Without
  `-ComputerName` it uses the `ADConnectServer` setting and fails if that is empty; the prompt for the server
  is now only in the menu (**Server > Active Directory > Start AD Sync**). A failed remote call is now a
  terminating error ([#1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1)).
- `Set-RDSessionHostMode` no longer toggles hosts or prompts. It requires `-SessionHost` and
  `-NewConnectionAllowed Yes|No`, leaves hosts already in that state alone, and returns one object per host
  (`SessionHost`, `CollectionName`, `PreviousState`, `NewConnectionAllowed`, `Result`). A host that cannot be
  changed is reported and the others are still processed. The menu item is renamed **Allow or block new
  connections** and asks which state to set ([#1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1)).

### Added

- `Invoke-ADPasswordReset -Unlock` and `-ChangePasswordAtLogon`.
- `Invoke-ADSync -ComputerName`.
- `Set-RDSessionHostMode -ConnectionBroker` defaults to the `RDBrokerServer` setting, and `-SessionHost` accepts
  pipeline input.

## [0.4.0] - 2026-10-15

### Breaking

- `Get-RDConnectedUser` returns one object per session (`SessionHost`, `CollectionName`, `UserName`,
  `DomainName`, `FullName`, `SessionState`, `SessionId`) and never prompts. Without `-ConnectionBroker` it uses
  the `RDBrokerServer` setting; without `-CollectionName` and `-SessionHost` it returns every session. The
  pick-a-collection-and-host version is now only in the menu (**Server > Remote Desktop > List connected
  users**) ([#1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1)).
- `Invoke-ADAccountUnlock` requires `-Identity` and never prompts for a username. It returns one object per
  account (`SamAccountName`, `Name`, `DistinguishedName`, `WasLocked`, `Result`) instead of printing messages.
  The prompt-for-a-username version is now only in the menu (**Server > Active Directory > Unlock Account**)
  ([#1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1)).
- `Invoke-ADAccountDisable` requires `-Identity` and never prompts for a username. It returns one object per
  account (`SamAccountName`, `Name`, `DistinguishedName`, `WasEnabled`, `Result`) instead of printing messages.
  The prompt-for-a-username version is now only in the menu (**Server > Active Directory > Disable User**)
  ([#1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1)).

### Added

- `Get-RDConnectedUser -CollectionName` and `-SessionHost`.
- `Invoke-ADAccountUnlock` accepts several identities and pipeline input, for example from
  `Search-ADAccount -LockedOut`.
- `Invoke-ADAccountDisable` accepts several identities and pipeline input, and leaves accounts that are already
  disabled alone.

## [0.3.0] - 2026-10-15

### Breaking

- The **Server > Troubleshooting** menu is removed. Its only item, "Query Server Disk Type", was never
  implemented.
- `ADConnectServer` no longer defaults to a server name; `Invoke-ADSync` prompts until it is set. Existing
  configurations keep their value.
- `Invoke-ADPasswordReset` and `Invoke-ADAccountUnlock` use the standard PowerShell confirmation prompt instead
  of their own "Enter y or yes" prompt, and the password reset no longer asks twice. Note that the standard
  prompt's default answer is **Yes**. `Invoke-ADAccountUnlock` now asks for confirmation by default.

### Added

- `-Force` on `Invoke-ADPasswordReset`, `Invoke-ADAccountUnlock`, and `Invoke-ADAccountDisable`.
- `Get-ADDisabledUser -NoExclusion` returns every disabled account without prompting.
- An optional, never-committed `Tests/LocalForbiddenTerms.txt`: when present, a test fails if any tracked file
  contains one of its terms.

### Fixed

- `Get-ADDisabledUser` treated `[`, `]`, `*`, and `?` in OU names as wildcards, only accepted OU paths with
  exactly two `DC=` parts, and could not be run without excluding at least one OU. Containers (`CN=`) and
  escaped commas are now accepted, and pressing Enter at the prompt excludes nothing.
- `Set-RDSessionHostMode` read and changed session hosts through the broker you named, which may be the passive
  one; it now uses the active broker.
- `Open-PrinterWebInterface` saved the print server for any answer that did not contain "n", and asked again
  after saving.
- `Read-Password` accepted an empty password, and could leave a plain-text copy in memory if the comparison was
  interrupted.

### Changed

- Examples and prompts use neutral names (`PC-0100`, `LAPTOP01`) instead of the naming scheme of one network.
- `Restart-RDSBroker`, `Set-RDSessionHostMode`, `Get-RDConnectedUser`, `Invoke-ADSync`, and `Stop-FileLock`
  check that a server resolves in DNS and accepts PowerShell remoting (WinRM) instead of pinging it. Servers
  that block ping now work; servers that answer ping but have WinRM turned off now fail before anything is
  changed, with a message that says so. `Restart-ServerAndWait` uses the same check before each reboot.
  `Open-PrinterWebInterface` only checks DNS for the print server.
- Errors from these commands keep the original exception in `$Error[0].Exception.InnerException` and have
  `FullyQualifiedErrorId` values that start with `SysAdminToolkit.` (for example
  `SysAdminToolkit.WinRMUnavailable`), so scripts can tell failures apart.
- Host names are resolved with `Dns.GetHostEntry` instead of the obsolete `Dns.GetHostByName`.

## [0.2.0] - 2026-10-13

First release after a full code review. Changes are relative to 0.0.1.

### Breaking

- PowerShell 7.4 or later is required. Windows PowerShell 5.1 was listed as supported but could not run the
  module.
- The module configuration is only loaded when only administrators can change it, and saving settings requires
  an elevated session. Folders created by 0.0.1 must be repaired once; see
  [Securing the configuration](README.md#securing-the-configuration).
- Internal helpers are no longer exported: `ConvertTo-TargetList`, `Expand-IPRange`, `Expand-NameRange`,
  `Invoke-Ping`, `Test-SingleTarget`.
- `Get-ADDisabledUsers` is now `Get-ADDisabledUser`, and `Get-RDConnectedUsers` is now `Get-RDConnectedUser`.
  The old names still work as aliases.
- `Restart-RDSBroker` now asks for confirmation (use `-Force` to skip it) and throws a terminating error when a
  step fails.
- `Stop-FileLock` asks for confirmation for each process (use `-Force` to skip it) instead of one `[Y/n]` prompt,
  and returns one result object per process.
- The default `SysinternalsPath` is now `C:\Program Files\Sysinternals` instead of
  `\\live.sysinternals.com\tools`. Existing configurations keep their current value.

### Added

- `-WhatIf` and `-Confirm` on `Stop-FileLock`, `Restart-RDSBroker`, `Set-RDSessionHostMode`, and `Invoke-ADSync`.
- `Restart-RDSBroker` is exported. It was defined but could not be called directly.
- `Invoke-ADSync -TimeoutSeconds` and the `ADSyncTimeoutSecs` setting (default 1800 seconds).
- `Get-BatteryReport` accepts several computers, including pipeline input from `Get-ADComputer`, and returns
  `BatteryId`, `Status`, and `CycleCount`.
- A warning when the account chosen for a password reset, unlock, or disable is a protected (`adminCount = 1`)
  account.
- Comment-based help for every public command.
- Pester tests, PSScriptAnalyzer settings, a test report script, and a GitHub Actions workflow.

### Changed

- Menus run in one loop: Back returns to the previous menu, invalid input shows the same menu again, every menu
  is shown again after its action, and an action that fails no longer exits the toolkit.
- Status messages from the Remote Desktop helpers use the verbose and information streams instead of
  `Write-Host`. `Restart-RDSBroker` still shows its progress by default.
- `RDMaxRetries` now means exactly that many service checks (it used to allow one extra check).
- Every function is in its own file, named after the function.

### Fixed

- `Test-ComputerReachability` did not work: the parallel runspaces could not load the helper functions, and every
  target was pinged as the host name "1".
- IP ranges did not expand, and ranges crossing 128.0.0.0 were rejected.
- `Stop-FileLock` stopped the process IDs found on a remote computer on the local computer instead, ignored its
  `-FileName` and `-ComputerName` parameters, and could report "No processes found" before the search finished.
- `Set-RDSessionHostMode` accepted an out-of-range collection number, and selecting a host twice toggled it twice.
- `Get-RDConnectedUser` counted users of `rds10` when `rds1` was selected, and stopped listing when a user was not
  in Active Directory.
- Password reset, unlock, and disable could continue with no account selected when a display-name search found
  nothing.
- `Invoke-ADSync` could wait forever, and started a second cycle when one was already running.
- Broker reboots compared service status inconsistently, gave the active-broker switch only one check after
  10 seconds, and reported failures without saying which step failed.
- `Get-BatteryReport` failed on computers with two batteries, hid connection errors, and left its report file
  behind when it failed.
- `Open-PrinterWebInterface` opened the wrong address for printer ports named like `IP_10.0.0.5`, and its help
  was not shown by `Get-Help`.
- Changing a setting reported success even when saving failed, a corrupt configuration file caused confusing
  errors, and the file was rewritten on every import.
- The "Query Server Disk Type" menu item threw an error because the command does not exist; it now shows a
  "not implemented" warning.

### Security

- `Stop-FileLock` refuses to run `handle.exe` unless it has a valid Microsoft signature, never stops process IDs
  0, 4, or its own process, and checks that a process ID still belongs to the same program before stopping it.
- The configuration controls which program `Stop-FileLock` runs and which servers are rebooted, so it is ignored
  when non-administrators can change it.
- An internal domain name was removed from the source code.

### Known issues

- Seven interactive commands print results instead of returning objects
  ([#1](https://github.com/xanderboy2001/SysAdminToolkit/issues/1)).
- `Get-ADDisabledUser` treats `[`, `]`, `*`, and `?` in OU names as wildcards, only accepts OU paths with exactly
  two `DC=` parts, and always prompts when `-Exclusions` is not given.
- Several Remote Desktop and Entra Connect commands still require the server to answer a ping.
- "Query Server Disk Type" is not implemented.

## [0.0.1]

- Initial version.

[Unreleased]: https://github.com/xanderboy2001/SysAdminToolkit/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/xanderboy2001/SysAdminToolkit/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/xanderboy2001/SysAdminToolkit/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/xanderboy2001/SysAdminToolkit/releases/tag/v0.2.0
[0.0.1]: https://github.com/xanderboy2001/SysAdminToolkit/commits/main
