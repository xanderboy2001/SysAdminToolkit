---
external help file: SysAdminToolkit-help.xml
Module Name: SysAdminToolkit
online version:
schema: 2.0.0
---

# Start-ToolkitMenu

## SYNOPSIS

Displays the main menu for the SysAdmin Toolkit.

## SYNTAX

```powershell
Start-ToolkitMenu [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Shows the main menu with options for Server, Client, and Config menus.
Handles user input and navigates to the appropriate submenu or exits the toolkit if a quit command is entered.

## EXAMPLES

### EXAMPLE 1

```powershell
Start-ToolkitMenu
# Displays the main menu and waits for the user to select an option
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

## RELATED LINKS
