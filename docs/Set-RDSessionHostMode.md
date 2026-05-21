---
external help file: SysAdminToolkit-help.xml
Module Name: SysAdminToolkit
online version:
schema: 2.0.0
---

# Set-RDSessionHostMode

## SYNOPSIS

Toggles the connection acceptance on one or more Remote Desktop session hosts.

## SYNTAX

```powershell
Set-RDSessionHostMode [[-ConnectionBroker] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Resolves and verifies connectivity to the specified Connection Broker, retrieves all Remote Desktop session
collections of type 'Remote Desktop', and prompts the user to select a collection and then one or more session
hosts to toggle.
Session hosts that currently allow new connections are disabled, and hosts that are disabled
are enabled.

## EXAMPLES

### EXAMPLE 1

```powershell
Set-RDSessionHostMode -ConnectionBroker 'broker01'
# Connects to broker01 and walks through collection and host selection interactively
```

### EXAMPLE 2

```powershell
Set-RDSessionHostMode
# Prompts for the Connection Broker name, then proceeds interactively
```

## PARAMETERS

### -ConnectionBroker

Optional.
The hostname or FQDN of a Remote Desktop Connection Broker.
If not provided, the user is prompted
to enter one.

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

## RELATED LINKS
