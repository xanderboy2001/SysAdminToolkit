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

    $manifestData = Import-PowerShellDataFile -Path (
        Join-Path -Path $PSScriptRoot -ChildPath '..', 'SysAdminToolkit.psd1'
    )
    $script:publicCommands = @($manifestData.FunctionsToExport)

    # Optional, never committed: one organisation-specific term per line (company name, internal domain, server
    # names). When present, a test fails if any tracked file contains one of them. See .gitignore.
    $script:forbiddenTermsPath = Join-Path -Path $PSScriptRoot -ChildPath 'LocalForbiddenTerms.txt'
    $script:hasForbiddenTerms = Test-Path -LiteralPath $script:forbiddenTermsPath
}

BeforeAll {
    $script:moduleRoot = Join-Path $PSscriptRoot '..'
    $script:manifestPath = Join-Path $script:moduleRoot 'SysAdminToolkit.psd1'

    # RemoteDesktop cmdlets are mocked; create stubs when the RemoteDesktop module is not installed (e.g. CI).
    $script:rdCommands = @(
        'Get-RDServer', 'Get-RDConnectionBrokerHighAvailability', 'Set-RDActiveManagementServer',
        'Get-RDSessionCollection', 'Get-RDSessionHost', 'Set-RDSessionHost', 'Get-RDUserSession'
    )
    # Stubs that tests filter on declare the real parameter names: a Pester mock copies the stub's parameters,
    # so a -ParameterFilter cannot see parameters that a catch-all stub hides.
    $namedStubs = @{
        'Get-RDUserSession' = { [CmdletBinding()] param([string]$ConnectionBroker, [string[]]$CollectionName) }
    }
    foreach ($commandName in $script:rdCommands) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            $stubBody = $namedStubs[$commandName] ?? {
                param([Parameter(ValueFromRemainingArguments)]$RemainingArguments)
            }
            $null = New-Item -Path "function:global:$commandName" -Value $stubBody
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

    It '<_> has a description, an example, and documented parameters' -ForEach $script:publicCommands {
        $commandName = $_
        $help = Get-Help -Name $commandName -Full

        "$($help.description.Text)".Trim() | Should -Not -BeNullOrEmpty -Because 'Get-Help needs a .DESCRIPTION'
        @($help.examples.example).Count | Should -BeGreaterThan 0 -Because 'Get-Help needs an .EXAMPLE'

        $commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters +
        [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $parameterNames = (Get-Command -Name $commandName).Parameters.Keys |
            Where-Object { $_ -notin $commonParameters }
        $undocumented = foreach ($parameterName in $parameterNames) {
            $parameterHelp = $help.parameters.parameter | Where-Object name -EQ $parameterName
            if (-not $parameterHelp -or -not "$($parameterHelp.description.Text)".Trim()) {
                $parameterName
            }
        }
        $undocumented | Should -BeNullOrEmpty -Because 'every parameter needs a .PARAMETER entry'
    }

    It 'has a CHANGELOG entry for the manifest version' {
        $version = (Import-PowerShellDataFile -Path $script:manifestPath).ModuleVersion
        $changelog = Join-Path $script:moduleRoot 'CHANGELOG.md'
        $newest = Select-String -LiteralPath $changelog -Pattern '^## \[(\d+\.\d+\.\d+)\]' |
            Select-Object -First 1
        $newest.Matches[0].Groups[1].Value | Should -Be $version
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
            { Expand-NameRange -StartName 'PC-1' -EndName 'LT-2' } | Should -Throw '*Prefixes must match*'
        }
    }

    It 'rejects ranges larger than 5001 names' {
        InModuleScope SysAdminToolkit {
            { Expand-NameRange -StartName 'PC-1' -EndName 'PC-9000' } | Should -Throw '*too large*'
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
        Mock -ModuleName SysAdminToolkit Resolve-ToolkitHost { $Name }
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
        Mock -ModuleName SysAdminToolkit Confirm-ConnectionBroker { 'B1.CONTOSO.TEST' }
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

        { Restart-RDSBroker -BrokerServer 'localhost' -Force } | Should -Throw '*Only one Connection Broker*'

        Should -Invoke -ModuleName SysAdminToolkit Restart-ServerAndWait -Times 0 -Exactly
    }

    It 'refuses to run when the active broker is not in the broker list' {
        Mock -ModuleName SysAdminToolkit Get-RDServer {
            [pscustomobject]@{ Server = 'B2.CONTOSO.TEST' }
            [pscustomobject]@{ Server = 'B3.CONTOSO.TEST' }
        }

        { Restart-RDSBroker -BrokerServer 'localhost' -Force } | Should -Throw '*not in the broker list*'

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

    It 'stops after a failed switch, does not reboot the active broker, and reports the state' {
        Mock -ModuleName SysAdminToolkit Get-RDServer {
            [pscustomobject]@{ Server = 'B1.CONTOSO.TEST' }
            [pscustomobject]@{ Server = 'B2.CONTOSO.TEST' }
        }
        Mock -ModuleName SysAdminToolkit Switch-ActiveBroker { throw 'switch failed' }

        $failure = { Restart-RDSBroker -BrokerServer 'localhost' -Force } | Should -Throw -PassThru

        $failure.Exception.Message | Should -BeLike "*step 'make B2.CONTOSO.TEST the active broker'*"
        $failure.Exception.Message | Should -BeLike '*switch failed*'
        $failure.Exception.Message | Should -BeLike '*Completed before the failure: rebooted B2.CONTOSO.TEST.*'
        $failure.Exception.Message | Should -BeLike '*Current active broker: B1.CONTOSO.TEST*'
        Should -Invoke -ModuleName SysAdminToolkit Restart-ServerAndWait -Times 1 -Exactly -ParameterFilter {
            $ComputerName -eq 'B2.CONTOSO.TEST'
        }
        Should -Invoke -ModuleName SysAdminToolkit Restart-ServerAndWait -Times 0 -Exactly -ParameterFilter {
            $ComputerName -eq 'B1.CONTOSO.TEST'
        }
    }
}

Describe 'Wait-RDMService' {
    BeforeAll {
        # Shorthand so each test does not repeat the target name.
        function script:Wait-RDMServiceTest {
            param([int]$MaxRetries)
            InModuleScope SysAdminToolkit -Parameters @{ MaxRetries = $MaxRetries } {
                param($MaxRetries)
                Wait-RDMService -ComputerName 'B1.CONTOSO.TEST' -MaxRetries $MaxRetries
            }
        }
    }

    BeforeEach {
        Mock -ModuleName SysAdminToolkit Start-Sleep { }
        Mock -ModuleName SysAdminToolkit Write-Information { }
        Mock -ModuleName SysAdminToolkit Write-Warning { }
    }

    It 'returns as soon as all three services report Running' {
        Mock -ModuleName SysAdminToolkit Invoke-Command {
            'rdms', 'tssdis', 'tscpubrpc' | ForEach-Object { [pscustomobject]@{ Name = $_; Status = 'Running' } }
        }

        { Wait-RDMServiceTest -MaxRetries 5 } | Should -Not -Throw

        Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 1 -Exactly
    }

    It 'checks exactly MaxRetries times, then throws (regression: used to check MaxRetries + 1 times)' {
        Mock -ModuleName SysAdminToolkit Invoke-Command {
            [pscustomobject]@{ Name = 'rdms'; Status = 'Running' }
            [pscustomobject]@{ Name = 'tssdis'; Status = 'StartPending' }
            [pscustomobject]@{ Name = 'tscpubrpc'; Status = 'Running' }
        }

        { Wait-RDMServiceTest -MaxRetries 3 } | Should -Throw '*after 3 checks*tssdis is StartPending*'

        Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 3 -Exactly
    }

    It 'treats a missing service as not running' {
        Mock -ModuleName SysAdminToolkit Invoke-Command {
            [pscustomobject]@{ Name = 'rdms'; Status = 'Running' }
            [pscustomobject]@{ Name = 'tssdis'; Status = 'NotFound' }
            [pscustomobject]@{ Name = 'tscpubrpc'; Status = 'Running' }
        }

        { Wait-RDMServiceTest -MaxRetries 1 } | Should -Throw '*tssdis is NotFound*'
    }

    It 'runs the status check on the target and compares status as text (regression: enum vs 4)' {
        InModuleScope SysAdminToolkit {
            Mock Start-Sleep { }
            # Run the remote script block locally, against mocked services with real enum values.
            Mock Invoke-Command { & $ScriptBlock @ArgumentList }
            Mock Get-Service {
                $running = [System.ServiceProcess.ServiceControllerStatus]::Running
                [pscustomobject]@{ Name = $Name; Status = $running }
            }

            { Wait-RDMService -ComputerName 'B1.CONTOSO.TEST' -MaxRetries 1 } | Should -Not -Throw

            Should -Invoke Get-Service -Times 3 -Exactly
        }
    }
}

Describe 'Switch-ActiveBroker' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Start-Sleep { }
            Mock Write-Information { }
            Mock Set-RDActiveManagementServer { }
            $script:reportedActive = [System.Collections.Generic.Queue[string]]::new()
            Mock Get-ActiveBroker { $script:reportedActive.Dequeue() }
            $script:switchParams = @{
                ActiveBroker    = 'B1.CONTOSO.TEST'
                NewActiveBroker = 'b2.contoso.test'
                BrokerServers   = @('B1.CONTOSO.TEST', 'b2.contoso.test')
                TimeoutSeconds  = 30
                PollSeconds     = 10
            }
        }
    }

    It 'polls until the new broker is reported active, ignoring case (regression: single check after 10s)' {
        InModuleScope SysAdminToolkit {
            'B1.CONTOSO.TEST', 'B2.CONTOSO.TEST' | ForEach-Object { $script:reportedActive.Enqueue($_) }

            { Switch-ActiveBroker @switchParams } | Should -Not -Throw

            Should -Invoke Get-ActiveBroker -Times 2 -Exactly
        }
    }

    It 'throws after TimeoutSeconds and reports the last active broker' {
        InModuleScope SysAdminToolkit {
            1..10 | ForEach-Object { $script:reportedActive.Enqueue('B1.CONTOSO.TEST') }

            { Switch-ActiveBroker @switchParams } | Should -Throw '*within 30s*last reported: B1.CONTOSO.TEST*'

            Should -Invoke Get-ActiveBroker -Times 3 -Exactly
        }
    }

    It 'throws without polling when Set-RDActiveManagementServer fails' {
        InModuleScope SysAdminToolkit {
            Mock Set-RDActiveManagementServer { throw 'access denied' }

            { Switch-ActiveBroker @switchParams } |
                Should -Throw '*Set-RDActiveManagementServer failed*access denied*'

            Should -Invoke Get-ActiveBroker -Times 0 -Exactly
        }
    }
}

Describe 'Restart-ServerAndWait' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Write-Information { }
            Mock Start-Sleep { }
            Mock Resolve-ToolkitHost { $Name }
            # Fake host names only: if a mock ever failed, nothing real could be rebooted.
            Mock Restart-Computer { }
            Mock Wait-RDMService { }
        }
    }

    It 'does not reboot a server that does not accept PowerShell remoting' {
        InModuleScope SysAdminToolkit {
            Mock Resolve-ToolkitHost { throw 'WinRM is not available for test' }

            { Restart-ServerAndWait -ComputerName 'B2.CONTOSO.TEST' -TimeoutSecs 60 -MaxRetries 1 } |
                Should -Throw '*not reachable*not rebooted*'

            Should -Invoke Restart-Computer -Times 0 -Exactly
        }
    }

    It 'names the server and the failed step when the services do not start' {
        InModuleScope SysAdminToolkit {
            Mock Wait-RDMService { throw 'services did not start' }

            { Restart-ServerAndWait -ComputerName 'B2.CONTOSO.TEST' -TimeoutSecs 60 -MaxRetries 1 } |
                Should -Throw "*B2.CONTOSO.TEST failed during step 'wait for RDS services'*services did not start*"

            Should -Invoke Restart-Computer -Times 1 -Exactly
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
        Mock -ModuleName SysAdminToolkit Resolve-ToolkitHost { 'ADCONNECT.CONTOSO.TEST' }
        Mock -ModuleName SysAdminToolkit Get-ToolkitConfig {
            @{ ADConnectServer = 'adconnect'; ADSyncTimeoutSecs = 900 }
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

Describe 'Get-BatteryReport' {
    Context 'Report parsing (remote script block run locally)' {
        BeforeAll {
            $script:batteryXml = {
                param([string]$Batteries)
                '<?xml version="1.0"?><BatteryReport xmlns="http://schemas.microsoft.com/battery/2012">' +
                "<Batteries>$Batteries</Batteries></BatteryReport>"
            }
        }

        BeforeEach {
            # powercfg.exe is replaced by a global FUNCTION with the same name: PowerShell finds functions before
            # programs, including from inside the module. A Pester mock of the .exe is not used because it fails
            # under the module's Set-StrictMode. The stub writes $fixture.Xml to the /output path, records the
            # path, and sets the exit code.
            $script:fixture = @{ Xml = ''; ExitCode = 0; ReportPath = $null }
            $fixture = $script:fixture
            $stub = {
                $fixture.ReportPath = $args[3]
                Set-Content -LiteralPath $args[3] -Value $fixture.Xml
                $global:LASTEXITCODE = $fixture.ExitCode
            }.GetNewClosure()
            $null = New-Item -Path 'function:global:powercfg.exe' -Value $stub -Force

            # Runs the remote script block in this session instead of on a remote computer.
            Mock -ModuleName SysAdminToolkit Invoke-Command { & $ScriptBlock }
            Mock -ModuleName SysAdminToolkit Read-Host { throw 'Read-Host must not be called' }
        }

        AfterEach {
            Remove-Item -Path 'function:global:powercfg.exe' -ErrorAction SilentlyContinue
        }

        It 'returns one object per battery (regression: two batteries used to fail)' {
            $script:fixture.Xml = & $script:batteryXml (
                '<Battery><Id>Internal</Id><DesignCapacity>50000</DesignCapacity>' +
                '<FullChargeCapacity>40000</FullChargeCapacity><CycleCount>120</CycleCount></Battery>' +
                '<Battery><Id>External</Id><DesignCapacity>24000</DesignCapacity>' +
                '<FullChargeCapacity>23000</FullChargeCapacity><CycleCount>30</CycleCount></Battery>'
            )

            $result = @(Get-BatteryReport -ComputerName 'PC1')

            $result.Count | Should -Be 2
            $result[0].BatteryId | Should -Be 'Internal'
            $result[0].CapacityPercent | Should -Be 80
            $result[0].CycleCount | Should -Be 120
            $result[1].CapacityPercent | Should -Be 95.8
            $result.Status | Should -Be @('OK', 'OK')
        }

        It 'reports NoBattery for a computer without a battery' {
            $script:fixture.Xml = & $script:batteryXml ''

            $result = @(Get-BatteryReport -ComputerName 'PC1')

            $result.Count | Should -Be 1
            $result[0].Status | Should -Be 'NoBattery'
        }

        It 'uses a unique temp file and deletes it even when the report cannot be read' {
            $script:fixture.Xml = 'this is not xml'

            { Get-BatteryReport -ComputerName 'PC1' -ErrorAction Stop } | Should -Throw

            $script:fixture.ReportPath | Should -BeLike '*batteryreport-*.xml'
            Test-Path -LiteralPath $script:fixture.ReportPath | Should -BeFalse
        }

        It 'fails when powercfg returns a non-zero exit code' {
            $script:fixture.Xml = & $script:batteryXml ''
            $script:fixture.ExitCode = 1

            { Get-BatteryReport -ComputerName 'PC1' -ErrorAction Stop } | Should -Throw '*exit code 1*'
        }

        It 'only calls built-in commands and powercfg.exe, so it can run remotely' {
            InModuleScope SysAdminToolkit {
                $script:capturedBlock = $null
                Mock Invoke-Command { $script:capturedBlock = $ScriptBlock }

                Get-BatteryReport -ComputerName 'PC1'

                $allowedModules = 'Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Utility',
                'Microsoft.PowerShell.Management'
                $commandNames = $script:capturedBlock.Ast.FindAll(
                    { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true
                ) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique

                $notAllowed = foreach ($commandName in $commandNames) {
                    if ($commandName -eq 'powercfg.exe') {
                        continue
                    }
                    $command = Get-Command -Name $commandName -CommandType Cmdlet -ErrorAction SilentlyContinue
                    if (-not $command -or $command.ModuleName -notin $allowedModules) {
                        $commandName
                    }
                }
                $notAllowed | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Targets and errors' {
        BeforeEach {
            Mock -ModuleName SysAdminToolkit Read-Host { throw 'Read-Host must not be called' }
        }

        It 'reports errors per computer instead of hiding them (regression: SilentlyContinue)' {
            Mock -ModuleName SysAdminToolkit Invoke-Command {
                [pscustomobject]@{ ComputerName = 'PC1'; BatteryId = 'A'; Status = 'OK' }
                # -ErrorAction Continue: keep this a non-terminating error whatever the test's preference is,
                # as it would be when one computer out of several fails.
                $errorParams = @{
                    Message      = 'WinRM cannot complete the operation'
                    TargetObject = 'PC2'
                    ErrorAction  = 'Continue'
                }
                Write-Error @errorParams
            }

            $result = @(Get-BatteryReport -ComputerName 'PC1', 'PC2' -ErrorVariable batteryErrors `
                    -ErrorAction SilentlyContinue)

            $result.Count | Should -Be 1
            $result[0].ComputerName | Should -Be 'PC1'
            "$batteryErrors" | Should -BeLike '*failed on PC2*WinRM cannot complete*'
        }

        It 'accepts pipeline input, removes duplicates, and queries all computers in one call' {
            Mock -ModuleName SysAdminToolkit Invoke-Command { }

            'PC1', 'pc1', 'PC2' | Get-BatteryReport

            Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 1 -Exactly -ParameterFilter {
                $ComputerName.Count -eq 2
            }
        }

        It 'accepts objects with a DNSHostName property, such as Get-ADComputer output' {
            Mock -ModuleName SysAdminToolkit Invoke-Command { }

            [pscustomobject]@{ DNSHostName = 'pc1.contoso.test' } | Get-BatteryReport

            Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 1 -Exactly -ParameterFilter {
                $ComputerName -contains 'pc1.contoso.test'
            }
        }

        It 'prompts for a comma-separated list when no computer is given' {
            Mock -ModuleName SysAdminToolkit Read-Host { 'PC1, PC2,' }
            Mock -ModuleName SysAdminToolkit Invoke-Command { }

            Get-BatteryReport

            Should -Invoke -ModuleName SysAdminToolkit Invoke-Command -Times 1 -Exactly -ParameterFilter {
                ($ComputerName -join ',') -eq 'PC1,PC2'
            }
        }
    }
}

Describe 'Public-repository hygiene' {
    It 'does not ship organisation-specific defaults' {
        $defaults = Import-PowerShellDataFile -Path (Join-Path $script:moduleRoot 'Config/config.defaults.psd1')
        $defaults.ADConnectServer | Should -BeNullOrEmpty
        $defaults.RDBrokerServer | Should -BeNullOrEmpty
    }

    It 'contains none of the terms in Tests/LocalForbiddenTerms.txt' -Skip:(-not $script:hasForbiddenTerms) {
        # Variables set in BeforeDiscovery only exist during discovery (for -Skip and -ForEach), not here.
        $termsPath = Join-Path -Path $PSScriptRoot -ChildPath 'LocalForbiddenTerms.txt'
        $terms = @(Get-Content -LiteralPath $termsPath | ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and -not $_.StartsWith('#') })
        $files = @(git -C $script:moduleRoot ls-files) |
            Where-Object { $_ -notlike '*.png' -and $_ -notlike '*.ico' } |
            ForEach-Object { Join-Path $script:moduleRoot $_ }

        $hits = foreach ($term in $terms) {
            Select-String -LiteralPath $files -Pattern $term -SimpleMatch |
                ForEach-Object { '{0}:{1}: {2}' -f $_.Path, $_.LineNumber, $term }
        }
        $hits | Should -BeNullOrEmpty
    }
}

Describe 'Get-ToolkitMenu after removing Troubleshooting (F-12)' {
    It 'has no Troubleshooting menu and no placeholder items' {
        InModuleScope SysAdminToolkit {
            $menus = Get-ToolkitMenu
            $menus.ContainsKey('Troubleshooting') | Should -BeFalse
            $menus.Server.Items.Label | Should -Not -Contain 'Troubleshooting'
        }
    }
}

Describe 'Test-ADDistinguishedName' {
    It 'accepts <_>' -ForEach @(
        'OU=Disabled,DC=contoso,DC=com'
        'OU=Disabled,OU=Users,DC=corp,DC=contoso,DC=com'
        'CN=Users,DC=contoso,DC=com'
        'OU=Smith\, John,DC=contoso,DC=com'
        'OU=Leavers [2025],DC=contoso,DC=com'
    ) {
        InModuleScope SysAdminToolkit -Parameters @{ Dn = $_ } {
            param($Dn)
            Test-ADDistinguishedName -DistinguishedName $Dn | Should -BeTrue
        }
    }

    It 'rejects <_>' -ForEach @('', 'Disabled', 'DC=contoso,DC=com', 'OU=Disabled', 'OU=Disabled,DC=') {
        InModuleScope SysAdminToolkit -Parameters @{ Dn = $_ } {
            param($Dn)
            Test-ADDistinguishedName -DistinguishedName $Dn | Should -BeFalse
        }
    }
}

Describe 'Get-ADDisabledUser (F-24)' {
    BeforeEach {
        Mock -ModuleName SysAdminToolkit Read-Host { throw 'Read-Host must not be called' }
        Mock -ModuleName SysAdminToolkit Get-ADUser {
            $domain = 'DC=contoso,DC=test'
            [pscustomobject]@{ SamAccountName = 'a'; DistinguishedName = "CN=A,OU=Leavers [2025],$domain" }
            [pscustomobject]@{ SamAccountName = 'b'; DistinguishedName = "CN=B,OU=Leavers 2,$domain" }
            [pscustomobject]@{ SamAccountName = 'c'; DistinguishedName = "CN=C,OU=Sub,OU=Old,$domain" }
            [pscustomobject]@{ SamAccountName = 'd'; DistinguishedName = "CN=D,OU=Staff,$domain" }
        }
    }

    It 'matches OU names literally, so [ ] are not wildcards (regression: -like)' {
        $result = Get-ADDisabledUser -Exclusions 'OU=Leavers [2025],DC=contoso,DC=test'

        $result.SamAccountName | Should -Be @('b', 'c', 'd')
    }

    It 'also leaves out accounts in sub-OUs of an excluded OU' {
        $result = Get-ADDisabledUser -Exclusions 'OU=Old,DC=contoso,DC=test'

        $result.SamAccountName | Should -Not -Contain 'c'
    }

    It 'returns every disabled account with -NoExclusion and does not prompt' {
        $result = Get-ADDisabledUser -NoExclusion

        $result.Count | Should -Be 4
    }

    It 'rejects an exclusion that is not a distinguished name' {
        { Get-ADDisabledUser -Exclusions 'Disabled' } | Should -Throw '*Not a valid OU*'

        Should -Invoke -ModuleName SysAdminToolkit Get-ADUser -Times 0 -Exactly
    }

    It 'treats an empty answer at the prompt as no exclusions' {
        Mock -ModuleName SysAdminToolkit Read-Host { '' }
        Mock -ModuleName SysAdminToolkit Write-Host { }

        (Get-ADDisabledUser).Count | Should -Be 4
    }
}

Describe 'Read-Password (F-28)' {
    BeforeAll {
        function script:New-TestSecureString {
            # Builds a SecureString without ConvertTo-SecureString -AsPlainText.
            param([string]$Text)
            $secure = [System.Security.SecureString]::new()
            foreach ($character in $Text.ToCharArray()) {
                $secure.AppendChar($character)
            }
            $secure
        }
    }

    It 'rejects an empty password, then re-prompts until both entries match' {
        $answers = [System.Collections.Generic.Queue[securestring]]::new()
        '', '', 'abc1', 'abc2', 'abc1', 'abc1' | ForEach-Object { $answers.Enqueue((New-TestSecureString $_)) }
        InModuleScope SysAdminToolkit -Parameters @{ Answers = $answers } {
            param($Answers)
            $script:answers = $Answers
            Mock Write-Host { }
            Mock Read-Host { $script:answers.Dequeue() }

            $result = Read-Password

            $result.Length | Should -Be 4
            Should -Invoke Read-Host -Times 6 -Exactly
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -like '*cannot be empty*' }
        }
    }
}

Describe 'AD account commands use one standard confirmation (F-10)' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Show-MenuHeader { }
            Mock Write-Host { }
            Mock Confirm-UserChoice { throw 'Confirm-UserChoice must not be called' }
            Mock Get-ValidADUser { [pscustomobject]@{ SamAccountName = 'jdoe'; Name = 'John Doe' } }
            Mock Get-ADUser { [pscustomobject]@{ SamAccountName = 'jdoe'; LockedOut = $true; Enabled = $true } }
            Mock Read-Password { [System.Security.SecureString]::new() }
            Mock Set-ADAccountPassword { }
            Mock Unlock-ADAccount { }
            Mock Disable-ADAccount { }
        }
    }

    It 'Invoke-ADPasswordReset -WhatIf asks for no password and changes nothing' {
        InModuleScope SysAdminToolkit {
            Invoke-ADPasswordReset -WhatIf

            Should -Invoke Read-Password -Times 0 -Exactly
            Should -Invoke Set-ADAccountPassword -Times 0 -Exactly
        }
    }

    It 'Invoke-ADPasswordReset -Force resets without a second confirmation' {
        InModuleScope SysAdminToolkit {
            Invoke-ADPasswordReset -Force -ErrorVariable resetErrors

            $resetErrors | Should -BeNullOrEmpty
            # No parameter filter: with the real ActiveDirectory module, -Identity is bound as an ADAccount
            # object, which does not compare equal to the string 'jdoe'.
            Should -Invoke Set-ADAccountPassword -Times 1 -Exactly
        }
    }

    It 'Invoke-ADAccountUnlock -WhatIf changes nothing, and -Force unlocks' {
        InModuleScope SysAdminToolkit {
            Invoke-ADAccountUnlock -Identity 'jdoe' -WhatIf
            Should -Invoke Unlock-ADAccount -Times 0 -Exactly

            $null = Invoke-ADAccountUnlock -Identity 'jdoe' -Force
            Should -Invoke Unlock-ADAccount -Times 1 -Exactly
        }
    }

    It 'Invoke-ADAccountDisable -Force disables without prompting' {
        InModuleScope SysAdminToolkit {
            $null = Invoke-ADAccountDisable -Identity 'jdoe' -Force

            Should -Invoke Disable-ADAccount -Times 1 -Exactly
        }
    }
}

Describe 'Set-RDSessionHostMode uses the active broker (F-05)' {
    It 'queries collections from the active broker, not the broker that was named' {
        InModuleScope SysAdminToolkit {
            Mock Write-Host { }
            Mock Confirm-ConnectionBroker { 'B1.CONTOSO.TEST' }
            Mock Get-ActiveBroker { 'B2.CONTOSO.TEST' }
            Mock Get-RDSessionCollection { throw 'stop here' }

            { Set-RDSessionHostMode -ConnectionBroker 'b1' } | Should -Throw '*stop here*'

            Should -Invoke Get-ActiveBroker -Times 1 -Exactly -ParameterFilter {
                $BrokerServers -contains 'B1.CONTOSO.TEST'
            }
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                "$Object" -like '*active Connection Broker B2.CONTOSO.TEST*'
            }
        }
    }
}

Describe 'Resolve-ToolkitHost (F-16)' {
    It 'resolves a name in DNS without checking WinRM by default' {
        InModuleScope SysAdminToolkit {
            Mock Test-WSMan { throw 'must not be called' }

            Resolve-ToolkitHost -Name 'localhost' | Should -Not -BeNullOrEmpty

            Should -Invoke Test-WSMan -Times 0 -Exactly
        }
    }

    It 'returns an IP address unchanged' {
        InModuleScope SysAdminToolkit {
            Resolve-ToolkitHost -Name ' 10.0.0.5 ' | Should -Be '10.0.0.5'
        }
    }

    It 'throws HostNotResolved with the DNS exception kept as the inner exception' {
        InModuleScope SysAdminToolkit {
            # The .invalid top-level domain never resolves (RFC 2606).
            $failure = { Resolve-ToolkitHost -Name 'no-such-host.invalid' } | Should -Throw -PassThru

            $failure.FullyQualifiedErrorId | Should -BeLike 'SysAdminToolkit.HostNotResolved*'
            $failure.Exception.Message | Should -BeLike "*Could not resolve 'no-such-host.invalid'*"
            $failure.Exception.InnerException | Should -Not -BeNullOrEmpty
        }
    }

    It 'checks WinRM against the resolved name with -RequireWinRM' {
        InModuleScope SysAdminToolkit {
            Mock Test-WSMan { }

            $resolved = Resolve-ToolkitHost -Name '10.0.0.5' -RequireWinRM

            $resolved | Should -Be '10.0.0.5'
            Should -Invoke Test-WSMan -Times 1 -Exactly -ParameterFilter { $ComputerName -eq '10.0.0.5' }
        }
    }

    It 'throws WinRMUnavailable with the WinRM exception kept as the inner exception' {
        InModuleScope SysAdminToolkit {
            Mock Test-WSMan { throw [System.TimeoutException]::new('WinRM timed out') }

            $failure = { Resolve-ToolkitHost -Name '10.0.0.5' -RequireWinRM } | Should -Throw -PassThru

            $failure.FullyQualifiedErrorId | Should -BeLike 'SysAdminToolkit.WinRMUnavailable*'
            $failure.Exception.Message | Should -BeLike '*WinRM timed out*'
            $failure.Exception.InnerException | Should -BeOfType [System.TimeoutException]
        }
    }
}

Describe 'Errors keep the original exception (F-20)' {
    It 'Restart-RDSBroker keeps the Get-RDServer exception when listing brokers fails' {
        Mock -ModuleName SysAdminToolkit Get-ToolkitConfig { @{ RDTimeoutSecs = 600; RDMaxRetries = 15 } }
        Mock -ModuleName SysAdminToolkit Write-Host { }
        Mock -ModuleName SysAdminToolkit Confirm-ConnectionBroker { 'B1.CONTOSO.TEST' }
        Mock -ModuleName SysAdminToolkit Restart-ServerAndWait { }
        Mock -ModuleName SysAdminToolkit Get-RDServer { throw [System.TimeoutException]::new('RPC timed out') }

        $failure = { Restart-RDSBroker -BrokerServer 'b1' -Force } | Should -Throw -PassThru

        $failure.FullyQualifiedErrorId | Should -BeLike 'SysAdminToolkit.BrokerListFailed*'
        $failure.Exception.InnerException | Should -BeOfType [System.TimeoutException]
        Should -Invoke -ModuleName SysAdminToolkit Restart-ServerAndWait -Times 0 -Exactly
    }

    It 'no source file throws a string that only copies the original error message' {
        $root = Join-Path $PSScriptRoot '..'
        $parser = [System.Management.Automation.Language.Parser]
        $files = Get-ChildItem -Path "$root/Private", "$root/Public" -Filter '*.ps1' -Recurse
        $isThrow = { $args[0] -is [System.Management.Automation.Language.ThrowStatementAst] }
        $offenders = foreach ($file in $files) {
            $ast = $parser::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $throws = $ast.FindAll($isThrow, $true)
            foreach ($throw in $throws) {
                $text = "$($throw.Pipeline)"
                if ($text -match '^["(]' -and $text -match '\$\(\$_\.Exception\.Message\)') {
                    '{0}:{1}' -f $file.Name, $throw.Extent.StartLineNumber
                }
            }
        }
        $offenders | Should -BeNullOrEmpty -Because 'use Get-ToolkitErrorRecord and keep the inner exception'
    }

    It 'no source file uses the obsolete Dns.GetHostByName, and only Invoke-Ping pings' {
        $root = Join-Path $PSScriptRoot '..'
        $files = Get-ChildItem -Path "$root/Private", "$root/Public" -Filter '*.ps1' -Recurse
        @($files | Select-String -Pattern 'GetHostByName' -SimpleMatch) | Should -BeNullOrEmpty
        # (?!\s*#) skips comment lines.
        $pings = $files | Where-Object Name -NE 'Invoke-Ping.ps1' |
            Select-String -Pattern '^(?!\s*#).*\bTest-Connection\b'
        @($pings) | Should -BeNullOrEmpty
    }
}

Describe 'Get-RDConnectedUser returns objects (F-21, issue #1)' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Read-Host { throw 'Read-Host must not be called' }
            Mock Write-Host { throw 'Write-Host must not be called' }
            Mock Get-ToolkitConfig { @{ RDBrokerServer = 'broker1' } }
            Mock Confirm-ConnectionBroker { 'BROKER1.CONTOSO.TEST' }
            Mock Get-ActiveBroker { 'BROKER2.CONTOSO.TEST' }
            Mock Get-RDCollectionName { 'Desktops', 'Apps' }
            Mock Get-FullNameFromUsername { "Full $UserName" }
            Mock Get-RDUserSession -ParameterFilter { $CollectionName -contains 'Desktops' } {
                [pscustomobject]@{
                    HostServer       = 'rds1.contoso.test'
                    UserName         = 'jdoe'
                    DomainName       = 'CONTOSO'
                    SessionState     = 'STATE_ACTIVE'
                    UnifiedSessionId = 3
                }
                [pscustomobject]@{
                    HostServer       = 'rds10.contoso.test'
                    UserName         = 'asmith'
                    DomainName       = 'CONTOSO'
                    SessionState     = 'STATE_DISCONNECTED'
                    UnifiedSessionId = 4
                }
            }
            Mock Get-RDUserSession -ParameterFilter { $CollectionName -contains 'Apps' } {
                [pscustomobject]@{
                    HostServer       = 'rds1.contoso.test'
                    UserName         = 'jdoe'
                    DomainName       = 'CONTOSO'
                    SessionState     = 'STATE_ACTIVE'
                    UnifiedSessionId = 7
                }
            }
        }
    }

    It 'returns one object per session in every collection, from the active broker' {
        InModuleScope SysAdminToolkit {
            $result = @(Get-RDConnectedUser)

            $result.Count | Should -Be 3
            $result[0].SessionHost | Should -Be 'rds1.contoso.test'
            $result[0].CollectionName | Should -Be 'Desktops'
            $result[0].FullName | Should -Be 'Full jdoe'
            $result[1].SessionState | Should -Be 'STATE_DISCONNECTED'
            $result[2].SessionId | Should -Be 7
            Should -Invoke Get-RDUserSession -Times 2 -Exactly -ParameterFilter {
                $ConnectionBroker -eq 'BROKER2.CONTOSO.TEST'
            }
        }
    }

    It 'matches -SessionHost exactly, so rds1 does not match rds10' {
        InModuleScope SysAdminToolkit {
            $result = @(Get-RDConnectedUser -CollectionName 'Desktops' -SessionHost 'rds1')

            $result.Count | Should -Be 1
            $result[0].UserName | Should -Be 'jdoe'
            Should -Invoke Get-RDCollectionName -Times 0 -Exactly
        }
    }

    It 'looks up each user in Active Directory only once' {
        InModuleScope SysAdminToolkit {
            $null = Get-RDConnectedUser

            Should -Invoke Get-FullNameFromUsername -Times 1 -Exactly -ParameterFilter { $UserName -eq 'jdoe' }
        }
    }

    It 'leaves FullName empty for users not in Active Directory' {
        InModuleScope SysAdminToolkit {
            Mock Get-FullNameFromUsername { throw 'not found' }

            $result = @(Get-RDConnectedUser -CollectionName 'Apps')

            $result[0].FullName | Should -BeNullOrEmpty
        }
    }

    It 'writes an error for a collection it cannot read and still returns the others' {
        InModuleScope SysAdminToolkit {
            Mock Get-RDUserSession -ParameterFilter { $CollectionName -contains 'Apps' } {
                throw [System.TimeoutException]::new('RPC timed out')
            }

            $result = @(Get-RDConnectedUser -ErrorVariable sessionErrors -ErrorAction SilentlyContinue)

            $result.Count | Should -Be 2
            # -ErrorVariable also collects caught inner errors, some as plain exceptions without
            # FullyQualifiedErrorId, so keep only error records before filtering.
            $listError = @($sessionErrors | Where-Object {
                    $_ -is [System.Management.Automation.ErrorRecord] -and
                    $_.FullyQualifiedErrorId -like 'SysAdminToolkit.SessionListFailed*'
                })
            $listError.Count | Should -Be 1
            $listError[0].Exception.InnerException | Should -BeOfType [System.TimeoutException]
        }
    }

    It 'fails clearly when no broker is given or configured' {
        InModuleScope SysAdminToolkit {
            Mock Get-ToolkitConfig { @{ RDBrokerServer = '' } }

            { Get-RDConnectedUser } | Should -Throw '*No Connection Broker given*'
        }
    }

    It 'has no PSAvoidUsingWriteHost suppression any more' {
        $path = Join-Path $script:moduleRoot 'Public/Server/RemoteDesktop/Get-RDConnectedUser.ps1'
        Select-String -LiteralPath $path -Pattern 'PSAvoidUsingWriteHost' -SimpleMatch | Should -BeNullOrEmpty
    }
}

Describe 'Show-RDConnectedUser (menu wrapper)' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Get-ToolkitConfig { @{ RDBrokerServer = 'broker1' } }
            Mock Confirm-ConnectionBroker { 'BROKER1.CONTOSO.TEST' }
            Mock Get-ActiveBroker { 'BROKER2.CONTOSO.TEST' }
            Mock Get-RDCollectionName { 'Desktops', 'Apps' }
            Mock Get-RDHostName { 'rds1', 'rds2' }
            Mock Show-MenuHeader { }
            Mock Out-Host { }
            Mock Get-RDConnectedUser { }
            $script:menuAnswers = [System.Collections.Generic.Queue[hashtable]]::new()
            Mock Show-Menu { $script:menuAnswers.Dequeue() }
        }
    }

    It 'passes the chosen collection and host to Get-RDConnectedUser' {
        InModuleScope SysAdminToolkit {
            $script:menuAnswers.Enqueue(@{ Quit = $false; Back = $false; Index = 1 })
            $script:menuAnswers.Enqueue(@{ Quit = $false; Back = $false; Index = 0 })

            Show-RDConnectedUser

            Should -Invoke Get-RDConnectedUser -Times 1 -Exactly -ParameterFilter {
                $ConnectionBroker -eq 'BROKER2.CONTOSO.TEST' -and $CollectionName -eq 'Apps' -and
                $SessionHost -eq 'rds1'
            }
        }
    }

    It 'returns to the menu without querying when Back is chosen' {
        InModuleScope SysAdminToolkit {
            $script:menuAnswers.Enqueue(@{ Quit = $false; Back = $true; Index = $null })

            Show-RDConnectedUser

            Should -Invoke Get-RDConnectedUser -Times 0 -Exactly
        }
    }
}

Describe 'Invoke-ADAccountUnlock returns objects (F-21, issue #1)' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Read-Host { throw 'Read-Host must not be called' }
            Mock Write-Host { throw 'Write-Host must not be called' }
            Mock Get-ValidADUser { throw 'Get-ValidADUser must not be called' }
            Mock Unlock-ADAccount { }
            # Accounts returned by Get-ADUser, in call order.
            $script:adAccounts = [System.Collections.Generic.Queue[object]]::new()
            Mock Get-ADUser {
                $next = $script:adAccounts.Dequeue()
                if ($next -is [System.Exception]) {
                    throw $next
                }
                $next
            }
            function script:New-TestAccount {
                param([string]$Sam, [bool]$Locked, $AdminCount = $null)
                [pscustomobject]@{
                    SamAccountName    = $Sam
                    Name              = "Name $Sam"
                    DistinguishedName = "CN=$Sam,OU=Users,DC=contoso,DC=test"
                    LockedOut         = $Locked
                    adminCount        = $AdminCount
                }
            }
        }
    }

    It 'requires -Identity' {
        $identity = (Get-Command -Name Invoke-ADAccountUnlock).Parameters['Identity']
        $identity.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
            Should -Contain $true
    }

    It 'unlocks a locked account and returns Unlocked' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Locked $true))

            $result = Invoke-ADAccountUnlock -Identity 'jdoe' -Force

            $result.Result | Should -Be 'Unlocked'
            $result.WasLocked | Should -BeTrue
            $result.Name | Should -Be 'Name jdoe'
            Should -Invoke Unlock-ADAccount -Times 1 -Exactly
        }
    }

    It 'leaves an account that is not locked alone and returns NotLocked' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Locked $false))

            $result = Invoke-ADAccountUnlock -Identity 'jdoe' -Force

            $result.Result | Should -Be 'NotLocked'
            Should -Invoke Unlock-ADAccount -Times 0 -Exactly
        }
    }

    It 'reports a missing account as an error and still processes the next identity' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue([Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]::new())
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'asmith' -Locked $true))

            $result = @(Invoke-ADAccountUnlock -Identity 'ghost', 'asmith' -Force -ErrorVariable unlockErrors `
                    -ErrorAction SilentlyContinue)

            $result.Count | Should -Be 1
            $result[0].SamAccountName | Should -Be 'asmith'
            $notFound = @($unlockErrors | Where-Object {
                    $_ -is [System.Management.Automation.ErrorRecord] -and
                    $_.FullyQualifiedErrorId -like 'SysAdminToolkit.UserNotFound*'
                })
            $notFound.Count | Should -Be 1
        }
    }

    It 'accepts objects with a SamAccountName property from the pipeline' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Locked $true))
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'asmith' -Locked $true))

            $result = @(
                [pscustomobject]@{ SamAccountName = 'jdoe' }, [pscustomobject]@{ SamAccountName = 'asmith' } |
                    Invoke-ADAccountUnlock -Force
            )

            $result.SamAccountName | Should -Be @('jdoe', 'asmith')
            Should -Invoke Unlock-ADAccount -Times 2 -Exactly
        }
    }

    It 'changes nothing and returns nothing with -WhatIf' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Locked $true))

            $result = Invoke-ADAccountUnlock -Identity 'jdoe' -WhatIf

            $result | Should -BeNullOrEmpty
            Should -Invoke Unlock-ADAccount -Times 0 -Exactly
        }
    }

    It 'warns before unlocking a protected (adminCount = 1) account' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'admin.jdoe' -Locked $true -AdminCount 1))

            $null = Invoke-ADAccountUnlock -Identity 'admin.jdoe' -Force -WarningVariable unlockWarnings `
                -WarningAction SilentlyContinue

            "$unlockWarnings" | Should -BeLike '*protected administrative group*'
        }
    }

    It 'returns Failed and keeps the original exception when the unlock fails' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Locked $true))
            Mock Unlock-ADAccount { throw [System.UnauthorizedAccessException]::new('Access is denied') }

            $result = Invoke-ADAccountUnlock -Identity 'jdoe' -Force -ErrorVariable unlockErrors `
                -ErrorAction SilentlyContinue

            $result.Result | Should -Be 'Failed'
            $failed = @($unlockErrors | Where-Object {
                    $_ -is [System.Management.Automation.ErrorRecord] -and
                    $_.FullyQualifiedErrorId -like 'SysAdminToolkit.UnlockFailed*'
                })
            $failed.Count | Should -Be 1
            $failed[0].Exception.InnerException | Should -BeOfType [System.UnauthorizedAccessException]
        }
    }

    It 'has no PSAvoidUsingWriteHost suppression any more' {
        $path = Join-Path $script:moduleRoot 'Public/Server/ActiveDirectory/Invoke-ADAccountUnlock.ps1'
        Select-String -LiteralPath $path -Pattern 'PSAvoidUsingWriteHost' -SimpleMatch | Should -BeNullOrEmpty
    }
}

Describe 'Show-ADAccountUnlock (menu wrapper)' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Show-MenuHeader { }
            Mock Write-Host { }
            Mock Get-ValidADUser { [pscustomobject]@{ SamAccountName = 'jdoe' } }
            Mock Invoke-ADAccountUnlock { [pscustomobject]@{ SamAccountName = 'jdoe'; Result = 'Unlocked' } }
        }
    }

    It 'unlocks the chosen account when it is locked' {
        InModuleScope SysAdminToolkit {
            Mock Get-ADUser { [pscustomobject]@{ SamAccountName = 'jdoe'; LockedOut = $true } }

            Show-ADAccountUnlock

            Should -Invoke Invoke-ADAccountUnlock -Times 1 -Exactly -ParameterFilter { $Identity -contains 'jdoe' }
        }
    }

    It 'warns and does not call Invoke-ADAccountUnlock when the account is not locked' {
        InModuleScope SysAdminToolkit {
            Mock Get-ADUser { [pscustomobject]@{ SamAccountName = 'jdoe'; LockedOut = $false } }

            Show-ADAccountUnlock -WarningVariable menuWarnings -WarningAction SilentlyContinue

            "$menuWarnings" | Should -BeLike '*not locked*'
            Should -Invoke Invoke-ADAccountUnlock -Times 0 -Exactly
        }
    }
}

Describe 'Invoke-ADAccountDisable returns objects (F-21, issue #1)' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Read-Host { throw 'Read-Host must not be called' }
            Mock Write-Host { throw 'Write-Host must not be called' }
            Mock Get-ValidADUser { throw 'Get-ValidADUser must not be called' }
            Mock Disable-ADAccount { }
            # Accounts returned by Get-ADUser, in call order.
            $script:adAccounts = [System.Collections.Generic.Queue[object]]::new()
            Mock Get-ADUser {
                $next = $script:adAccounts.Dequeue()
                if ($next -is [System.Exception]) {
                    throw $next
                }
                $next
            }
            function script:New-TestAccount {
                param([string]$Sam, [bool]$Enabled, $AdminCount = $null)
                [pscustomobject]@{
                    SamAccountName    = $Sam
                    Name              = "Name $Sam"
                    DistinguishedName = "CN=$Sam,OU=Users,DC=contoso,DC=test"
                    Enabled           = $Enabled
                    adminCount        = $AdminCount
                }
            }
        }
    }

    It 'requires -Identity' {
        $identity = (Get-Command -Name Invoke-ADAccountDisable).Parameters['Identity']
        $identity.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory |
            Should -Contain $true
    }

    It 'disables an enabled account and returns Disabled' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Enabled $true))

            $result = Invoke-ADAccountDisable -Identity 'jdoe' -Force

            $result.Result | Should -Be 'Disabled'
            $result.WasEnabled | Should -BeTrue
            $result.Name | Should -Be 'Name jdoe'
            Should -Invoke Disable-ADAccount -Times 1 -Exactly
        }
    }

    It 'leaves an account that is already disabled alone and returns AlreadyDisabled' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Enabled $false))

            $result = Invoke-ADAccountDisable -Identity 'jdoe' -Force

            $result.Result | Should -Be 'AlreadyDisabled'
            Should -Invoke Disable-ADAccount -Times 0 -Exactly
        }
    }

    It 'reports a missing account as an error and still processes the next identity' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue([Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]::new())
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'asmith' -Enabled $true))

            $result = @(Invoke-ADAccountDisable -Identity 'ghost', 'asmith' -Force -ErrorVariable disableErrors `
                    -ErrorAction SilentlyContinue)

            $result.Count | Should -Be 1
            $result[0].SamAccountName | Should -Be 'asmith'
            $notFound = @($disableErrors | Where-Object {
                    $_ -is [System.Management.Automation.ErrorRecord] -and
                    $_.FullyQualifiedErrorId -like 'SysAdminToolkit.UserNotFound*'
                })
            $notFound.Count | Should -Be 1
        }
    }

    It 'accepts objects with a SamAccountName property from the pipeline' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Enabled $true))
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'asmith' -Enabled $true))

            $result = @(
                [pscustomobject]@{ SamAccountName = 'jdoe' }, [pscustomobject]@{ SamAccountName = 'asmith' } |
                    Invoke-ADAccountDisable -Force
            )

            $result.SamAccountName | Should -Be @('jdoe', 'asmith')
            Should -Invoke Disable-ADAccount -Times 2 -Exactly
        }
    }

    It 'changes nothing and returns nothing with -WhatIf' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Enabled $true))

            $result = Invoke-ADAccountDisable -Identity 'jdoe' -WhatIf

            $result | Should -BeNullOrEmpty
            Should -Invoke Disable-ADAccount -Times 0 -Exactly
        }
    }

    It 'warns before disabling a protected (adminCount = 1) account' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'admin.jdoe' -Enabled $true -AdminCount 1))

            $null = Invoke-ADAccountDisable -Identity 'admin.jdoe' -Force -WarningVariable disableWarnings `
                -WarningAction SilentlyContinue

            "$disableWarnings" | Should -BeLike '*protected administrative group*'
        }
    }

    It 'returns Failed and keeps the original exception when the disable fails' {
        InModuleScope SysAdminToolkit {
            $script:adAccounts.Enqueue((New-TestAccount -Sam 'jdoe' -Enabled $true))
            Mock Disable-ADAccount { throw [System.UnauthorizedAccessException]::new('Access is denied') }

            $result = Invoke-ADAccountDisable -Identity 'jdoe' -Force -ErrorVariable disableErrors `
                -ErrorAction SilentlyContinue

            $result.Result | Should -Be 'Failed'
            $failed = @($disableErrors | Where-Object {
                    $_ -is [System.Management.Automation.ErrorRecord] -and
                    $_.FullyQualifiedErrorId -like 'SysAdminToolkit.DisableFailed*'
                })
            $failed.Count | Should -Be 1
            $failed[0].Exception.InnerException | Should -BeOfType [System.UnauthorizedAccessException]
        }
    }

    It 'has no PSAvoidUsingWriteHost suppression any more' {
        $path = Join-Path $script:moduleRoot 'Public/Server/ActiveDirectory/Invoke-ADAccountDisable.ps1'
        Select-String -LiteralPath $path -Pattern 'PSAvoidUsingWriteHost' -SimpleMatch | Should -BeNullOrEmpty
    }
}

Describe 'Show-ADAccountDisable (menu wrapper)' {
    BeforeEach {
        InModuleScope SysAdminToolkit {
            Mock Show-MenuHeader { }
            Mock Write-Host { }
            Mock Get-ValidADUser { [pscustomobject]@{ SamAccountName = 'jdoe' } }
        }
    }

    It 'disables the chosen account' {
        InModuleScope SysAdminToolkit {
            Mock Invoke-ADAccountDisable {
                [pscustomobject]@{ SamAccountName = 'jdoe'; Name = 'John Doe'; Result = 'Disabled' }
            }

            Show-ADAccountDisable

            Should -Invoke Invoke-ADAccountDisable -Times 1 -Exactly -ParameterFilter {
                $Identity -contains 'jdoe'
            }
        }
    }

    It 'warns when the account is already disabled' {
        InModuleScope SysAdminToolkit {
            Mock Invoke-ADAccountDisable {
                [pscustomobject]@{ SamAccountName = 'jdoe'; Name = 'John Doe'; Result = 'AlreadyDisabled' }
            }

            Show-ADAccountDisable -WarningVariable menuWarnings -WarningAction SilentlyContinue

            "$menuWarnings" | Should -BeLike '*already disabled*'
        }
    }
}
