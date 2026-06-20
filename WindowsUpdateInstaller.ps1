<#
.SYNOPSIS
  Script to install Windows Updates
.DESCRIPTION
  This script will install pending Windows Updates and reboot the server if needed.
.PARAMETER Reboot
  Specify if the servers needs to reboot after the updates or not, is default false.
.OUTPUTS
  A log file will be created under c:\temp\WindowsUpdateInstaller.log
.NOTES
  Version:        0.1
  Author:         Seys Alain
  Creation Date:  29/01/2022
  Purpose/Change: Initial script development
.EXAMPLE
  WindowsUpdateInstaller.ps1 -Reboot $false
#>

param (
    [switch]$Reboot
 )



# Define variables
$logPath = "c:\Temp"
$logFile = "c:\Temp\WindowsUpdateInstaller.log"


if (Test-Path -Path $logPath) {
    Write-Verbose "Path already exists."        
}
else {
    Write-Verbose "Create directory $logPath"    
    New-Item -Path $logPath -ItemType Directory -Force         
} 

#Define log function
function Write-Logfile() {
    param (
        [string]$logText
     )
    "$(get-date -Format 'dd/MM/yyyy h:m:s') $($logText)" | Out-File $logFile -Append
}

#Define update criteria.
$Criteria = "IsInstalled=0"

#Search for relevant updates.
$Searcher = New-Object -ComObject Microsoft.Update.Searcher
Write-Logfile -logText "Windows Update searcher created." 
$SearchResult = $Searcher.Search($Criteria).Updates
Write-Logfile -logText "$($SearchResult.count ) updates found" 

foreach($Result in $SearchResult) {
    Write-Logfile -logText $Result.Title    
}

#Download updates.
Write-Logfile -logText "Downloading the updates." 
foreach($Update in $SearchResult) {
    if($Update.IsDownloaded) {
        Write-Logfile -logText "$($Update.Title) already downloaded"
    } else {
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Downloader = $Session.CreateUpdateDownloader()
        $Downloader.Updates = New-Object -ComObject Microsoft.Update.UpdateColl
        $Downloader.Updates.Add($Update)
        $downloadResult = $Downloader.Download()

        if($downloadResult.ResultCode -ne 2) {
            Write-Logfile -logText "$($Update.Title) failed to download"
        } else {
            Write-Logfile -logText "$($Update.Title) downloaded"
        }
    }
}

#Install the updates.
Write-Logfile -logText "Installing the $($SearchResult.count) update(s)." 

$Installer = New-Object -ComObject Microsoft.Update.Installer
$Installer.Updates = $SearchResult
$InstallerResult = $Installer.Install()

$indexUpdate = 0
foreach($Update in $SearchResult) {
    try {
        $updateResult = $InstallerResult.GetUpdateResult($indexUpdate)

        if($updateResult.ResultCode -eq 2) {
            Write-Logfile "Update $($Update.Title) succeeded"
        } else {
            Write-Logfile "Update $($Update.Title) failed with error code $($updateResult.ResultCode) / $($updateResult.HResult)"
        }

    } catch {
        Write-Logfile -logText "Failed to get update results for $($Update.Title)"
    }   
    $indexUpdate++ 
}

#Reboot if required
if ($Reboot) {
    Write-Logfile -logText "Check reboot required..."
    if ( ((New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired) -eq $True) {
        Write-Logfile -logText "Reboot required - restart computer..."
        Restart-Computer -Force
    }
    else {
        Write-Logfile -logText "No reboot required."
    }
} else {
    Write-Logfile -logText "No check reboot required. No reboot from this script."
}
