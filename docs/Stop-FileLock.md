---
external help file: SysAdminToolkit-help.xml
Module Name: SysAdminToolkit
online version:
schema: 2.0.0
---

# Stop-FileLock

## SYNOPSIS

Identifies and terminates processes holding a lock on a specified file.

## SYNTAX

```powershell
Stop-FileLock [[-FileName] <String>] [[-ComputerName] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION

Prompts for filename and an optional remote computer name, then uses Handle.exe to identify any processes
with an open handle on that file.
If blocking processes are found, they are listed and the user is prompted
to confirm before each is forcibly terminated with Stop-Process.
The Sysinternals path is read from the
toolkit configuration via Get-ToolkitConfig.

## EXAMPLES

### EXAMPLE 1

```powershell
Stop-FileLock
# Prompts for a filename and computer name, then unlocks the file if processes are found
```

## PARAMETERS

### -ComputerName

Optional.
The name of a remote computer to target.
If not provided, the user is prompted and may leave blank
to target the local machine.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FileName

Optional.
The name or path of the locked file.
If not provided, the user is prompted.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

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
Requires Sysinternals Handle.exe.
The path is read from the SysinternalsPath toolkit config key.

## RELATED LINKS
