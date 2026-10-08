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
            'Get-ADDisabledUsers', 'Get-BatteryReport', 'Get-RDConnectedUsers', 'Invoke-ADAccountDisable',
            'Invoke-ADAccountUnlock', 'Invoke-ADPasswordReset', 'Invoke-ADSync', 'Open-PrinterWebInterface',
            'Restart-RDSBroker', 'Set-RDSessionHostMode', 'Show-ReachabilityMenu', 'Start-ToolkitMenu',
            'Stop-FileLock', 'Test-ComputerReachability'
        ) | Sort-Object
        $actual = (Get-Command -Module SysAdminToolkit).Name | Sort-Object
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
                Should -be @('127.255.255.255', '128.0.0.0', '128.0.0.1')
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

Describe 'Initialize-ToolkitConfig' {
    It 'reports a corrupt config file clearly and does not overwrite it' {
        InModuleScope SysAdminToolkit {
            $originalPath = $script:ConfigPath
            try {
                $script:ConfigPath = Join-Path $TestDrive 'config.psd1'
                Set-Content -LiteralPath $script:ConfigPath -Value 'not a hashtable'

                { Initialize-ToolkitConfig } | Should -Throw '*is not a valid .psd1 file*'

                Get-Content -LiteralPath $script:ConfigPath -Raw | Should -BeLike 'not a hashtable*'
            } finally {
                $script:ConfigPath = $originalPath
            }
        }
    }

    It 'creates the file from defaults when it does not exist' {
        InModuleScope SysAdminToolkit {
            $originalPath = $script:ConfigPath
            $originalConfig = $script:ToolkitConfig
            try {
                $script:ConfigPath = Join-Path $TestDrive 'new\config.psd1'

                Initialize-ToolkitConfig

                $defaults = Import-PowerShellDataFile -LiteralPath $script:DefaultConfigPath
                $loaded = Import-PowerShellDataFile -LiteralPath $script:ConfigPath
                $loaded.Keys.Count | Should -Be $defaults.Keys.Count
                $loaded.RDMaxRetries | Should -Be $defaults.RDMaxRetries
            } finally {
                $script:ConfigPath = $originalPath
                $script:ToolkitConfig = $originalConfig
            }
        }
    }

    It 'does not rewrite an existing complete config file' {
        InModuleScope SysAdminToolkit {
            $originalPath = $script:ConfigPath
            $originalConfig = $script:ToolkitConfig
            try {
                $script:ConfigPath = Join-Path $TestDrive 'existing\config.psd1'
                Initialize-ToolkitConfig
                $before = (Get-Item -LiteralPath $script:ConfigPath).LastWriteTimeUtc
                Start-Sleep -Milliseconds 50

                Initialize-ToolkitConfig

                (Get-Item -LiteralPath $script:ConfigPath).LastWriteTimeUtc | Should -Be $before
            } finally {
                $script:ConfigPath = $originalPath
                $script:ToolkitConfig = $originalConfig
            }
        }
    }
}

Describe 'Save-ToolkitConfig' {
    It 'round-trips quotes (including typographic quotes) and integers' {
        InModuleScope SysAdminToolkit {
            $originalPath = $script:ConfigPath
            $originalConfig = $script:ToolkitConfig
            try {
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
            } finally {
                $script:ConfigPath = $originalPath
                $script:ToolkitConfig = $originalConfig
            }
        }
    }

    It 'does not update in-memory configuration when the write fails' {
        InModuleScope SysAdminToolkit {
            $originalPath = $script:ConfigPath
            $originalConfig = $script:ToolkitConfig
            try {
                $script:ConfigPath = Join-Path $TestDrive 'missing-dir\config.psd1'
                { Save-ToolkitConfig -Config @{ PrintServer = 'new' } } | Should -Throw
                [object]::ReferenceEquals($script:ToolkitConfig, $originalConfig) | Should -BeTrue
            } finally {
                $script:ConfigPath = $originalPath
                $script:ToolkitConfig = $originalConfig
            }
        }
    }
}
