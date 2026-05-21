---
external help file: SysAdminToolkit-help.xml
Module Name: SysAdminToolkit
online version:
schema: 2.0.0
---

# Get-BatteryReport

## SYNOPSIS

Retrieves battery capacity data from a single computer.

## SYNTAX

```powershell
Get-BatteryReport [[-ComputerName] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION

Connects to the specified computer via Invoke-Command and uses powercfg to generate
a temporary XML battery
report.
The design capacity and full charge capacity are parsed from the report and
returned as a PSCustomObject.
The temporary report file is removed from the remote machine after parsing.

CapacityPercent is calculated as (FullChargeCapacity / DesignCapacity) \* 100,
rounded to 1 decimal place.
Capacity values are in milliwatt-hours (mWh).

## EXAMPLES

### EXAMPLE 1

```powershell
Get-BatteryReport -ComputerName 'PC-1234'
# Returns battery capacity data for PC-1234
```

### EXAMPLE 2

```powershell
Get-BatteryReport
# Prompts for a computer name and returns battery capacity data
```

## PARAMETERS

### -ComputerName

Optional.
The name of the computer to collect battery data from.
If not provided, the user is prompted to
enter one.

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

This cmdlet supports the common parameters: -Debug
-ErrorAction
-ErrorVariable
-InformationAction
-InformationVariable
-OutVariable
-OutBuffer
-PipelineVariable
-Verbose
-WarningAction
-WarningVariable
For more information see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSCustomObject with properties

ComputerName, DesignCapacity, FullChargeCapacity, CapacityPercent

## NOTES

Author: Alexander Christian
Requires powercfg to be available and the executing account to have permission
to run it remotely on the target machine.

## RELATED LINKS
