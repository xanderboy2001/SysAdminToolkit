function Protect-ToolkitConfigDirectory {
    <#
    .SYNOPSIS
    Creates or repairs the configuration folder so that only administrators can change it.

    .DESCRIPTION
    Sets the folder's owner to BUILTIN\Administrators and replaces its permissions with:
    - BUILTIN\Administrators : Full control
    - NT AUTHORITY\SYSTEM    : Full control
    - BUILTIN\Users          : Read & execute
    Inheritance from C:\ProgramData is turned off, because ProgramData lets standard users create files.
    Files already in the folder get Administrators as owner and lose any explicit permissions, so they inherit
    only the entries above.

    Requires an elevated session.

    .PARAMETER Path
    The configuration folder.

    .EXAMPLE
    & (Get-Module SysAdminToolkit) { Protect-ToolkitConfigDirectory -Path (Split-Path $script:ConfigPath) }
    # One-time repair of an existing configuration folder, run from an elevated session.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $administrators = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $system = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $users = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
    $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagation = [System.Security.AccessControl.PropagationFlags]::None

    $folderAcl = [System.Security.AccessControl.DirectorySecurity]::new()
    $folderAcl.SetOwner($administrators)
    # $true, $false: stop inheriting from the parent and do not copy the inherited entries.
    $folderAcl.SetAccessRuleProtection($true, $false)
    $entries = @(
        @{ Sid = $administrators; Rights = 'FullControl' }
        @{ Sid = $system; Rights = 'FullControl' }
        @{ Sid = $users; Rights = 'ReadAndExecute' }
    )
    foreach ($entry in $entries) {
        $rights = [System.Security.AccessControl.FileSystemRights]$entry.Rights
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $entry.Sid, $rights, $inherit, $propagation, 'Allow'
        )
        $folderAcl.AddAccessRule($rule)
    }

    $action = 'Restrict to Administrators and SYSTEM (write) and Users (read)'
    if (-not $PSCmdlet.ShouldProcess($Path, $action)) {
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -ItemType Directory -Path $Path -ErrorAction Stop
    }
    Set-Acl -LiteralPath $Path -AclObject $folderAcl -ErrorAction Stop

    foreach ($file in Get-ChildItem -LiteralPath $Path -File -Force) {
        $fileAcl = [System.Security.AccessControl.FileSecurity]::new()
        $fileAcl.SetOwner($administrators)
        # $false: inherit from the folder. No explicit entries are added.
        $fileAcl.SetAccessRuleProtection($false, $false)
        Set-Acl -LiteralPath $file.FullName -AclObject $fileAcl -ErrorAction Stop
    }
}
