function Test-ToolkitConfigTrust {
    <#
    .SYNOPSIS
    Checks that only administrators can change a configuration file or folder.

    .DESCRIPTION
    The configuration controls which executable Stop-FileLock runs and which servers the toolkit reboots, so
    anyone who can change it can make an administrator run their code. A path is trusted only when:
    - its owner is BUILTIN\Administrators, NT AUTHORITY\SYSTEM, or TrustedInstaller, and
    - no other identity has an Allow entry that grants write, delete, permission-change, or ownership rights.
    Deny entries and CREATOR OWNER entries are ignored. CREATOR OWNER only affects items created later, and
    creating items already requires write access, which is checked.
    Identities are compared by SID, so the check works on non-English Windows.

    .PARAMETER Path
    The file or folder to check.

    .OUTPUTS
    PSCustomObject with Path, IsTrusted, and Reasons (why the path is not trusted).

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $trustedSids = @(
        'S-1-5-32-544'                                                    # BUILTIN\Administrators
        'S-1-5-18'                                                        # NT AUTHORITY\SYSTEM
        'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'  # NT SERVICE\TrustedInstaller
    )
    $creatorOwnerSid = 'S-1-3-0'

    # WriteData also means CreateFiles on a folder; AppendData also means CreateDirectories.
    $modifyRights = [System.Security.AccessControl.FileSystemRights](
        'WriteData, AppendData, Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership'
    )
    # Generic GENERIC_ALL (0x10000000) and GENERIC_WRITE (0x40000000) bits can appear on inherited entries.
    $genericWriteBits = 0x50000000

    $reasons = [System.Collections.Generic.List[string]]::new()
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop

    $ownerSid = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
    if ($ownerSid -notin $trustedSids) {
        $reasons.Add("owner is '$($acl.Owner)'")
    }

    $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
    foreach ($rule in $rules) {
        $sid = $rule.IdentityReference.Value
        if ($rule.AccessControlType -ne 'Allow' -or $sid -in $trustedSids -or $sid -eq $creatorOwnerSid) {
            continue
        }
        $rights = [int64]$rule.FileSystemRights
        if (($rights -band [int64]$modifyRights) -or ($rights -band $genericWriteBits)) {
            $name = try {
                $rule.IdentityReference.Translate([System.Security.Principal.NTAccount]).Value
            } catch {
                $sid
            }
            $reasons.Add("'$name' can modify it ($($rule.FileSystemRights))")
        }
    }

    [pscustomobject]@{
        Path      = $Path
        IsTrusted = $reasons.Count -eq 0
        Reasons   = $reasons.ToArray()
    }
}
