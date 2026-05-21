---
external help file: SysAdminToolkit-help.xml
Module Name: SysAdminToolkit
online version:
schema: 2.0.0
---

# Invoke-ADSync

## SYNOPSIS

Triggers a delta synchronization cycle on the configured AD Connect server.

## SYNTAX

```powershell
Invoke-ADSync [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Resolves and verifies connectivity to the AD Connect server specified in the toolkit configuration
(or prompts for one if not configured).
Connects to the server via Invoke-Command and runs
Start-ADSyncSyncCycle with the Delta policy type.
Waits for the sync cycle to begin and then polls until
it completes before returning.

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-ADSync
# Triggers a delta AD sync on the configured AD Connect server and waits for completion
```

## PARAMETERS

### -ProgressAction

{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

Author: Alexander Christian
Requires the ADSync module to be installed on the target AD Connect server.
The ADConnectServer value is read from the toolkit configuration via Get-ToolkitConfig.

## RELATED LINKS
