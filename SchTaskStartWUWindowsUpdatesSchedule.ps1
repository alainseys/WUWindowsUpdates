$WUconfig = Import-PowerShellDataFile .\inc\Config.ps1

Set-Location $WUconfig.scriptbase
Import-Module .\WindowsUpdates.psm1
Start-WUWindowsUpdatesSchedule
