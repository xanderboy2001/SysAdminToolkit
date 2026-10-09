#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '',
    Justification = 'Computer names in this file are fake test data.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
    Justification = 'Stub functions accept and deliberately ignore all arguments.')]
param()

BeforeDiscovery {
    $script:sourceFiles = Get-ChildItem -Path (Join-Path $PSscriptRoot '..') -Include '*.ps1', '*.psm1', '*.psd1' `
        -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]Tests[\\/]' }

    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = [System.Security.Principal.WindowsPrincipal]::new($currentIdentity)
    $script:isElevated = $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    $script:moduleRoot = Join-Path $PSscriptRoot '..'
    $script:manifestPath = Join-Path $script:moduleRoot 'SysAdminToolkit.psd1'

    # RemoteDesktop cmdlets are mocked; create stubs when the RemoteDesktop module is not installed (e.g. CI).
    $script:rdCommands = @(
        'Get-RDServer', 'Get-RDConnectionBrokerHighAvailability', 'Set-RDActiveManagementServer',
        'Get-RDSessionCollection', 'Get-RDSessionHost', 'Set-RDSessionHost', 'Get-RDUserSession'
    )
    foreach ($commandName in $script:rdCommands) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            $null = New-Item -Path "function:global:$commandName" -Value {
                param([Parameter(ValueFromRemainingArguments)]$RemainingArguments)
            }
        }
    }

    Import-Module $script:manifestPath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module SysAdminToolkit -Force -ErrorAction SilentlyContinue
    foreach ($commandName in $script:rdCommands) {
        $stub = Get-Item -Path "function:global:$commandName" -ErrorAction SilentlyContinue
        if ($stub -and -not $stub.Module) {
            Remove-Item -Path "function:global:$commandName"
        }
    }
}

Describe 'Source files' {
    It '<_.Name> parses without errors' -ForEach $script:sourceFiles {
        $tokens = $null
        $parseErrors = $null
        $parser = [System.Management.Automation.Language.Parser]
        $null = $parser::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'Module manifest and public API' {
    It 'is a valid manifest' {
        { Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'targets PowerShell 7.4 Core' {
        $manifest = Import-PowerShellDataFile -Path $script:manifestPath
        $manifest.PowerShellVersion | Should -Be '7.4'
        $manifest.CompatiblePSEditions | Should -Be @('Core')
    }

    It 'exports exactly the documented public commands' {
        $expected = @(
            'Get-ADDisabledUser', 'Get-BatteryReport', 'Get-RDConnectedUser', 'Invoke-ADAccountDisable',
            'Invoke-ADAccountUnlock', 'Invoke-ADPasswordReset', 'Invoke-ADSync', 'Open-PrinterWebInterface',
            'Restart-RDSBroker', 'Set-RDSessionHostMode', 'Show-ReachabilityMenu', 'Start-ToolkitMenu',
            'Stop-FileLock', 'Test-ComputerReachability'
        ) | Sort-Object
        $actual = (Get-Command -Module SysAdminToolkit -CommandType Function).Name | Sort-Object
        $actual | Should -Be $expected
    }

    It 'does not export private helper <_>' -ForEach @(
        'ConvertTo-TargetList', 'Expand-IPRange', 'Expand-NameRange', 'Invoke-Ping', 'Test-SingleTarget',
        'Save-ToolkitConfig', 'Get-ValidADUser', 'Read-Password'
    ) {
        Get-Command -Module SysAdminToolkit -Name $_ -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'state-changing command <_> supports -WhatIf' -ForEach @(
        'Stop-FileLock', 'Restart-RDSBroker', 'Set-RDSessionHostMode', 'Invoke-ADAccountDisable',
        'Invoke-ADAccountUnlock', 'Invoke-ADPasswordReset'
    ) {
        (Get-Command -Name $_).Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'keeps the pre-0.1 plural names working as aliases' -ForEach @(
        @{ Alias = 'Get-ADDisabledUsers'; Target = 'Get-ADDisabledUser' }
        @{ Alias = 'Get-RDConnectedUsers'; Target = 'Get-RDConnectedUser' }
    ) {
        $command = Get-Command -Name $Alias -Module SysAdminToolkit
        $command.CommandType | Should -Be 'Alias'
        $command.ResolvedCommand.Name | Should -Be $Target
    }
}

Describe 'ConvertTo-TargetList' {
    It 'trims, drops blanks, and removes case-insensitive duplicates in input order' {
        InModuleScope SysAdminToolkit {
            $result = ConvertTo-TargetList -InputObject @(' PC2 ', 'pc1', '', $null, 'PC1', 'pc2')
            $result | Should -Be @('PC2', 'pc1')
        }
    }
}

Describe 'Expand-NameRange' {
    It 'preserves zero padding' {
        InModuleScope SysAdminToolkit {
            Expand-NameRange -StartName 'PC-0098' -EndName 'PC-0101' |
                Should -Be @('PC-0098', 'PC-0099', 'PC-0100', 'PC-0101')
        }
    }

    It 'rejects mismatched prefixes' {
        InModuleScope SysAdminToolkit {
            { Expand-NameRange -StartName 'D-1' -EndName 'L-2' } | Should -Throw '*Prefixes must match*'
        }
    }

    It 'rejects ranges larger than 5001 names' {
        InModuleScope SysAdminToolkit {
            { Expand-NameRange -StartName 'D-1' -EndName 'PC-9000' } | Should -Throw '*too large*'
        }
    }
}

Describe 'Expand-IPRange' {
    It 'expands across an octet boundary above 128.0.0.0' {
        InModuleScope SysAdminToolkit {
            Expand-IPRange -StartIPAddress '192.168.1.254' -EndIPAddress '192.168.2.1' |
                Should -Be @('192.168.1.254', '192.168.1.255', '192.168.2.0', '192.168.2.1')
        }
    }

    It 'rejects a reversed range' {
        InModuleScope SysAdminToolkit {
            { Expand-IPRange -StartIPAddress '10.0.0.5' -EndIPAddress '10.0.0.1' } | Should -Throw
        }
    }

    It 'handles a range that crosses 128.0.0.0' {
        InModuleScope SysAdminToolkit {
            Expand-IPRange -StartIPAddress '127.255.255.255' -EndIPAddress '128.0.0.1' |
                Should -Be @('127.255.255.255', '128.0.0.0', '128.0.0.1')
        }
    }

    It 'rejects invalid address <_>' -ForEach @('10', '::1', '10.0.0.256', 'abc') {
        InModuleScope SysAdminToolkit -Parameters @{ Address = $_ } {
            param($Address)
            { Expand-IPRange -StartIPAddress $Address -EndIPAddress '10.0.0.1' } | Should -Throw
        }
    }
}

Describe 'Test-SingleTarget' {
    It 'pings the requested target with the requested count (regression: Target was passed $Count)' {
        InModuleScope SysAdminToolkit {
            Mock Invoke-Ping {
                [pscustomobject]@{ Status = 'Success'; Latency = 4; Address = [ipaddress]'10.0.0.5' }
                [pscustomobject]@{ Status = 'Success'; Latency = 6; Address = [ipaddress]'10.0.0.5' }
            }

            $result = Test-SingleTarget -Target 'PC1' -Count 2

            Should -Invoke Invoke-Ping -Times 1 -Exactly -ParameterFilter { $Target -eq 'PC1' -and $Count -eq 2 }
            $result.Online | Should -BeTrue
            $result.IPAddress | Should -Be '10.0.0.5'
            $result.ResponseTime | Should -Be 5
        }
    }

    It 'reports offline when there is no reply' {
        InModuleScope SysAdminToolkit {
            Mock Invoke-Ping { }
            $result = Test-SingleTarget -Target 'PC1'
            $result.Online | Should -BeFalse
            $result.ResponseTime | Should -BeNullOrEmpty
        }
    }
}

Describe 'Test-ComputerReachability (integration)' -Tag 'Integration' {
    It 'tests the loopback address once even when supplied twice' {
        $result = @(Test-ComputerReachability -ComputerName '127.0.0.1', '127.0.0.1')
        $result.Count | Should -Be 1
        $result[0].Online | Should -BeTrue
    }
}

Describe 'Stop-FileLock' {
    BeforeEach {
        Mock -ModuleName SysAdminToolkit Get-ToolkitConfig { @{ SysinternalsPath = 'C:\Tools' } }
        Mock -ModuleName SysAdminToolkit Test-WSMan { }
        Mock -ModuleName SysAdminToolkit Read-Host { throw 'Read-Host must not be called' }
        Mock -ModuleName SysAdminToolkit Stop-Process { }
        Mock -ModuleName SysAdminToolkit Get-FileLockProcess {
            [pscustomobject]@{ ComputerName = 'PC1'; ProcessName = 'EXCEL.EXE'; PID = 1234; Path = 'C:\x.xlsx' }
        }
    }

    It 'stops remote processes on the remote computer, never locally (regression)' {
        Mock -ModuleName SysAdminToolkit Invoke-Command { 'Stopped' }

        $result = Stop-FileLock -FileName 'C:\x.xlsx' -ComputerName 'PC1' -Force

        Should -Invoke -ModuleName SysAdminToolkit Stop-Process -Times 0 -Exactly
        Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 1 -Exactly -ParameterFilter {
            $ComputerName -eq 'PC1'
        }
        $result.Result | Should -Be 'Stopped'
    }

    It 'does not stop anything with -WhatIf' {
        Mock -ModuleName SysAdminToolkit Invoke-Command { 'Stopped' }

        Stop-FileLock -FileName 'C:\x.xlsx' -ComputerName 'PC1' -WhatIf

        Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 0 -Exactly
    }

    It 'skips a local PID that now belongs to a different process' {
        Mock -ModuleName SysAdminToolkit Get-Process { [pscustomobject]@{ ProcessName = 'notepad' } }

        $result = Stop-FileLock -FileName 'C:\x.xlsx' -Force

        $result.Result | Should -BeLike 'Skipped*'
        Should -Invoke -ModuleName SysAdminToolkit Stop-Process -Times 0 -Exactly
    }

    It 'honours -FileName without prompting' {
        Mock -ModuleName SysAdminToolkit Get-Process { [pscustomobject]@{ ProcessName = 'EXCEL' } }

        { Stop-FileLock -FileName 'C:\x.xlsx' -Force } | Should -Not -Throw
        Should -Invoke -ModuleName SysAdminToolkit Stop-Process -Times 1 -Exactly -ParameterFilter { $Id -eq 1234 }
    }
}

Describe 'Restart-RDSBroker' {
    BeforeEach {
        Mock -ModuleName SysAdminToolkit Get-ToolkitConfig { @{ RDTimeoutSecs = 600; RDMaxRetries = 15 } }
        Mock -ModuleName SysAdminToolkit Test-Connection { $true }
        Mock -ModuleName SysAdminToolkit Write-Host { }
        Mock -ModuleName SysAdminToolkit Restart-ServerAndWait { }
        Mock -ModuleName SysAdminToolkit Switch-ActiveBroker { }
        Mock -ModuleName SysAdminToolkit Get-ActiveBroker { 'B1.CONTOSO.TEST' }
    }

    It 'reboots nothing with -WhatIf' {
        Mock -ModuleName SysAdminToolkit Get-RDServer {
            [pscustomobject]@{ Server = 'B1.CONTOSO.TEST' }
            [pscustomobject]@{ Server = 'B2.CONTOSO.TEST' }
        }

        Restart-RDSBroker -BrokerServer 'localhost' -WhatIf

        Should -Invoke -ModuleName SysAdminToolkit Restart-ServerAndWait -Times 0 -Exactly
    }

    It 'refuses to run with a single broker' {
        Mock -ModuleName SysAdminToolkit Get-RDServer { [pscustomobject]@{ Server = 'B1.CONTOSO.TEST' } }

        Restart-RDSBroker -BrokerServer 'localhost' -Force -ErrorAction SilentlyContinue -ErrorVariable errors

        Should -Invoke -ModuleName SysAdminToolkit Restart-ServerAndWait -Times 0 -Exactly
        "$errors" | Should -BeLike '*Only one Connection Broker*'
    }

    It 'refuses to run when the active broker is not in the broker list' {
        Mock -ModuleName SysAdminToolkit Get-RDServer {
            [pscustomobject]@{ Server = 'B2.CONTOSO.TEST' }
            [pscustomobject]@{ Server = 'B3.CONTOSO.TEST' }
        }

        Restart-RDSBroker -BrokerServer 'localhost' -Force -ErrorAction SilentlyContinue

        Should -Invoke -ModuleName SysAdminToolkit Restart-ServerAndWait -Times 0 -Exactly
    }

    It 'reboots the inactive broker before the original active broker' {
        # InModuleScope so that $script:rebootOrder is the same variable in the test and in the mock body.
        InModuleScope SysAdminToolkit {
            Mock Get-RDServer {
                [pscustomobject]@{ Server = 'B1.CONTOSO.TEST' }
                [pscustomobject]@{ Server = 'B2.CONTOSO.TEST' }
            }
            $script:rebootOrder = [System.Collections.Generic.List[string]]::new()
            Mock Restart-ServerAndWait { $script:rebootOrder.Add($ComputerName) }

            Restart-RDSBroker -BrokerServer 'localhost' -Force

            $script:rebootOrder | Should -Be @('B2.CONTOSO.TEST', 'B1.CONTOSO.TEST')
        }
    }
}

Describe 'Set-RDSessionHostMode selection helpers' {
    It 'Select-Server de-duplicates repeated indices (regression: 1,1 toggled twice)' {
        InModuleScope SysAdminToolkit {
            Mock Write-Host { }
            Mock Read-Host { '1,1' }
            $servers = @(
                [pscustomobject]@{ SessionHost = 'rds1'; NewConnectionAllowed = $true }
                [pscustomobject]@{ SessionHost = 'rds2'; NewConnectionAllowed = $false }
            )
            @(Select-Server -Servers $servers).Count | Should -Be 1
        }
    }

    It 'Select-RDSessionCollection re-prompts on out-of-range and non-numeric input (regression: off-by-one)' {
        InModuleScope SysAdminToolkit {
            Mock Write-Host { }
            $script:answers = [System.Collections.Generic.Queue[string]]::new([string[]]@('3', 'abc', '2'))
            Mock Read-Host { $script:answers.Dequeue() }

            Select-RDSessionCollection -Collections @('apps', 'desktops') | Should -Be 'desktops'
            Should -Invoke Read-Host -Times 3 -Exactly
        }
    }
}

Describe 'Get-ValidADUser' {
    It 're-prompts instead of returning $null when a display-name search finds nothing (regression)' {
        InModuleScope SysAdminToolkit {
            Mock Write-Host { }
            $script:usernames = [System.Collections.Generic.Queue[string]]::new([string[]]@('john doe', 'jdoe'))
            Mock Read-Username { $script:usernames.Dequeue() }
            Mock Get-ADUser -ParameterFilter { $Filter } { }
            Mock Get-ADUser -ParameterFilter { $Identity } {
                [pscustomobject]@{
                    SamAccountName    = 'jdoe'
                    DisplayName       = 'John Doe'
                    DistinguishedName = 'CN=John Doe,OU=Users,DC=contoso,DC=test'
                    adminCount        = $null
                }
            }

            $user = Get-ValidADUser

            $user.SamAccountName | Should -Be 'jdoe'
            Should -Invoke Read-Username -Times 2 -Exactly
        }
    }
}

Describe 'Toolkit configuration' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            # Every test points the module at $TestDrive; restore the real state afterwards.
            $script:savedConfigPath = $script:ConfigPath
            $script:savedToolkitConfig = $script:ToolkitConfig
            $script:savedBlockedReason = $script:ConfigWriteBlockedReason
            $script:ConfigWriteBlockedReason = $null
        }
    }

    AfterEach {
        InModuleScope SysAdminToolkit {
            $script:ConfigPath = $script:savedConfigPath
            $script:ToolkitConfig = $script:savedToolkitConfig
            $script:ConfigWriteBlockedReason = $script:savedBlockedReason
        }
    }

    Context 'Initialize-ToolkitConfig with a protected folder' {
        BeforeEach {
            # Permissions are tested separately; here the folder is treated as protected and the session as
            # elevated, so the loading logic can be tested in $TestDrive.
            Mock -ModuleName SysAdminToolkit Test-ToolkitConfigTrust {
                [pscustomobject]@{ Path = $Path; IsTrusted = $true; Reasons = @() }
            }
            Mock -ModuleName SysAdminToolkit Test-AdministratorSession { $true }
            Mock -ModuleName SysAdminToolkit Protect-ToolkitConfigDirectory {
                $null = New-Item -ItemType Directory -Path $Path -Force
            }
        }

        It 'reports a corrupt config file clearly, does not overwrite it, and keeps defaults loaded' {
            InModuleScope SysAdminToolkit {
                $script:ConfigPath = Join-Path $TestDrive 'corrupt\config.psd1'
                $null = New-Item -ItemType Directory -Path (Split-Path $script:ConfigPath) -Force
                Set-Content -LiteralPath $script:ConfigPath -Value 'not a hashtable'

                { Initialize-ToolkitConfig } | Should -Throw '*is not a valid .psd1 file*'

                Get-Content -LiteralPath $script:ConfigPath -Raw | Should -BeLike 'not a hashtable*'
                $script:ToolkitConfig | Should -Not -BeNullOrEmpty
            }
        }

        It 'creates a protected folder and the file from defaults when neither exists' {
            InModuleScope SysAdminToolkit {
                $script:ConfigPath = Join-Path $TestDrive 'new\config.psd1'

                Initialize-ToolkitConfig

                Should -Invoke Protect-ToolkitConfigDirectory -Times 1 -Exactly
                $defaults = Import-PowerShellDataFile -LiteralPath $script:DefaultConfigPath
                $loaded = Import-PowerShellDataFile -LiteralPath $script:ConfigPath
                $loaded.Keys.Count | Should -Be $defaults.Keys.Count
                $loaded.RDMaxRetries | Should -Be $defaults.RDMaxRetries
            }
        }

        It 'does not rewrite an existing complete config file' {
            InModuleScope SysAdminToolkit {
                $script:ConfigPath = Join-Path $TestDrive 'existing\config.psd1'
                Initialize-ToolkitConfig
                $before = (Get-Item -LiteralPath $script:ConfigPath).LastWriteTimeUtc
                Start-Sleep -Milliseconds 50

                Initialize-ToolkitConfig

                (Get-Item -LiteralPath $script:ConfigPath).LastWriteTimeUtc | Should -Be $before
            }
        }

        It 'keeps new default keys in memory when they cannot be saved' {
            InModuleScope SysAdminToolkit {
                $script:ConfigPath = Join-Path $TestDrive 'backfill\config.psd1'
                $null = New-Item -ItemType Directory -Path (Split-Path $script:ConfigPath) -Force
                Set-Content -LiteralPath $script:ConfigPath -Value "@{ RDBrokerServer = 'broker1' }"
                Mock Save-ToolkitConfig { throw 'Saving the configuration requires an elevated session.' }

                Initialize-ToolkitConfig -WarningVariable initWarnings -WarningAction SilentlyContinue

                $script:ToolkitConfig.RDBrokerServer | Should -Be 'broker1'
                $script:ToolkitConfig.ContainsKey('ADSyncTimeoutSecs') | Should -BeTrue
                "$initWarnings" | Should -BeLike '*could not be saved*'
            }
        }
    }

    Context 'Initialize-ToolkitConfig without a protected folder' {
        It 'ignores the file, uses defaults, and blocks saving when non-administrators can change it' {
            InModuleScope SysAdminToolkit {
                Mock Test-ToolkitConfigTrust {
                    [pscustomobject]@{ Path = $Path; IsTrusted = $false; Reasons = @("'Users' can modify it") }
                }
                $script:ConfigPath = Join-Path $TestDrive 'tampered\config.psd1'
                $null = New-Item -ItemType Directory -Path (Split-Path $script:ConfigPath) -Force
                Set-Content -LiteralPath $script:ConfigPath -Value "@{ SysinternalsPath = '\\attacker\share' }"

                Initialize-ToolkitConfig -WarningVariable initWarnings -WarningAction SilentlyContinue

                $defaults = Import-PowerShellDataFile -LiteralPath $script:DefaultConfigPath
                $script:ToolkitConfig.SysinternalsPath | Should -Be $defaults.SysinternalsPath
                "$initWarnings" | Should -BeLike '*NOT loaded*'
                { Save-ToolkitConfig -Config @{ PrintServer = 'x' } } | Should -Throw '*could not be saved*'
                Get-Content -LiteralPath $script:ConfigPath -Raw | Should -BeLike '*attacker*'
            }
        }

        It 'does not create the folder from a non-elevated session' {
            InModuleScope SysAdminToolkit {
                Mock Test-AdministratorSession { $false }
                Mock Protect-ToolkitConfigDirectory { }
                $script:ConfigPath = Join-Path $TestDrive 'not-elevated\config.psd1'

                Initialize-ToolkitConfig -WarningAction SilentlyContinue

                Should -Invoke Protect-ToolkitConfigDirectory -Times 0 -Exactly
                Test-Path -LiteralPath (Split-Path $script:ConfigPath) | Should -BeFalse
                $script:ToolkitConfig | Should -Not -BeNullOrEmpty
                $script:ConfigWriteBlockedReason | Should -BeLike '*elevated session*'
            }
        }
    }

    Context 'Save-ToolkitConfig' {
        It 'round-trips quotes (including typographic quotes) and integers' {
            InModuleScope SysAdminToolkit {
                $script:ConfigPath = Join-Path $TestDrive 'config.psd1'
                $config = @{
                    PrintServer  = "it's"
                    Tricky       = "a$([char]0x2019)b"
                    RDMaxRetries = 15
                }

                Save-ToolkitConfig -Config $config

                $loaded = Import-PowerShellDataFile -Path $script:ConfigPath
                $loaded.PrintServer | Should -Be "it's"
                $loaded.Tricky | Should -Be "a$([char]0x2019)b"
                $loaded.RDMaxRetries | Should -BeOfType [int]
                $loaded.Keys.Count | Should -Be 3
            }
        }

        It 'does not update in-memory configuration when the write fails' {
            InModuleScope SysAdminToolkit {
                $originalConfig = $script:ToolkitConfig
                $script:ConfigPath = Join-Path $TestDrive 'missing-dir\config.psd1'

                { Save-ToolkitConfig -Config @{ PrintServer = 'new' } } | Should -Throw

                [object]::ReferenceEquals($script:ToolkitConfig, $originalConfig) | Should -BeTrue
            }
        }

        It 'refuses to write while saving is blocked' {
            InModuleScope SysAdminToolkit {
                $script:ConfigPath = Join-Path $TestDrive 'blocked.psd1'
                $script:ConfigWriteBlockedReason = 'test reason'

                { Save-ToolkitConfig -Config @{ PrintServer = 'x' } } | Should -Throw '*test reason*'

                Test-Path -LiteralPath $script:ConfigPath | Should -BeFalse
            }
        }
    }
}

Describe 'Test-ToolkitConfigTrust' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            # Builds an in-memory folder security descriptor; Get-Acl is mocked to return it.
            function script:New-TestAcl {
                param([string]$OwnerSid, [hashtable[]]$Rules)
                $acl = [System.Security.AccessControl.DirectorySecurity]::new()
                $acl.SetOwner([System.Security.Principal.SecurityIdentifier]::new($OwnerSid))
                foreach ($rule in $Rules) {
                    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
                            [System.Security.Principal.SecurityIdentifier]::new($rule.Sid),
                            [System.Security.AccessControl.FileSystemRights]$rule.Rights,
                            'ContainerInherit, ObjectInherit', 'None', $rule.Type))
                }
                $acl
            }
            $script:adminsFull = @{ Sid = 'S-1-5-32-544'; Rights = 'FullControl'; Type = 'Allow' }
            $script:systemFull = @{ Sid = 'S-1-5-18'; Rights = 'FullControl'; Type = 'Allow' }
            $script:usersRead = @{ Sid = 'S-1-5-32-545'; Rights = 'ReadAndExecute'; Type = 'Allow' }
            Mock Get-Acl { $script:testAcl }
        }
    }

    It 'trusts an Administrators-owned folder that only Administrators and SYSTEM can change' {
        InModuleScope SysAdminToolkit {
            $script:testAcl = New-TestAcl -OwnerSid 'S-1-5-32-544' -Rules $adminsFull, $systemFull, $usersRead

            $result = Test-ToolkitConfigTrust -Path 'C:\Fake'

            $result.IsTrusted | Should -BeTrue
            $result.Reasons | Should -BeNullOrEmpty
        }
    }

    It 'does not trust a folder owned by a non-administrator' {
        InModuleScope SysAdminToolkit {
            $script:testAcl = New-TestAcl -OwnerSid 'S-1-5-32-545' -Rules $adminsFull, $systemFull, $usersRead

            $result = Test-ToolkitConfigTrust -Path 'C:\Fake'

            $result.IsTrusted | Should -BeFalse
            "$($result.Reasons)" | Should -BeLike '*owner*'
        }
    }

    It 'does not trust a folder that Users can <Rights>' -ForEach @(
        @{ Rights = 'Modify' }
        @{ Rights = 'CreateFiles' }
        @{ Rights = 'Delete' }
        @{ Rights = 'ChangePermissions' }
    ) {
        InModuleScope SysAdminToolkit -Parameters @{ Rights = $Rights } {
            param($Rights)
            $usersWrite = @{ Sid = 'S-1-5-32-545'; Rights = $Rights; Type = 'Allow' }
            $script:testAcl = New-TestAcl -OwnerSid 'S-1-5-32-544' -Rules $adminsFull, $usersWrite

            (Test-ToolkitConfigTrust -Path 'C:\Fake').IsTrusted | Should -BeFalse
        }
    }

    It 'ignores Deny entries and CREATOR OWNER entries' {
        InModuleScope SysAdminToolkit {
            $usersDeny = @{ Sid = 'S-1-5-32-545'; Rights = 'Modify'; Type = 'Deny' }
            $creatorOwner = @{ Sid = 'S-1-3-0'; Rights = 'FullControl'; Type = 'Allow' }
            $script:testAcl = New-TestAcl -OwnerSid 'S-1-5-32-544' -Rules $adminsFull, $usersDeny, $creatorOwner

            (Test-ToolkitConfigTrust -Path 'C:\Fake').IsTrusted | Should -BeTrue
        }
    }
}

Describe 'Protect-ToolkitConfigDirectory (needs an elevated session)' {
    It 'produces a folder and file that Test-ToolkitConfigTrust accepts' -Skip:(-not $script:isElevated) {
        InModuleScope SysAdminToolkit {
            $folder = Join-Path $TestDrive 'protect\Config'
            $null = New-Item -ItemType Directory -Path $folder -Force
            Set-Content -LiteralPath (Join-Path $folder 'config.psd1') -Value '@{}'

            Protect-ToolkitConfigDirectory -Path $folder -Confirm:$false

            (Test-ToolkitConfigTrust -Path $folder).IsTrusted | Should -BeTrue
            (Test-ToolkitConfigTrust -Path (Join-Path $folder 'config.psd1')).IsTrusted | Should -BeTrue
        }
    }
}

Describe 'Invoke-ToolkitMenu navigation' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            # Two-level test menu: Main -> Sub, plus actions that record that they ran.
            $script:actionLog = [System.Collections.Generic.List[string]]::new()
            Mock Get-ToolkitMenu {
                @{
                    Main = @{
                        Title = 'Main'
                        Items = @(
                            @{ Label = 'Open Sub'; Menu = 'Sub' }
                            @{ Label = 'Fail'; Action = { throw 'boom' } }
                            @{ Label = 'Record'; Action = { $script:actionLog.Add('ran') } }
                        )
                    }
                    Sub  = @{
                        Title = 'Sub'
                        Items = @(@{ Label = 'Record'; Action = { $script:actionLog.Add('sub') } })
                    }
                }
            }
            $script:titles = [System.Collections.Generic.List[string]]::new()
            $script:selections = [System.Collections.Generic.Queue[hashtable]]::new()
            Mock Show-Menu {
                $script:titles.Add($Title)
                $script:selections.Dequeue()
            }
            function script:New-Selection {
                param($Index, [switch]$Back, [switch]$Quit)
                @{ Quit = [bool]$Quit; Back = [bool]$Back; Choice = ''; Index = $Index }
            }
        }
    }

    It 'opens a submenu, returns on Back, and exits on Quit' {
        InModuleScope SysAdminToolkit {
            $script:selections.Enqueue((New-Selection -Index 0))
            $script:selections.Enqueue((New-Selection -Back))
            $script:selections.Enqueue((New-Selection -Quit))

            Invoke-ToolkitMenu -MenuName 'Main'

            $script:titles | Should -Be @('Main', 'Sub', 'Main')
        }
    }

    It 'shows the same menu again after invalid input (regression: submenus used to exit)' {
        InModuleScope SysAdminToolkit {
            $script:selections.Enqueue((New-Selection -Index $null))
            $script:selections.Enqueue((New-Selection -Quit))

            Invoke-ToolkitMenu -MenuName 'Main'

            $script:titles | Should -Be @('Main', 'Main')
        }
    }

    It 'keeps running after an action throws, and shows the menu again after an action' {
        InModuleScope SysAdminToolkit {
            $script:selections.Enqueue((New-Selection -Index 1))
            $script:selections.Enqueue((New-Selection -Index 2))
            $script:selections.Enqueue((New-Selection -Quit))

            Invoke-ToolkitMenu -MenuName 'Main' -ErrorVariable menuErrors -ErrorAction SilentlyContinue

            "$menuErrors" | Should -BeLike '*boom*'
            $script:actionLog | Should -Be @('ran')
            $script:titles | Should -Be @('Main', 'Main', 'Main')
        }
    }

    It 'quits from a submenu without returning to the parent' {
        InModuleScope SysAdminToolkit {
            $script:selections.Enqueue((New-Selection -Index 0))
            $script:selections.Enqueue((New-Selection -Quit))

            Invoke-ToolkitMenu -MenuName 'Main'

            $script:titles | Should -Be @('Main', 'Sub')
        }
    }

    It 'hides Back on the starting menu only when -NoBackAtRoot is used' {
        InModuleScope SysAdminToolkit {
            $script:selections.Enqueue((New-Selection -Index 0))
            $script:selections.Enqueue((New-Selection -Quit))

            Invoke-ToolkitMenu -MenuName 'Main' -NoBackAtRoot

            Should -Invoke Show-Menu -Times 1 -Exactly -ParameterFilter {
                $Title -eq 'Main' -and $BackOptions.Count -eq 0
            }
            Should -Invoke Show-Menu -Times 1 -Exactly -ParameterFilter {
                $Title -eq 'Sub' -and $BackOptions.Count -gt 0
            }
        }
    }
}

Describe 'Get-ToolkitMenu definitions' {
    It 'links only to menus that exist, and every action calls only commands that exist' {
        InModuleScope SysAdminToolkit {
            $menus = Get-ToolkitMenu
            $problems = foreach ($menuName in $menus.Keys) {
                foreach ($item in $menus[$menuName].Items) {
                    if ($item.ContainsKey('Menu')) {
                        if (-not $menus.ContainsKey($item.Menu)) {
                            "$menuName/$($item.Label): unknown menu '$($item.Menu)'"
                        }
                        continue
                    }
                    $commands = $item.Action.Ast.FindAll(
                        { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true
                    ) | ForEach-Object { $_.GetCommandName() }
                    foreach ($commandName in $commands) {
                        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
                            "$menuName/$($item.Label): command '$commandName' not found"
                        }
                    }
                }
            }
            $problems | Should -BeNullOrEmpty
        }
    }

    It 'can reach every menu from Main' {
        InModuleScope SysAdminToolkit {
            $menus = Get-ToolkitMenu
            $reached = [System.Collections.Generic.HashSet[string]]::new()
            $pending = [System.Collections.Generic.Queue[string]]::new()
            $pending.Enqueue('Main')
            while ($pending.Count -gt 0) {
                $name = $pending.Dequeue()
                if ($reached.Add($name)) {
                    $menus[$name].Items | Where-Object { $_.ContainsKey('Menu') } |
                        ForEach-Object { $pending.Enqueue($_.Menu) }
                }
            }
            @($menus.Keys | Where-Object { -not $reached.Contains($_) }) | Should -BeNullOrEmpty
        }
    }
}

Describe 'Function layout' {
    It 'defines each top-level function exactly once' {
        $root = Join-Path $PSScriptRoot '..'
        $files = Get-ChildItem -Path "$root/Private", "$root/Public" -Filter '*.ps1' -Recurse
        $parser = [System.Management.Automation.Language.Parser]
        $definitions = foreach ($file in $files) {
            $fileAst = $parser::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $fileAst.FindAll(
                { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false
            ) | ForEach-Object { $_.Name }
        }
        $definitions | Group-Object | Where-Object Count -GT 1 | Select-Object -ExpandProperty Name |
            Should -BeNullOrEmpty
    }

    It 'names every file after the single function it defines' {
        $root = Join-Path $PSScriptRoot '..'
        $parser = [System.Management.Automation.Language.Parser]
        $getFileParams = @{
            Path    = "$root/Private", "$root/Public"
            Filter  = "*.ps1"
            Recurse = $true
        }
        $mismatches = foreach ($file in Get-ChildItem @getFileParams) {
            $fileAst = $parser::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $names = @($fileAst.FindAll(
                    { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false
                ).Name)
            if ($names.Count -ne 1 -or $names[0] -cne $file.BaseName) {
                "$($file.Name): $($names -join ', ')"
            }
        }
        $mismatches | Should -BeNullOrEmpty
    }

    It 'keeps exactly the exported commands in Public/' {
        $root = Join-Path $PSScriptRoot '..'
        $publicNames = (Get-ChildItem -Path "$root/Public" -Filter '*.ps1' -Recurse).BaseName | Sort-Object
        $exported = (Import-PowerShellDataFile -Path $script:manifestPath).FunctionsToExport | Sort-Object
        $publicNames | Should -Be $exported
    }
}

Describe 'Invoke-ADSyncDeltaCycle (runs on the AD Connect server)' {
    BeforeAll {
        # ADSync cmdlets only exist on the AD Connect server; create stubs so they can be mocked.
        # The stubs declare the real parameter names: Mock copies the stub's parameters, so a -ParameterFilter
        # can only see parameters the stub declares (a catch-all stub hides -PolicyType from the filter).
        $script:adSyncStubs = @{
            'Get-ADSyncScheduler'   = { [CmdletBinding()] param() }
            'Start-ADSyncSyncCycle' = { [CmdletBinding()] param([string]$PolicyType) }
        }
        $script:adSyncCommands = @($script:adSyncStubs.Keys)
        foreach ($commandName in $script:adSyncCommands) {
            if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
                $null = New-Item -Path "function:global:$commandName" -Value $script:adSyncStubs[$commandName]
            }
        }
    }

    AfterAll {
        foreach ($commandName in $script:adSyncCommands) {
            $stub = Get-Item -Path "function:global:$commandName" -ErrorAction SilentlyContinue
            if ($stub -and -not $stub.Module) {
                Remove-Item -Path "function:global:$commandName"
            }
        }
    }

    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Import-Module { } -ParameterFilter { $Name -eq 'ADSync' }
            Mock Start-Sleep { }
            Mock Write-Progress { }
            Mock Start-ADSyncSyncCycle { }
            # Each call to Get-ADSyncScheduler returns the next value from this queue.
            $script:inProgress = [System.Collections.Generic.Queue[bool]]::new()
            Mock Get-ADSyncScheduler { [pscustomobject]@{ SyncCycleInProgress = $script:inProgress.Dequeue() } }
        }
    }

    It 'reports Completed after the cycle starts and then finishes' {
        InModuleScope SysAdminToolkit {
            # Not running before start, then running, running, finished.
            $false, $true, $true, $false | ForEach-Object { $script:inProgress.Enqueue($_) }

            $result = Invoke-ADSyncDeltaCycle -TimeoutSeconds 60 -PollSeconds 1

            $result.Status | Should -Be 'Completed'
            Should -Invoke Start-ADSyncSyncCycle -Times 1 -Exactly -ParameterFilter { $PolicyType -eq 'Delta' }
        }
    }

    It 'does not start a second cycle when one is already running' {
        InModuleScope SysAdminToolkit {
            $script:inProgress.Enqueue($true)

            $result = Invoke-ADSyncDeltaCycle

            $result.Status | Should -Be 'AlreadyRunning'
            Should -Invoke Start-ADSyncSyncCycle -Times 0 -Exactly
        }
    }

    It 'stops waiting for the start after StartTimeoutSeconds (regression: used to loop forever)' {
        InModuleScope SysAdminToolkit {
            1..10 | ForEach-Object { $script:inProgress.Enqueue($false) }

            $result = Invoke-ADSyncDeltaCycle -StartTimeoutSeconds 3 -PollSeconds 1

            $result.Status | Should -Be 'StartNotObserved'
            # One check before starting, then three start polls.
            Should -Invoke Get-ADSyncScheduler -Times 4 -Exactly
        }
    }

    It 'stops waiting for completion after TimeoutSeconds (regression: used to loop forever)' {
        InModuleScope SysAdminToolkit {
            $script:inProgress.Enqueue($false)
            1..20 | ForEach-Object { $script:inProgress.Enqueue($true) }

            $result = Invoke-ADSyncDeltaCycle -TimeoutSeconds 5 -PollSeconds 1

            $result.Status | Should -Be 'TimedOut'
            # One check before starting, one start poll, then five completion polls.
            Should -Invoke Get-ADSyncScheduler -Times 7 -Exactly
        }
    }

    It 'only calls built-in commands and ADSync cmdlets, so it can run remotely' {
        InModuleScope SysAdminToolkit {
            $allowedModules = 'Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Utility',
            'Microsoft.PowerShell.Management'
            $commandNames = ${function:Invoke-ADSyncDeltaCycle}.Ast.FindAll(
                { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true
            ) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique

            $notAllowed = foreach ($commandName in $commandNames) {
                if ($commandName -like '*-ADSync*') {
                    continue
                }
                # -CommandType Cmdlet looks past the mocks defined in BeforeEach to the real cmdlet.
                $command = Get-Command -Name $commandName -CommandType Cmdlet -ErrorAction SilentlyContinue
                if (-not $command -or $command.ModuleName -notin $allowedModules) {
                    $commandName
                }
            }
            $notAllowed | Should -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-ADSync' {
    BeforeEach {
        Mock -ModuleName SysAdminToolkit Show-MenuHeader { }
        Mock -ModuleName SysAdminToolkit Write-Host { }
        Mock -ModuleName SysAdminToolkit Read-Host { throw 'Read-Host must not be called' }
        Mock -ModuleName SysAdminToolkit Test-Connection { $true }
        Mock -ModuleName SysAdminToolkit Get-ToolkitConfig {
            @{ ADConnectServer = 'localhost'; ADSyncTimeoutSecs = 900 }
        }
    }

    It 'passes the configured timeout to the remote cycle' {
        Mock -ModuleName SysAdminToolkit Invoke-Command {
            [pscustomobject]@{ Status = 'Completed'; ElapsedSeconds = 5 }
        }

        Invoke-ADSync

        Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 1 -Exactly -ParameterFilter {
            $ArgumentList[0] -eq 900
        }
    }

    It 'lets -TimeoutSeconds override the configuration' {
        Mock -ModuleName SysAdminToolkit Invoke-Command {
            [pscustomobject]@{ Status = 'Completed'; ElapsedSeconds = 5 }
        }

        Invoke-ADSync -TimeoutSeconds 60

        Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 1 -Exactly -ParameterFilter {
            $ArgumentList[0] -eq 60
        }
    }

    It 'writes an error when the cycle times out' {
        Mock -ModuleName SysAdminToolkit Invoke-Command {
            [pscustomobject]@{ Status = 'TimedOut'; ElapsedSeconds = 900 }
        }

        Invoke-ADSync -ErrorVariable syncErrors -ErrorAction SilentlyContinue

        "$syncErrors" | Should -BeLike '*still running after 900s*'
    }

    It 'warns instead of failing when a cycle is already running' {
        Mock -ModuleName SysAdminToolkit Invoke-Command {
            [pscustomobject]@{ Status = 'AlreadyRunning'; ElapsedSeconds = 0 }
        }

        Invoke-ADSync -WarningVariable syncWarnings -WarningAction SilentlyContinue -ErrorVariable syncErrors

        "$syncWarnings" | Should -BeLike '*already running*'
        $syncErrors | Should -BeNullOrEmpty
    }

    It 'starts nothing with -WhatIf' {
        Mock -ModuleName SysAdminToolkit Invoke-Command { }

        Invoke-ADSync -WhatIf

        Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 0 -Exactly
    }
}
