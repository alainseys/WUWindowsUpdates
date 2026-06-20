# WUWindowsUpdates

Requirements:
- WSUS Installed
- IIS Installed
- Seperate Disk to store the updates
- Active directory groups for the maintance windows(ServersPrePilot, ServersMonthly1, ServersMonthly2 ...)
- Configure Update Service BEFORE using this script

How to use:
- Import the scheduled tasks in "Task Scheduler"
- Set the correct user to execute
- Allow the user to run as batch.

## Config
- csv/MaintanceWindows.csv (list of the maintance windows)
- csv/Inventory.csv (list of the seperate logging)
- inc/Config.ps1 (general config parameters)

## Seperate Logging
To have seperate logging for buisness so they receive a email for example one machine.
Update csv\Inventory.cs and aadd the machine name MaintanceWindow and email for the reporting
