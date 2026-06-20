####################### VARIABLES ##########################
@{
    # CMDB
    cmdbEnabled = $false

    # Logging
    logFile = ".\log\WindowsUpdates.txt"

    # Maintenance Windows
    maintenanceWindowsCSV = ".\csv\MaintenanceWindows.csv"

    # Inventory
    inventoryCSV = ".\csv\Inventory.csv"

    # Pre and aftercase
    PreCareHours = 6
    AfterCareHours = -6

    # HtmlFiles
    htmlUpdateMailPath = ".\files\UpdateMail.html"

    # Scheduled tasks
    scheduledTaskUsername = "DOMAIN\svc_windowsupdates"
    scheduledTaskPassword = "PASSWORD_HERE"

    # Target Groups
    targetGroupsServers = @("PrePilot","Monthly","DomainControllers")
    targetGroupsClients = @()

    # Mail
    mailServer = "relay-02.domain.com"
    mailFrom = "WUWindowsUpdates@domain.com.be"
    mailTo = @("alain.seys@outlook.com")

    # VMWare
    vmwareSnapshots = $true;
    vmwareVCenter = "vcenter.domain.com"
    vmwareVCenters = @("vcenter.domain.com")
    vmwareVCenterUser = "DOMAIN\svc_windowsupdates"
    vmwareVCenterPassword = "PASSWORD_VCENTER_HERER"
    vmwareSnapshotName = "WUWindowsUpdateSnapshot"
    vmwareSnapshotAgeInDays = 7

    # Netbox
    netboxJournal = $true
    netboxapiToken = "NETBOX_TOKEN"
    CreateDetailedJournalEntries = $true
}
