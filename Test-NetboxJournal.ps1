# Test-NetboxJournal.ps1 - Simplified Version
# Standalone script to test Netbox journal entry functionality

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = "AUTOMATE-01",
    
    [Parameter(Mandatory=$false)]
    [string]$TestComment = "Test journal entry from standalone script",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("info", "success", "warning", "danger")]
    [string]$Kind = "info",
    
    [Parameter(Mandatory=$false)]
    [switch]$TestMissingMachine
)

# Netbox configuration
$NetboxUrl = "https://ipam.domain.com.be"
$NetboxToken = "TOKEN_HERE"
$MissingMachinesLog = "C:\SCRIPTS\WUWindowsUpdates\logs\MissingMachines.log"

# Create log directory if it doesn't exist
$logDir = Split-Path $MissingMachinesLog -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Clear-Host
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Netbox Journal Entry Test Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

function Test-NetboxConnection {
    Write-Host "Testing Netbox Connection..." -ForegroundColor Yellow
    try {
        $headers = @{
            "Authorization" = "Token $NetboxToken"
        }
        $statusUrl = "$NetboxUrl/api/status/"
        $response = Invoke-RestMethod -Uri $statusUrl -Headers $headers -ErrorAction Stop
        Write-Host "  ✓ Connected to Netbox successfully" -ForegroundColor Green
        Write-Host "  Netbox Version: $($response.'netbox-version')" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ✗ Failed to connect to Netbox: $_" -ForegroundColor Red
        return $false
    }
}

function Find-ComputerInNetbox {
    param([string]$Computer)
    
    Write-Host "Searching for computer: $Computer" -ForegroundColor Yellow
    
    $headers = @{
        "Authorization" = "Token $NetboxToken"
    }
    
    # Search for Virtual Machine
    try {
        Write-Host "  Checking Virtual Machines..." -ForegroundColor Gray
        $VMUrl = "$NetboxUrl/api/virtualization/virtual-machines/?name=$Computer"
        $VMResponse = Invoke-RestMethod -Uri $VMUrl -Headers $headers -ErrorAction Stop
        
        if($VMResponse.count -gt 0){
            Write-Host "  ✓ Found as Virtual Machine" -ForegroundColor Green
            Write-Host "    ID: $($VMResponse.results[0].id)" -ForegroundColor Green
            Write-Host "    Name: $($VMResponse.results[0].name)" -ForegroundColor Green
            return @{
                Found = $true
                Id = $VMResponse.results[0].id
                Type = "virtualization.virtualmachine"
                Name = $VMResponse.results[0].name
            }
        }
        catch {
        Write-Host "  ✗ Error searching Virtual Machines: $_" -ForegroundColor Red
        # Continue to device search
    }
    }
    catch {
        Write-Host "  ✗ Error searching Virtual Machines: $_" -ForegroundColor Red
        # Continue to device search
    }
    
    # Search for Physical Device
    try {
        Write-Host "  Not found as VM, checking Physical Devices..." -ForegroundColor Gray
        $DeviceUrl = "$NetboxUrl/api/dcim/devices/?name=$Computer"
        $DeviceResponse = Invoke-RestMethod -Uri $DeviceUrl -Headers $headers -ErrorAction Stop
        
        if($DeviceResponse.count -gt 0){
            Write-Host "  ✓ Found as Physical Device" -ForegroundColor Green
            Write-Host "    ID: $($DeviceResponse.results[0].id)" -ForegroundColor Green
            Write-Host "    Name: $($DeviceResponse.results[0].name)" -ForegroundColor Green
            return @{
                Found = $true
                Id = $DeviceResponse.results[0].id
                Type = "dcim.device"
                Name = $DeviceResponse.results[0].name
            }
        }
    }
    catch {
        Write-Host "  ✗ Error searching Physical Devices: $_" -ForegroundColor Red
    }
    
    # Not found
    Write-Host "  ✗ Computer NOT found in Netbox" -ForegroundColor Red
    return @{ Found = $false }
}

function Create-JournalEntry {
    param(
        $ComputerInfo,
        [string]$Comment,
        [string]$Kind
    )
    
    Write-Host ""
    Write-Host "Creating journal entry..." -ForegroundColor Yellow
    
    $JournalEntry = @{
        "assigned_object_id" = $ComputerInfo.Id
        "assigned_object_type" = $ComputerInfo.Type
        "comments" = $Comment
        "kind" = $Kind
    }
    
    $Body = $JournalEntry | ConvertTo-Json
    Write-Host "Payload: $Body" -ForegroundColor Gray
    
    $headers = @{
        "Authorization" = "Token $NetboxToken"
        "Content-Type" = "application/json"
    }
    
    try {
        $Response = Invoke-RestMethod -Uri "$NetboxUrl/api/extras/journal-entries/" -Method Post -Headers $headers -Body $Body -ErrorAction Stop
        Write-Host "  ✓ Journal entry created successfully!" -ForegroundColor Green
        Write-Host "    Entry ID: $($Response.id)" -ForegroundColor Green
        Write-Host "    Created: $($Response.created)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ✗ Failed to create journal entry" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        if($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd()
            Write-Host "    Response Body: $responseBody" -ForegroundColor Red
        }
        return $false
    }
}catch {
        Write-Host "  ✗ Error searching Virtual Machines: $_" -ForegroundColor Red
        # Continue to device search
    }

function LogMissingMachine {
    param([string]$Computer)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - Computer '$Computer' not found in Netbox (VM or Device)"
    $logEntry | Out-File $MissingMachinesLog -Append
    Write-Host "  Logged to: $MissingMachinesLog" -ForegroundColor Yellow
}

# Main execution
Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  Computer: $ComputerName" -ForegroundColor White
Write-Host "  Comment: $TestComment" -ForegroundColor White
Write-Host "  Kind: $Kind" -ForegroundColor White
Write-Host "  Log File: $MissingMachinesLog" -ForegroundColor White
Write-Host ""

# Test Netbox connection first
if (-not (Test-NetboxConnection)) {
    Write-Host "Cannot proceed without Netbox connection. Exiting." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "-------------------------------------" -ForegroundColor Cyan

if($TestMissingMachine) {
    Write-Host "Testing Missing Machine Scenario..." -ForegroundColor Magenta
    $testComputer = "NonExistentComputer123"
    Write-Host "Using computer: $testComputer" -ForegroundColor Magenta
    
    $result = Find-ComputerInNetbox -Computer $testComputer
    if (-not $result.Found) {
        LogMissingMachine -Computer $testComputer
    }
    
    Write-Host ""
    Write-Host "Content of missing machines log:" -ForegroundColor Yellow
    if (Test-Path $MissingMachinesLog) {
        Get-Content $MissingMachinesLog -Tail 5
    } else {
        Write-Host "  Log file not created yet" -ForegroundColor Gray
    }
}
else {
    # Normal test - find computer and create journal entry
    $computerInfo = Find-ComputerInNetbox -Computer $ComputerName
    
    if ($computerInfo.Found) {
        Create-JournalEntry -ComputerInfo $computerInfo -Comment $TestComment -Kind $Kind
    }
    else {
        Write-Host ""
        Write-Host "Would you like to log this missing machine? (Y/N)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq 'Y' -or $response -eq 'y') {
            LogMissingMachine -Computer $ComputerName
        }
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
