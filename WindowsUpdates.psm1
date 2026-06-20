# WindowsUpdates.psm1
# Copyright 2023 Seys Alain
# alain.seys@outlook.com
# v2023.12.05

############################################################

####################### VARIABLES ##########################

############################################################

# Load WU Config File
$WUconfig = Import-PowerShellDataFile .\inc\Config.ps1

# Load inventory
$inventory = Import-Csv -Path "C:\SCRIPTS\WUWindowsUpdates\csv\Inventory.csv"

# Missing machines log file path
$missingMachinesLog = "C:\SCRIPTS\WUWindowsUpdates\logs\MissingMachines.log"


############################################################

################### PREREQUISISTES #########################

############################################################

$adModule = Get-Module -Name ActiveDirectory -ListAvailable

if($adModule) {
    Import-Module -Name ActiveDirectory
} else {
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
    Import-Module -Name ActiveDirectory
}

if($WUconfig.vmwareSnapshots) {
    
    $vmwareModule = Get-Module -Name VMware.PowerCLI -ListAvailable

    if($vmwareModule) {
        Get-Module -Name VMware.PowerCLI -ListAvailable | Import-Module        
    } else {
        $powershellModulePath = "C:\Windows\system32\WindowsPowerShell\v1.0\Modules"
        Copy-Item "C:\SCRIPTS\WUWindowsUpdates\modules\vmware\*" -Destination $powershellModulePath -Recurse
        Get-Module -Name VMware.PowerCLI -ListAvailable | Import-Module
    }

}

############################################################

####################### FUNCTIONS ##########################

############################################################
# Netbox Integration
function Get-AssignedObjectId(){
    param(
        [string]$Computer
    )
    # Search for Virtual Machine
    $VMUrl = "https://ipam.vanmarcke.be/api/virtualization/virtual-machines/?name=$Computer"
    $headers = @{
        "Authorization" = "Token 929593ab0ebfeaa8795d00cfa052189f2f90c602"
    }
    $VMResponse = Invoke-RestMethod -Uri $VMUrl -Headers $headers
    if($VMResponse.count -gt 0){
        return [PSCustomObject]@{
            AssignedObjectId   = $VMResponse.results[0].id
            AssignedObjectType = "virtualization.virtualmachine"
        }
    }
    # Not found search for physical
    $DeviceUrl = "https://ipam.vanmarcke.be/api/dcim/devices/?name=$Computer"
    $DeviceResponse = Invoke-RestMethod -Uri $DeviceUrl -Headers $headers
    if($DeviceResponse.count -gt 0){
        return [PSCustomObject]@{
            AssignedObjectId   = $DeviceResponse.results[0].id
            AssignedObjectType = "dcim.device"
        }
    }
    # Not found - log to missing machines file
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - Computer '$Computer' not found in Netbox (VM or Device)" | Out-File $missingMachinesLog -Append
    return $null
}

function New-JournalEntry(){
    param(
        [string]$Computer,
        [string]$Comment,
        [string]$Kind
    )
    # Get object data
    $ObjectDetails = Get-AssignedObjectId -Computer $Computer
    if(-not $ObjectDetails){
        Write-Host "No matching object found for $Computer - logged to missing machines log"
        return
    }
    $AssignedObjectId = $ObjectDetails.AssignedObjectId
    $AssignedObjectType = $ObjectDetails.AssignedObjectType

    # Prepare the payload
    $JournalEntry = @{
        "assigned_object_id"   = $AssignedObjectId
        "assigned_object_type" = $AssignedObjectType
         "comments"            = $Comment
        "kind"                = $Kind
    }
    $Body = $JournalEntry | ConvertTo-Json -Depth 3 -Compress
    $headers = @{
          "Authorization" = "Token 929593ab0ebfeaa8795d00cfa052189f2f90c602"
          "Content-Type" = "application/json"
    }

    try{

        $Response = Invoke-RestMethod -Uri "https://ipam.vanmarcke.be/api/extras/journal-entries/" -Method Post -Headers $headers -Body $Body
         Write-Host "Journal entry created successfully."
    }
    catch{
        Write-Host "Failed to create journal entry. Error: $_  "
        Write-Host "Headers: $($headers | ConvertTo-Json)"
        Write-Host "Body: $Body"
        
    }
}

# New function to compare and log installed updates
function Compare-AndLogUpdates() {
    param(
        [string]$Computer,
        [array]$BeforeUpdates,
        [array]$AfterUpdates
    )
    
    $logFunction = "Compare-AndLogUpdates"
    
    # If BeforeUpdates is empty or null, create a baseline
    if(-not $BeforeUpdates -or $BeforeUpdates.Count -eq 0) {
        Write-Logfile -logFunction $logFunction -logText "Creating baseline for $Computer"
        return
    }
    
    # Create hashtable of before updates for faster lookup
    $beforeHash = @{}
    foreach($update in $BeforeUpdates) {
        $beforeHash[$update.UpdateId] = $update
    }
    
    # Find newly installed updates
    $newlyInstalled = @()
    $failedUpdates = @()
    
    foreach($afterUpdate in $AfterUpdates) {
        if(-not $beforeHash.ContainsKey($afterUpdate.UpdateId)) {
            # This is a new update that wasn't in the before list
            if($afterUpdate.Result -eq "Success") {
                $newlyInstalled += $afterUpdate
            } elseif($afterUpdate.Result -eq "Failed") {
                $failedUpdates += $afterUpdate
            }
        }
    }
    
    # Create journal entries for new installations
    if($newlyInstalled.Count -gt 0) {
        Write-Logfile -logFunction $logFunction -logText "$($newlyInstalled.Count) new updates installed on $Computer"
        
        # Create summary journal entry
        $summaryComment = "Windows Updates installed: $($newlyInstalled.Count) updates`n"
        $summaryComment += "Updates: $($newlyInstalled.Title -join ', ')"
        New-JournalEntry -Computer $Computer -Comment $summaryComment -Kind "success"
        
        # Optionally create individual entries for each update
        if($WUconfig.CreateDetailedJournalEntries) {
            foreach($update in $newlyInstalled) {
                $detailComment = "Update installed: $($update.Title)`nProduct: $($update.Product)`nDate: $($update.Date)"
                New-JournalEntry -Computer $Computer -Comment $detailComment -Kind "success"
            }
        }
    }
    
    # Log failed updates if any
    if($failedUpdates.Count -gt 0) {
        Write-Logfile -logFunction $logFunction -logText "$($failedUpdates.Count) updates failed on $Computer"
        $failedComment = "Failed Windows Updates: $($failedUpdates.Count) updates`n"
        $failedComment += "Failed updates: $($failedUpdates.Title -join ', ')"
        New-JournalEntry -Computer $Computer -Comment $failedComment -Kind "danger"
    }
    
    # If no changes
    if($newlyInstalled.Count -eq 0 -and $failedUpdates.Count -eq 0) {
        Write-Logfile -logFunction $logFunction -logText "No new updates installed on $Computer"
        New-JournalEntry -Computer $Computer -Comment "No new Windows Updates were installed during this maintenance window" -Kind "info"
    }
}

# Modified function to collect before and after updates
function Invoke-WUUpdateInstallation() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)][string]$Computer,
        [parameter(mandatory = $false)][switch]$CreateSnapshot = $true
    )
    
    $logFunction = "Invoke-WUUpdateInstallation"
    
    Write-Logfile -logFunction $logFunction -logText "Starting update installation process for $Computer"
    
    # Check if computer is online
    if(-not (Test-Connection -ComputerName $Computer -Count 2 -Quiet)) {
        Write-Logfile -logFunction $logFunction -logText "Computer $Computer is offline"
        New-JournalEntry -Computer $Computer -Comment "Computer is offline, updates cannot be installed" -Kind "warning"
        return
    }
    
    # Get installed updates before installation
    Write-Logfile -logFunction $logFunction -logText "Collecting installed updates before installation for $Computer"
    $beforeUpdates = Get-WUInstalledUpdates -Computer $Computer
    
    # Create VMware snapshot if needed
    if($CreateSnapshot -and $WUconfig.vmwareSnapshots) {
        Write-Logfile -logFunction $logFunction -logText "Creating snapshot before updates for $Computer"
        Set-WUVMWareSnapshots -Computers @($Computer)
    }
    
    # Install updates
    Write-Logfile -logFunction $logFunction -logText "Installing updates on $Computer"
    Set-WUWindowsUpdatesScheduledTask -Computer $Computer -Reboot $true
    
    # Wait for installation to complete (you might want to implement a better waiting mechanism)
    Start-Sleep -Seconds 300
    
    # Check if computer is back online after reboot
    $maxRetries = 12
    $retryCount = 0
    $computerOnline = $false
    
    while($retryCount -lt $maxRetries -and -not $computerOnline) {
        Start-Sleep -Seconds 30
        $computerOnline = Test-Connection -ComputerName $Computer -Count 2 -Quiet
        $retryCount++
    }
    
    if($computerOnline) {
        # Get installed updates after installation
        Write-Logfile -logFunction $logFunction -logText "Collecting installed updates after installation for $Computer"
        $afterUpdates = Get-WUInstalledUpdates -Computer $Computer
        
        # Compare and create journal entries
        Compare-AndLogUpdates -Computer $Computer -BeforeUpdates $beforeUpdates -AfterUpdates $afterUpdates
    } else {
        Write-Logfile -logFunction $logFunction -logText "Computer $Computer did not come back online after updates"
        New-JournalEntry -Computer $Computer -Comment "Computer did not come back online after update installation" -Kind "danger"
    }
}

function Write-Logfile() {
    param (
        [string]$logFunction,
        [string]$logText
     )
    "$(get-date -Format 'dd/MM/yyyy HH:mm:ss') - $($logFunction) - $($logText)" | Out-File $WUconfig.logFile -Append
}

function Write-ApprovalLogfile() {
    param (
        [string]$logText
    )

    $today = Get-Date -Format('ddMMyyyy')
    $approvalLogFile = "log\" + $today + "_approval_log.txt"

    "$(get-date -Format 'dd/MM/yyyy HH:mm:ss') $($logText)" | Out-File $approvalLogFile -Append
}

function Start-WUApproval() {
    #Get updates that needs approval
    Write-ApprovalLogfile -logText "Start Windows Updates approval"
    $updatesToApprove = Get-WsusUpdate -Classification Security -Approval Unapproved

    #If needed, approved the updates
    if($updatesToApprove.count -gt 0) {
        foreach($updateToApprove in $updatesToApprove) {
            if(($updateToApprove.Products -match "Server") -or ($updateToApprove.Products -match "Windows Server") -or ($updateToApprove.Products -match "Exchange") -or ($updateToApprove.Products -match "SQL Server")) {
                foreach($targetGroup in $WUconfig.targetGroupsServers) {
                    Approve-WsusUpdate -Update $updateToApprove -TargetGroupName $targetGroup -Action Install
                    Write-ApprovalLogfile -logText "Approved update $($updateToApprove.Update.Title) for target group $targetGroup"
                }        
            } elseif($updateToApprove.Products -match "Windows 10") {
                foreach($targetGroup in $WUconfig.targetGroupsClients) {                
                    Approve-WsusUpdate -Update $updateToApprove -TargetGroupName $targetGroup -Action Install
                    Write-ApprovalLogfile -logText "Approved update $($updateToApprove.Update.Title) for target group $targetGroup"
                }        
            } else {
                Write-ApprovalLogfile -logText "No target group found for update $($updateToApprove.Update.Title)"
            }
        }
    }
}

function Restart-WUComputers() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)][string[]]$Computers
    ) 

    $logFunction = "Restart-WUComputers"
        
    foreach ($Computer in $Computers) {        
        Write-Logfile -logFunction $logFunction -logText "Restart computer $Computer"

        # Test if computer is online
        if (Test-Connection -ComputerName $Computer) {                           
            $Credential = New-Object System.Management.Automation.PsCredential($WUconfig.scheduledTaskUsername, $WUconfig.scheduledTaskPassword)   
            Start-Job -Name "Restart $($Computer)" -ScriptBlock { Restart-Computer -ComputerName $args[0] -Wait -For PowerShell -Protocol WSMAN -Force -Timeout 900 } -ArgumentList $Computer, $Credential                                                                            
            New-JournalEntry -Computer $Computer -Comment "Restarted computer $($Computer)" -Kind "info"
                                                                                       
        } 
        else { 
            Write-Logfile -logFunction $logFunction -logText "Computer $Computer is offline"
            New-JournalEntry -Computer $Computer -Comment "Computer $($Computer) is offline" -Kind "warning"
        }
    }   
        
    do {            
        Start-Sleep -Seconds 20
    } while ((Get-Job | Where-Object { ($_.Name -like "Restart*") -and (($_.State -like "Running") -or ($_.State -like "Stopping"))}).Count -gt 0)

    # Completed jobs
    Get-Job | Where-Object { ($_.Name -like "Restart*") -and ($_.State -like "Completed")} | ForEach-Object {        
        Write-Logfile -logFunction $logFunction -logText "$($_.Name) is succeeded"
        New-JournalEntry -Computer $Computer -Comment "$($_.Name) is succeeded" -Kind "success"
    }

    # Failed jobs
    Get-Job | Where-Object { ($_.Name -like "Restart*") -and ($_.State -like "Failed")} | ForEach-Object {
        $RestartError = Receive-Job -Id $_.Id        
        Write-Logfile -logFunction $logFunction -logText "$($_.Name) has failed - $RestartError "
        New-JournalEntry -Computer $Computer -Comment "$($_.Name) has failed - $RestartError" -Kind "danger"
    }

    # Remove the jobs
    Get-Job | Where-Object { ($_.Name -like "Restart*")} | Remove-Job
}

function Get-WUPendingUpdates() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)][string]$Computer
    )

    $logFunction = "Get-WUPendingUpdates"
    
    Write-Logfile -logFunction $logFunction -logText "Checking for pending updates on computer $($Computer)"
    if(Test-Connection -ComputerName $Computer -Count 1) {        
        $pendingUpdates = Invoke-Command -ComputerName $Computer -ScriptBlock {
            $updateSearcher = New-Object -ComObject Microsoft.Update.Searcher         
            $searchResult = $updateSearcher.Search("IsInstalled=0").Updates            
            $searchResult                            
            
        } -AsJob

        $pendingUpdates | Wait-Job -Timeout 60 | out-null
        $pendingUpdates = $pendingUpdates | Receive-Job

        if($pendingUpdates -isnot [array]) {
            $pendingUpdates = @($pendingUpdates)
        }

        $count = $pendingUpdates.count

        Write-Logfile -logFunction $logFunction -logText "$($count) update(s) found on computer $($Computer)"
        New-JournalEntry -Computer $Computer -Comment "$($count) update(s) pending on computer $($Computer)" -Kind "info"

        return $pendingUpdates
    }
}

function Get-WUInstalledUpdates() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)][string]$Computer
    )

    $logFunction = "Get-WUInstalledUpdates"
    
    Write-Logfile -logFunction $logFunction -logText "Collecting installed updates on computer $($Computer)"
    if(Test-Connection -ComputerName $Computer -Count 1) {
        $installedUpdates =  Invoke-Command -ComputerName $Computer -ScriptBlock {
            $session = (New-Object -ComObject 'Microsoft.Update.Session')
            $history = $session.QueryHistory("",0,50)            

            $convertedInstalledUpdates = @()

            foreach($installedUpdate in $history) {
                if($installedUpdate.ResultCode -eq 2) {
                    $Result = "Success"
                } else {
                    $Result = "Failed"
                }
                $Product = $installedUpdate.Categories | Where-Object { $_.Type -eq 'Product' } | Select-Object -First 1 -ExpandProperty Name
                $convertedInstalledUpdate = New-Object PSObject
                $convertedInstalledUpdate | Add-Member -MemberType NoteProperty -Value $Result -Name Result
                $convertedInstalledUpdate | Add-Member -MemberType NoteProperty -Value $installedUpdate.Title -Name Title
                $convertedInstalledUpdate | Add-Member -MemberType NoteProperty -Value $installedUpdate.Date -Name Date
                $convertedInstalledUpdate | Add-Member -MemberType NoteProperty -Value $env:COMPUTERNAME -Name Computer                
                $convertedInstalledUpdate | Add-Member -MemberType NoteProperty -Value $installedUpdate.UpdateIdentity.UpdateId -Name UpdateId
                $convertedInstalledUpdate | Add-Member -MemberType NoteProperty -Value $installedUpdate.UpdateIdentity.RevisionNumber -Name RevisionNumber
                $convertedInstalledUpdate | Add-Member -MemberType NoteProperty -Value $Product -Name Product
                $convertedInstalledUpdates += $convertedInstalledUpdate           
            } 
            Write-Output $convertedInstalledUpdates
        } -AsJob

        $installedUpdates | Wait-Job -Timeout 60 | out-null
        $installedUpdates = $installedUpdates | Receive-Job   
        
        $count = $installedUpdates.count 
        
        Write-Logfile -logFunction $logFunction -logText "$($count) installed update(s) found on computer $($Computer)"    
        
        return $installedUpdates
    }
}

function Get-WUUpdateWindows() {

    $maintenanceWindows = Import-Csv $WUconfig.maintenanceWindowsCSV | Where-Object { $_.Enabled -eq "True" }

    return $maintenanceWindows

}

function Get-WUUpdateWindow() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $false)][switch]$PreCare,
        [parameter(mandatory = $false)][switch]$AfterCare
    )

    $logFunction = "Get-WUUpdateWindow"
    $maintenanceWindows = Import-Csv $WUconfig.maintenanceWindowsCSV | Where-Object { $_.Enabled -eq "True" }

    foreach($maintenanceWindow in $maintenanceWindows) {
        $patchTuesday = Get-WUDay -weekDay Tuesday -findNthDay 2 -Hour "0"
        $currentDayTime = Get-Date -Minute 00 -Second 00

        if($patchTuesday -gt $currentDayTime) {
            $patchTuesday = Get-WUDay -weekDay Tuesday -findNthDay 2 -Hour "0" -DateToStartFrom $currentDayTime.AddMonths(-1).ToString("MM/01")
        }
        
        $maintenanceWindowDayTime = Get-WUDay -weekDay $maintenanceWindow.DayOfWeek -findNthDay $maintenanceWindow.nThDay -Hour $maintenanceWindow.Hour.substring(0,2) -DateToStartFrom $patchTuesday.toString("MM/dd")        

        if($PreCare) {
            $currentDayTime = (Get-Date -Minute 00 -Second 00).AddHours($WUconfig.PreCareHours)
        }

        if($AfterCare) {
            $currentDayTime = (Get-Date -Minute 00 -Second 00).AddHours($WUconfig.AfterCareHours)
        }

        if($maintenanceWindowDayTime.ToString() -eq $currentDayTime.ToString()) {
            return $maintenanceWindow
        }
    }
}

function Get-WUComputersForMaintenanceWindow() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)]$MaintenanceWindow
    )

    $logFunction = "Get-WUComputersForMaintenanceWindow"

    $groupMembers = Get-ADGroupMember -Identity $MaintenanceWindow.SecurityGroup

    $computersForMaintenanceWindow = @()

    foreach($groupMember in $groupMembers) {
        $computersForMaintenanceWindow += $groupMember.name
    }

    return $computersForMaintenanceWindow
}

function Set-WUWindowsUpdatesScheduledTask() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)][string]$Computer,
        [parameter(mandatory = $true)][boolean]$Reboot = $false
    )

    $logFunction = "Set-WUWindowsUpdatesScheduledTask"

    $updateScript = Get-Content ".\WindowsUpdateInstaller.ps1"

    Invoke-Command -ComputerName $Computer -ErrorVariable $InvokeError -ArgumentList $WUconfig.scheduledTaskUsername, $WUconfig.scheduledTaskPassword, $updateScript, $Reboot -ScriptBlock {
        $logPath = "c:\temp"
        if (Test-Path -Path $logPath) {
            Write-Verbose "Path already exists."        
        }
        else {
            Write-Verbose "Create directory $logPath"    
            New-Item -Path $logPath -ItemType Directory -Force         
        } 

        Unregister-ScheduledTask -TaskName "WindowsUpdateInstaller" -Confirm:$false

        Set-Content -Value $args[2] -Path "C:\temp\WindowsUpdateInstaller.ps1"

        if($args[3]) {
            $script = "-ExecutionPolicy Bypass -file C:\Temp\WindowsUpdateInstaller.ps1 -Reboot"
            
        } else {
            $script = "-ExecutionPolicy Bypass -file C:\Temp\WindowsUpdateInstaller.ps1"
        }
        
        $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument $script
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(30)
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3)

        Register-ScheduledTask -TaskName "WindowsUpdateInstaller" -Action $action -Trigger $trigger -Settings $settings -User $args[0] -Password $args[1] -RunLevel Highest
    }


}

function Start-WUWindowsUpdatesSchedule() {

    $logFunction = "Start-WUWindowsUpdatesSchedule"

    Write-Logfile -logFunction $logFunction -logText "Starting WUWindowsUpdatesSchedule"

    #Check for windows update window
    Write-Logfile -logFunction $logFunction -logText "Checking for windows update window"
    $maintenanceWindow = Get-WUUpdateWindow

    #Start Windows Updates if maintenance window
    if($maintenanceWindow) {
        Write-Logfile -logFunction $logFunction -logText "Windows update window $($maintenanceWindow.Name) found."

        #Get computers to update for current maintenance window
        Write-Logfile -logFunction $logFunction -logText "Checking for computers in windows update window $($maintenanceWindow.Name)"
        $computersToUpdate = Get-WUComputersForMaintenanceWindow -maintenanceWindow $maintenanceWindow
        Write-Logfile -logFunction $logFunction -logText "$($computersToUpdate) will be updated"

        # Store before-update states
        $beforeUpdateStates = @{}
        foreach($computer in $computersToUpdate) {
            Write-Logfile -logFunction $logFunction -logText "Collecting pre-update state for $computer"
            $beforeUpdateStates[$computer] = Get-WUInstalledUpdates -Computer $computer
        }

        #Reboot all computers prior to Windows Updates
        Restart-WUComputers $computersToUpdate

        #Create VMWare snapshots if needed
        if($WUconfig.vmwareSnapshots) {
            Set-WUVMWareSnapshots -Computers $computersToUpdate
        }

        #Start Windows Updates for all computers
        foreach($computer in $computersToUpdate) {
            #TODO: check if computer is online
            Write-Logfile -logFunction $logFunction -logText "Creating Windows Update Scheduled Task for computer $($computer)"
            Set-WUWindowsUpdatesScheduledTask -Computer $computer -Reboot $true
            Write-Logfile -logFunction $logFunction -logText "Windows Update Scheduled Task for computer $($computer) created"
        }
        
        # Wait for updates to complete (adjust timing as needed)
        Write-Logfile -logFunction $logFunction -logText "Waiting for updates to complete..."
        Start-Sleep -Seconds 1800 # 30 minutes
        
        # Collect after-update states and create journal entries
        foreach($computer in $computersToUpdate) {
            if(Test-Connection -ComputerName $computer -Count 2 -Quiet) {
                Write-Logfile -logFunction $logFunction -logText "Collecting post-update state for $computer"
                $afterUpdates = Get-WUInstalledUpdates -Computer $computer
                Compare-AndLogUpdates -Computer $computer -BeforeUpdates $beforeUpdateStates[$computer] -AfterUpdates $afterUpdates
            } else {
                Write-Logfile -logFunction $logFunction -logText "Computer $computer is offline after updates"
                New-JournalEntry -Computer $computer -Comment "Computer is offline after update installation" -Kind "danger"
            }
        }
    }
}

function Get-WUDay {
  [CmdletBinding()]
  Param
  (
    [Parameter(position = 0)]
    [ValidateSet("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")]
    [String]$weekDay = 'Tuesday',
    [ValidateRange(0, 5)]
    [Parameter(position = 1)]
    [int]$findNthDay = 2,
    [Parameter(position = 2)]
    [int]$Hour = 3,
    [Parameter(position = 3)]
    [String]$DateToStartFrom = 0
  )
  # Get the date and find the first day of the month
  # Find the first instance of the given weekday
  [datetime]$today = [datetime]::NOW
  $todayM = $today.Month.ToString()
  $todayY = $today.Year.ToString()
  if($DateToStartFrom -ne 0) {
    [datetime]$strtMonth = $DateToStartFrom + '/' + $todayY
  } else {
    [datetime]$strtMonth = $todayM + '/1/' + $todayY
  }  
  $strtMonth = $strtMonth.AddHours($Hour)
  while ($strtMonth.DayofWeek -ine $weekDay ) { $strtMonth = $StrtMonth.AddDays(1) }
  $firstWeekDay = $strtMonth

  # Identify and calculate the day offset
  if ($findNthDay -eq 1) {
    $dayOffset = 0
  }
  else {
    $dayOffset = ($findNthDay - 1) * 7
  }
  
  # Return date of the day/instance specified
  $patchTuesday = $firstWeekDay.AddDays($dayOffset).AddDays($DaysToAdd)
  return $patchTuesday
}

function Set-WUPendingUpdatesForMaintenanceWindowByMail() {

    $logFunction = "Set-WUPendingUpdatesForMaintenanceWindowByMail"

    Write-Logfile -logFunction $logFunction -logText "Starting WUPendingUpdatesForMaintenanceWindowByMail"

    #Check for windows update window
    Write-Logfile -logFunction $logFunction -logText "Checking for windows update window"
    $maintenanceWindow = Get-WUUpdateWindow -PreCare

    #Start Windows Updates if maintenance window
    if($maintenanceWindow) {
        Write-Logfile -logFunction $logFunction -logText "Checking for computers in windows update window $($maintenanceWindow.Name)"
        $computersToUpdate = Get-WUComputersForMaintenanceWindow -maintenanceWindow $maintenanceWindow

        #Collect pending updates for all computers
        $pendingUpdatesForComputers = @()

        foreach($computer in $computersToUpdate) {
            [array]$pendingUpdatesForComputer = Get-WUPendingUpdates -Computer $computer
            $convertedUpdates = @()
            if($pendingUpdatesForComputer.count -gt 0) {
                foreach($pendingUpdate in $pendingUpdatesForComputer) {
                    $convertedUpdate = New-Object PSObject
                    $convertedUpdate | Add-Member -MemberType NoteProperty -Value $computer -Name Computer
                    $convertedUpdate | Add-Member -MemberType NoteProperty -Value $pendingUpdate.Title -Name Title
                    $pendingUpdatesForComputers += $convertedUpdate
                    $convertedUpdates += $convertedUpdate                    
                }

                $inventoryObject = $inventory | Where-Object { $_.Name -eq $computer }

                if(($inventoryObject -ne $null) -and ($inventoryObject.BusinessContact -ne '')) {                        
                    $body = Set-WUHtmlForUpdateMail -Data $convertedUpdates -Title "Pending Windows Updates" -Text "Below you can find the updates that will be installed today at $($maintenanceWindow.Hour) on $computer"
                    Write-Logfile -logFunction $logFunction -logText "Send mail to $($inventoryObject.BusinessContact ) with updates that will be installed for maintenance window $($maintenanceWindow.Name)"
                    Send-MailMessage -From $WUconfig.mailFrom -To $inventoryObject.BusinessContact.Split(';') -SmtpServer $WUconfig.mailServer -BodyAsHtml $body -Subject "Windows Updates to be installed"
                }
            } else {
                $noUpdate = New-Object PSObject
                $noUpdate | Add-Member -MemberType NoteProperty -Value $computer -Name Computer
                $noUpdate | Add-Member -MemberType NoteProperty -Value "No updates found" -Name Title
                $pendingUpdatesForComputers += $noUpdate
            }
        }

        $body = $pendingUpdatesForComputers | ConvertTo-Html -PreContent "The following updates will be installed later today<br><br>" | Out-String

        $body = Set-WUHtmlForUpdateMail -Data $pendingUpdatesForComputers -Title "Pending Windows Updates" -Text "Below you can find the updates that will be installed later today for maintenance window $($maintenanceWindow.Name)"
        
        Write-Logfile -logFunction $logFunction -logText "Send mail to $($WUconfig.mailTo) with updates that will be installed for maintenance window $($maintenanceWindow.Name)"
        Send-MailMessage -From $WUconfig.mailFrom -To $WUconfig.mailTo -SmtpServer $WUconfig.mailServer -BodyAsHtml $body -Subject "Windows Updates to be installed"
    } else {
        Write-Logfile -logFunction $logFunction -logText "No windows update window found"
    }
}

function Set-WUInstalledUpdatesForMaintenanceWindowByMail() {
    
    $logFunction = "Set-WUInstalledUpdatesForMaintenanceWindowByMail"

    Write-Logfile -logFunction $logFunction -logText "Starting WUInstalledUpdatesForMaintenanceWindowByMail"

    #Check for windows update window
    Write-Logfile -logFunction $logFunction -logText "Checking for windows update window"
    $maintenanceWindow = Get-WUUpdateWindow -AfterCare

    #Start Windows Updates if maintenance window
    if($maintenanceWindow) {
        Write-Logfile -logFunction $logFunction -logText "Checking for computers in windows update window $($maintenanceWindow.Name)"
        $computersToCheck = Get-WUComputersForMaintenanceWindow -maintenanceWindow $maintenanceWindow

        #Collect installed updates for all computers
        $installedUpdatesForComputers = @()

        foreach($computer in $computersToCheck) {
            [array]$installedUpdatesForComputer = Get-WUInstalledUpdates -Computer $computer      
            $installedUpdatesForComputers += $installedUpdatesForComputer
            
        }

        $installedUpdatesForComputers = $installedUpdatesForComputers | Where-Object {$_.Date -gt (Get-Date -Hour 0 -Minute 0).AddDays(-1) } | Select-Object Computer,Date,Result,Title

        $body = Set-WUHtmlForUpdateMail -Data $installedUpdatesForComputers -Title "Windows Update Report" -Text "Below you can find the result for maintenance window $($maintenanceWindow.Name)"
        
        Write-Logfile -logFunction $logFunction -logText "Send mail to $($WUconfig.mailTo) with the update report for maintenance window $($maintenanceWindow.Name)"
        Send-MailMessage -From $WUconfig.mailFrom -To $WUconfig.mailTo -SmtpServer $WUconfig.mailServer -BodyAsHtml $body -Subject "Windows Updates report for maintenance window $($maintenanceWindow.Name)"
    }
}

function Set-WUVMWareSnapshots() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)][string[]]$Computers
    )

    $logFunction = "Set-WUVMWareSnapshots"

    foreach ($vmwareVCenter in $WUconfig.vmwareVCenters) {
        Write-Logfile -logFunction $logFunction -logText "Connecting to vcenter $($vmwareVCenter)"
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DefaultVIServerMode Single -InformationAction Continue -Confirm:$false

        $connection = Connect-VIServer -Server $vmwareVCenter -User $WUconfig.vmwareVCenterUser -Password $WUconfig.vmwareVCenterPassword    
        
        if($connection.IsConnected) {

            Write-Logfile -logFunction $logFunction -logText "Connected to vcenter $($vmwareVCenter)"

            foreach ($Computer in $Computers) {
                Write-Logfile -logFunction $logFunction -logText "Create snapshot for $($Computer)"
                New-Snapshot -Name $WUconfig.vmwareSnapshotName -VM $Computer
            }

            Disconnect-VIServer -Server $vmwareVCenter -Confirm:$false
        } else {
            Write-Logfile -logFunction $logFunction -logText "Error connecting vcenter $($vmwareVCenter)"
        }     
    }   
}

function Set-WUVMWareSnapshots_v2() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)][string[]]$Computers
    )

    $logFunction = "Set-WUVMWareSnapshots"

    foreach ($vmwareVCenter in $WUconfig.vmwareVCenters) {
        
        $connection = Connect-VIServer -Server $vmwareVCenter -User $WUconfig.vmwareVCenterUser -Password $WUconfig.vmwareVCenterPassword
        
        if($connection.IsConnected) {
            Write-Logfile -logFunction $logFunction -logText "Connected to vcenter $($vmwareVCenter)"            
        } else {
            Write-Logfile -logFunction $logFunction -logText "Error connecting vcenter $($vmwareVCenter)"
        }     
    }

    foreach ($Computer in $Computers) {

        $inventoryObject = $inventory | Where-Object { $_.Name -eq $computer }

        if(($inventoryObject -ne $null) -and ($inventoryObject.VCenter -ne '') -and ($inventoryObject.Virtual -eq 'True')) {    
            Write-Logfile -logFunction $logFunction -logText "Create snapshot for $($Computer) on VCenter $($inventoryObject.VCenter)"
            New-Snapshot -Name $WUconfig.vmwareSnapshotName -VM $Computer -Server $inventoryObject.VCenter
        }        
    }

    foreach ($vmwareVCenter in $WUconfig.vmwareVCenters) {
        Write-Logfile -logFunction $logFunction -logText "Disconnect to vcenter $($vmwareVCenter)"     
        Disconnect-VIServer -Server $vmwareVCenter -Confirm:$false                   
    }
}

function Remove-WUVMWareSnapshots() {    

    $logFunction = "Remove-WUVMWareSnapshots"    

    foreach($vmwareVCenter in $WUconfig.vmwareVCenters) {
        Write-Logfile -logFunction $logFunction -logText "Connecting to vcenter $($vmwareVCenter)"
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DefaultVIServerMode Single -InformationAction Continue -Confirm:$false

        Connect-VIServer -Server $vmwareVCenter -User $WUconfig.vmwareVCenterUser -Password $WUconfig.vmwareVCenterPassword
        Write-Logfile -logFunction $logFunction -logText "Connected to vcenter $($vmwareVCenter)"

        Write-Logfile -logFunction $logFunction -logText "Collecting WUWindowsUpdate snapshots older then $($WUconfig.vmwareSnapshotAgeInDays) days"
        $snapshots = Get-VM | Get-Snapshot | Where-Object { $_.Created -lt (Get-Date).AddDays((-1 * $WUconfig.vmwareSnapshotAgeInDays)) } | Where-Object { $_.Name -eq $WUconfig.vmwareSnapshotName }
    
        if($snapshots.count -gt 0) {
            foreach ($snapshot in $snapshots) {
                $vmForSnapshot = $snapshot.VM
                Write-Logfile -logFunction $logFunction -logText "Remove snapshot for $($vmForSnapshot)"
                $snapshot | Remove-Snapshot -Confirm:$false
            }
        } else {
            Write-Logfile -logFunction $logFunction -logText "No snapshots found"
        }            

        Disconnect-VIServer -Server $vmwareVCenter -Confirm:$false        
    }    
}

function Set-WUHtmlForUpdateMail() {
    [CmdletBinding()]    
    param
    ( 
        [parameter(mandatory = $true)]$Data,
        [parameter(mandatory = $true)][string]$Title,
        [parameter(mandatory = $true)][string]$Text
    )

    $htmlHeaders = ""
    $headers = $Data[0] | Get-Member -MemberType NoteProperty | % { $_.Name }

    foreach($header in $headers) {
        $htmlHeaders += "<th>$header</th>"
    }

    $htmlValues = ""

    foreach($dataValue in $Data) {
        $htmlDataValue = "<tr>"
        foreach($value in ($headers | % { $dataValue."$_"})) {
            if($value -eq "Success") {
                $htmlDataValue += "<td style='background-color: green'>$value</td>"
            } elseif($value -eq "Failed") {
                $htmlDataValue += "<td style='background-color: red'>$value</td>"
            } else {
                $htmlDataValue += "<td>$value</td>"
            }
        }
        $htmlDataValue += "</tr>"
        $htmlValues += $htmlDataValue
    }

    $htmlUpdateMail = Get-Content $WUconfig.htmlUpdateMailPath
    $htmlUpdateMail = $htmlUpdateMail.replace('##Title##', $Title)
    $htmlUpdateMail = $htmlUpdateMail.replace('##Text##', $Text)
    $htmlUpdateMail = $htmlUpdateMail.replace('##Headers##', $htmlHeaders)
    $htmlUpdateMail = $htmlUpdateMail.replace('##Values##', $htmlValues)

    return [string]$htmlUpdateMail
}

############################################################
