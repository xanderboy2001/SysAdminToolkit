---
external help file: SysAdminToolkit-help.xml
Module Name: SysAdminToolkit
online version:
schema: 2.0.0
---

# Invoke-ADPasswordReset

## SYNOPSIS

Resets the password for an Active Directory user account.

## SYNTAX

```powershell
Invoke-ADPasswordReset [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION

Prompts for a valid Active Directory username and resets the account password after confirmation.
The new password is read as a SecureString via Read-Password to avoid storing credentials in plaintext.
The account is also unlocked after a successful password reset in case it was locked due to failed attempts.

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-ADPasswordReset
# Prompts for a username, requests confirmation, then resets the account password
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
