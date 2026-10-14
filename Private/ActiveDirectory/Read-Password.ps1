function Read-Password {
    <#
    .SYNOPSIS
    Reads a new password twice and returns it as a SecureString once both entries match.

    .DESCRIPTION
    Prompts for the password twice with Read-Host -AsSecureString and repeats until both entries match and are not
    empty. Returns the password as a SecureString; it is never written to a PowerShell string variable.

    To compare the two entries, each is copied briefly into unmanaged memory as plain text (a BSTR). Both copies
    are overwritten with zeros and freed in a finally block, including when the comparison fails or is
    interrupted.

    .EXAMPLE
    $securePassword = Read-Password
    # Prompts for a password twice and returns it as a SecureString once the entries match.

    .OUTPUTS
    System.Security.SecureString. The confirmed password.

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive prompt; output is for the operator, not the pipeline.')]
    param()

    $marshal = [System.Runtime.InteropServices.Marshal]

    while ($true) {
        $password1 = Read-Host -Prompt 'Enter Password' -AsSecureString
        $password2 = Read-Host -Prompt 'Confirm Password' -AsSecureString

        if ($password1.Length -eq 0) {
            Write-Host 'The password cannot be empty. Please try again.' -ForegroundColor Red
            continue
        }

        $match = $false
        if ($password1.Length -eq $password2.Length) {
            $bstr1 = [IntPtr]::Zero
            $bstr2 = [IntPtr]::Zero
            try {
                $bstr1 = $marshal::SecureStringToBSTR($password1)
                $bstr2 = $marshal::SecureStringToBSTR($password2)
                $match = $true
                for ($i = 0; $i -lt $password1.Length; $i++) {
                    # BSTRs are UTF-16, so each character is two bytes.
                    if ($marshal::ReadInt16($bstr1, $i * 2) -ne $marshal::ReadInt16($bstr2, $i * 2)) {
                        $match = $false
                        break
                    }
                }
            } finally {
                if ($bstr1 -ne [IntPtr]::Zero) {
                    $marshal::ZeroFreeBSTR($bstr1)
                }
                if ($bstr2 -ne [IntPtr]::Zero) {
                    $marshal::ZeroFreeBSTR($bstr2)
                }
            }
        }

        if ($match) {
            $password2.Dispose()
            Write-Host 'Passwords match' -ForegroundColor Green
            return $password1
        }

        Write-Host 'Passwords do not match. Please try again.' -ForegroundColor Red
    }
}
