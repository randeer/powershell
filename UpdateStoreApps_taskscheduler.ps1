<#
.DESCRIPTION
    Script will uninstall Sophos Endpoint agent

.SCRIPT VERSION 
    1.4 (Updated for Task Scheduler compatibility)

.NAME 
    Uninstall_Sophos.ps1

.AUTHOR
    Randeer Lalanga & Azaam Basheer

.DEPARTMENT 
    Centralized Services | Strategic Technology Solutions

.DEVELOPED ON 
    12/18/2024
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Log file location
$logFolder = "C:\Temp"
$logFile = "$logFolder\WingetUpdateLog.txt"

# Ensure the log folder exists
if (-not (Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# Log function
function Log {
    $message = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($args -join ' ')"
    Add-Content -Path $logFile -Value $message
}

# Find Winget executable
write-host "Searching for Winget executable..." -ForegroundColor Cyan
$wingetPath = Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -Filter "winget.exe" | 
    Sort-Object FullName -Descending | 
    Select-Object -First 1 -ExpandProperty FullName

if (-not $wingetPath) {
    write-host "ERROR: Winget executable not found!" -ForegroundColor Red
    Log "Winget executable not found!"
    exit 1
}

write-host "Winget executable found at: $wingetPath" -ForegroundColor Green

# Start logging
Log "Script execution started."
Log "Using Winget path: $wingetPath"

try {
    # Updating Winget source
    write-host "Updating Winget source..." -ForegroundColor Cyan
    Log "Updating Winget source..."
    & $wingetPath source update
    write-host "Winget source update completed." -ForegroundColor Green
    Log "Winget source update completed."

    # Checking for available upgrades
    write-host "Checking for available upgrades..." -ForegroundColor Cyan
    Log "Checking for available upgrades..."
    $upgrades = & $wingetPath upgrade --include-unknown 2>&1
    Log "Raw Upgrade Output: $upgrades"

    if ($upgrades -match "No available upgrades found.") {
        write-host "No upgrades available." -ForegroundColor Yellow
        Log "No upgrades available."
    } else {
        write-host "Available upgrades found:" -ForegroundColor Green
        write-host $upgrades

        # Automatically updating available upgrades without popups
        write-host "Updating all identified packages quietly..." -ForegroundColor Cyan
        Log "Starting silent automatic update for all packages."

        $upgradeResult = & $wingetPath upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --silent 2>&1

        if ($upgradeResult -match "No installed package found matching input criteria") {
            write-host "No matching packages were found for update." -ForegroundColor Yellow
            Log "No matching packages were found for update."
        } elseif ($upgradeResult -match "Error") {
            write-host "Errors occurred during the update process:" -ForegroundColor Red
            write-host $upgradeResult
            Log "Errors during update process: $upgradeResult"
            exit 1
        } else {
            write-host "Packages updated successfully without triggering popups." -ForegroundColor Green
            Log "Package updates completed successfully and silently: $upgradeResult"
        }
    }

    # Repair Microsoft Store registration
    write-host "Repairing Microsoft Store registration..." -ForegroundColor Cyan
    Log "Repairing Microsoft Store registration..."

    $registrationErrors = 0
    $successfulRegistrations = 0

    # Improved filtering and registration approach
    Get-ChildItem "C:\Program Files\WindowsApps\" -Recurse -Filter "AppxManifest.xml" | 
    Where-Object { $_.DirectoryName -notlike "*\*\*" } | # Avoid nested directories
    ForEach-Object {
        try {
            $manifestPath = $_.FullName
            $packageDirectory = $_.Directory.FullName

            write-host "Attempting to register: $manifestPath" -ForegroundColor Cyan
            $result = Start-Process powershell -ArgumentList "Add-AppxPackage -Register '$manifestPath' -ErrorAction Stop" -Wait -PassThru -NoNewWindow

            if ($result.ExitCode -eq 0) {
                $successfulRegistrations++
                write-host "Successfully registered: $manifestPath" -ForegroundColor Green
                Log "Successfully registered: $manifestPath"
            } else {
                $registrationErrors++
                write-host "Failed to register: $manifestPath (Exit Code: $($result.ExitCode))" -ForegroundColor Red
                Log "Failed to register: $manifestPath (Exit Code: $($result.ExitCode))"
            }
        } catch {
            $registrationErrors++
            write-host "Error re-registering app: $manifestPath" -ForegroundColor Red
            write-host "Error details: $_" -ForegroundColor Red
            Log "Error re-registering app: $manifestPath. Error: $_"
        }
    }

    # Summary of registration results
    write-host "`nRegistration Summary:" -ForegroundColor Cyan
    write-host "Successful Registrations: $successfulRegistrations" -ForegroundColor Green
    write-host "Failed Registrations: $registrationErrors" -ForegroundColor Red

    # Completion
    write-host "Script execution completed!" -ForegroundColor Green
    Log "Script execution completed successfully."
    exit 0

} catch {
    # Catch any unhandled errors
    write-host "An unexpected error occurred:" -ForegroundColor Red
    write-host $_ -ForegroundColor Red
    Log "An unexpected error occurred: $_"
    exit 1
}


------------
The NT AUTHORITY\SYSTEM account is a highly privileged system account with access to most parts of the operating system.

Some parts of Windows, especially app data and user-specific configurations, are tied to a specific user profile. The SYSTEM account does not have direct access to user-specific directories or resources unless explicitly granted.
