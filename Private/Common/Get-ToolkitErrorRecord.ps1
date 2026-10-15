function Get-ToolkitErrorRecord {
    <#
    .SYNOPSIS
    Builds an ErrorRecord that keeps the original exception as its inner exception.

    .DESCRIPTION
    Used with $PSCmdlet.ThrowTerminatingError() or $PSCmdlet.WriteError() instead of throwing a string that
    only copies the original error's message. The message gives the toolkit's context; the original exception
    (its type, stack trace, and details) stays available in $Error[0].Exception.InnerException.

    .PARAMETER Message
    What failed, in the toolkit's words.

    .PARAMETER InnerException
    Optional. The exception that caused the failure, usually $_.Exception in a catch block.

    .PARAMETER ErrorId
    A short identifier. It is prefixed with 'SysAdminToolkit.' to form the FullyQualifiedErrorId.

    .PARAMETER Category
    The error category. Defaults to NotSpecified.

    .PARAMETER TargetObject
    Optional. The object the operation was working on, such as a computer name.

    .EXAMPLE
    try { Get-RDServer -ConnectionBroker $broker -ErrorAction Stop } catch {
        $PSCmdlet.ThrowTerminatingError((Get-ToolkitErrorRecord -Message "Could not list brokers." `
                    -InnerException $_.Exception -ErrorId 'BrokerListFailed' -TargetObject $broker))
    }

    .OUTPUTS
    System.Management.Automation.ErrorRecord

    .NOTES
    Author: Alexander Christian
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Only creates an object in memory; changes no system state.')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [System.Exception]$InnerException,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ErrorId,

        [System.Management.Automation.ErrorCategory]$Category = 'NotSpecified',

        [object]$TargetObject
    )

    $exception = [System.InvalidOperationException]::new($Message, $InnerException)
    [System.Management.Automation.ErrorRecord]::new(
        $exception, "SysAdminToolkit.$ErrorId", $Category, $TargetObject
    )
}
