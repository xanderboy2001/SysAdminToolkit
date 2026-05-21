---
external help file: SysAdminToolkit-help.xml
Module Name: SysAdminToolkit
online version:
schema: 2.0.0
---

# Invoke-ADAccountDisable

## SYNOPSIS

Disables an Active Directory user account.

## SYNTAX

```powershell
Invoke-ADAccountDisable [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Prompts for a valid Active Directory username and disables the corresponding account.
Uses Get-ValidADUser to resolve and validate the account before calling Disable-ADAccount.
Displays a success or failure message depending on the outcome.

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-ADAccountDisable
# Prompts for a username and disables the corresponding Active Directory account
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

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf

Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

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
