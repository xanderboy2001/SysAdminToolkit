function Get-OUPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # User chose AD OU
    do {
        $result = Read-Host "Do you know the full path to the OU containing your servers? Selecting 'No' will open an interactive menu to select the OU [y/n]"
    } until ($result -match '[Yy]' -or $result -match '[Nn]')

    if ($result -match '[Yy]') {
        do {
            $OUPath = Read-Host "Enter the path to the OU containing your servers"
        } until ($OUPath -match '^(OU=.+,)+DC=.+,DC=.+$')
    }
    else {
        $CurrentPath = (Get-ADDomain).DistinguishedName
        $TargetOUSelected = $false

        while (-not $TargetOUSelected) {
            Write-Host "`nCurrent Location: $CurrentPath" -ForegroundColor Cyan

            # Get ONLY the immediate childred of the current path
            $ChildOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $CurrentPath -SearchScope OneLevel |
                Select-Object Name, DistinguishedName

            # If we hit the bottom of the tree
            if ($ChildOUs.Count -eq 0 -or $null -eq $ChildOUs) {
                Write-Host "No further sub-OUs found. Selecting this location." -ForegroundColor Yellow
                $OUPath = $CurrentPath
                $TargetOUSelected = $true
            }
            else {
                # Option 0 is ALWAYS to select current directory
                Write-Host "[0]`t>>> SELECT THIS OU <<<" -ForegroundColor Green

                # List the children
                for ($i = 0; $i -lt $ChildOUs.Count; $i++) {
                    Write-Host "[$($i + 1)]`tDrill down into: $($ChildOUs[$i].Name)"
                }

                # Capture input and cast to integer for safe comparison
                [int]$selection = Read-Host "Enter a number to drill down, or 0 to select the current OU"

                if ($selection -eq 0) {
                    # User is done navigating
                    $OUPath = $CurrentPath
                    $TargetOUSelected = $true
                }
                elseif ($selection -ge 1 -and $selection -le $ChildOUs.Count) {
                    # User wants to go deeper. Update the path and let the loop run again.
                    $CurrentPath = $ChildOUs[$selection - 1].DistinguishedName
                }
                else {
                    Write-Host "Invalid input, please try again." -ForegroundColor Red
                }
            }
        }
    }
    Write-Output $OUPath
}

function Get-ServerList() {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    Write-Host "How would you like to define your server list?"
    Write-Host "`t[1]`tActive Directory OU"
    Write-Host "`t[2]`tManual Input"
    do {
        $result = Read-Host "Enter the number corresponding to your choice"
    } while ($result -ne 1 -and $result -ne 2)
    if ($result -eq 1) {
        $OUPath = Get-OUPath
        $ServerList = Get-ADComputer -Filter * -SearchBase $OUPath | Select-Object Name, DNSHostName, DistinguishedName
    }
    else {
        $ServerList = @()
        do {
            $Server = Read-Host "Enter the name of a server. Enter a blank line when done"
            if ($Server -and $Server -ne "") {
                $ServerList += $Server 
            }
        } while ($Server -ne "")
    }
    Write-Output $ServerList
}

function Get-ServerDiskType() {
    [CmdletBinding()]
    param()

    $RawList = Get-ServerList
    
    if (-not $RawList) {
        Write-Warning "No servers selected;"; return 
    }

    $TargetServers = foreach ($Item in $RawList) {
        if ($Item.DNSHostName) {
            $Item.DNSHostName 
        }
        elseif ($Item.Name) {
            $Item.Name 
        }
        else {
            $Item 
        }
    }

    Write-Host "`nInitiating parallel disk query against $($TargetServers.Count) servers..." -ForegroundColor Cyan

    $CimQuery = {
        try {
            # Query the partitions
            $Partitions = Get-CimInstance -ClassName Win32_DiskPartition -ErrorAction Stop

            # Check if ANY partition on the server is a Logical Disk Manager (Dynamic)
            $HasDynamic = [bool]($Partitions | Where-Object { $_.Type -match "Logical Disk Manager" })

            [pscustomobject]@{
                DiskType = if ($HasDynamic) {
                    "Dynamic" 
                }
                else {
                    "Basic" 
                }
                Status = "Success"
            }
        }
        catch {
            [pscustomobject]@{
                DiskType = "Unknown"
                Status = "Failed: $($_.Exception.Message)"
            }
        }
    }

    $Job = Invoke-Command -ComputerName $TargetServers -ScriptBlock $CimQuery -AsJob -ErrorAction SilentlyContinue

    while ($Job.State -eq 'Running') {
        $TotalTasks = $Job.ChildJobs.Count
        $CompletedTasks = ($Job.ChildJobs | Where-Object { $_.State -ne 'Running' }).Count

        $Percent = 0
        if ($TotalTasks -gt 0) {
            $Percent = [System.Math]::Round(($CompletedTasks / $TotalTasks) * 100) 
        }
        
        $ProgressParams = @{
            Activity = "Auditing Remote Disk Types"
            Status = "$CompletedTasks of $TotalTasks Servers Completed"
            PercentComplete = $Percent
        }
        Write-Progress @ProgressParams
        
        Start-Sleep -Milliseconds 250
    }

    Write-Progress -Activity "Auditing Remote Disk Types" -Completed

    $Results = Receive-Job -Job $Job
    $SuccessfulServers = $Results.PSComputerName | ForEach-Object { $_.ToLower() }
    Remove-Job -Job $Job

    $FinalReport = @()
    foreach ($Server in $TargetServers) {
        $Match = $Results | Where-Object { $_.PSComputerName -eq $Server }
        if ($Match) {
            $FinalReport += [pscustomobject]@{
                ComputerName = $Server
                DiskType = $Match.DiskType
                Status = $Match.Status
            }
        }
        else {
            $FinalReport += [pscustomobject]@{
                ComputerName = $Server
                DiskType = "Unknown"
                Status = "Failed: Connection/Access Denied"
            }
        }
    }

    Write-Host "Query Complete!`n" -ForegroundColor Green
    return $FinalReport
}
