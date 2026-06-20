<#
.SYNOPSIS
  Script to check if a computer has a update group
.DESCRIPTION
  This script wil report if a computer has a update group

.OUTPUTS
  A log file will be created under c:\temp\ServerGroupCheck.log
  A CSV file will be created under c:\temp\ServerGroupMissing.csv
.NOTES
  Version:        0.1
  Author:         Seys Alain
  Creation Date:  12/06/2026
  Purpose/Change: Add logging and csv
.EXAMPLE

#>
$LogFile = "C:\Temp\ServerGroupCheck.log"
$ResultFile = "C:\Temp\ServerGroupMissing.csv"

# Ensure folder exists
if (-not (Test-Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory | Out-Null
}

# Start log
"$(Get-Date) - Script started" | Out-File $LogFile -Append

$Computers = Get-ADComputer `
    -Filter "OperatingSystem -like 'Windows Server*' -and Name -notlike 'CTXVM*' -and Enabled -eq 'True'" `
    -Properties OperatingSystem

$Total = $Computers.Count
$Current = 0
$MissingCount = 0

$Result = foreach ($Computer in $Computers) {

    $Current++

    Write-Progress `
        -Activity "Checking Windows Server group memberships" `
        -Status "Processing $($Computer.Name) ($Current of $Total) - Missing groups found: $MissingCount" `
        -PercentComplete (($Current / $Total) * 100)

    $Groups = Get-ADPrincipalGroupMembership $Computer |
              Select-Object -ExpandProperty Name

    if (-not ($Groups -like "gl_mg_sv_wu_*")) {

        $MissingCount++

        "$(Get-Date) - WARNING: $($Computer.Name) missing required group membership" |
            Out-File $LogFile -Append

        [PSCustomObject]@{
            ComputerName    = $Computer.Name
            OperatingSystem = $Computer.OperatingSystem
        }
    }
}

Write-Progress -Activity "Checking Windows Server group memberships" -Completed

# Save results
$Result | Sort-Object ComputerName | Export-Csv $ResultFile -NoTypeInformation

"$(Get-Date) - Script completed. Missing count: $MissingCount" |
    Out-File $LogFile -Append