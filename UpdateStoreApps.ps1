<#
.DESCRIPTION
    Script will uninstall Sophos Endpoint agent

.SCRIPT VERSION 
    1.3 (Updated for silent updates)

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

# Ensure script runs with elevation
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Find Winget executable
Write-output "Searching for Winget executable..." -ForegroundColor Cyan
$wingetPath = Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -Filter "winget.exe" | 
    Sort-Object FullName -Descending | 
    Select-Object -First 1 -ExpandProperty FullName

if (-not $wingetPath) {
    Write-output "ERROR: Winget executable not found!" -ForegroundColor Red
    Log "Winget executable not found!"
    exit 1
}

Write-output "Winget executable found at: $wingetPath" -ForegroundColor Green

# Start logging
Log "Script execution started."
Log "Using Winget path: $wingetPath"

try {
    # Updating Winget source
    Write-output "Updating Winget source..." -ForegroundColor Cyan
    Log "Updating Winget source..."
    & $wingetPath source update
    Write-output "Winget source update completed." -ForegroundColor Green
    Log "Winget source update completed."

    # Checking for available upgrades
    Write-output "Checking for available upgrades..." -ForegroundColor Cyan
    Log "Checking for available upgrades..."
    $upgrades = & $wingetPath upgrade --include-unknown 2>&1
    Log "Raw Upgrade Output: $upgrades"

    if ($upgrades -match "No available upgrades found.") {
        Write-output "No upgrades available." -ForegroundColor Yellow
        Log "No upgrades available."
    } else {
        Write-output "Available upgrades found:" -ForegroundColor Green
        Write-output $upgrades

        # Automatically updating available upgrades without popups
        Write-output "Updating all identified packages quietly..." -ForegroundColor Cyan
        Log "Starting silent automatic update for all packages."

        $upgradeResult = & $wingetPath upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --silent 2>&1

        if ($upgradeResult -match "No installed package found matching input criteria") {
            Write-output "No matching packages were found for update." -ForegroundColor Yellow
            Log "No matching packages were found for update."
        } elseif ($upgradeResult -match "Error") {
            Write-output "Errors occurred during the update process:" -ForegroundColor Red
            Write-output $upgradeResult
            Log "Errors during update process: $upgradeResult"
        } else {
            Write-output "Packages updated successfully without triggering popups." -ForegroundColor Green
            Log "Package updates completed successfully and silently: $upgradeResult"
        }
    }

    # Repair Microsoft Store registration
    Write-output "Repairing Microsoft Store registration..." -ForegroundColor Cyan
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

            Write-output "Attempting to register: $manifestPath" -ForegroundColor Cyan
            $result = Start-Process powershell -ArgumentList "Add-AppxPackage -Register '$manifestPath' -ErrorAction Stop" -Wait -PassThru -NoNewWindow

            if ($result.ExitCode -eq 0) {
                $successfulRegistrations++
                Write-output "Successfully registered: $manifestPath" -ForegroundColor Green
                Log "Successfully registered: $manifestPath"
            } else {
                $registrationErrors++
                Write-output "Failed to register: $manifestPath (Exit Code: $($result.ExitCode))" -ForegroundColor Red
                Log "Failed to register: $manifestPath (Exit Code: $($result.ExitCode))"
            }
        } catch {
            $registrationErrors++
            Write-output "Error re-registering app: $manifestPath" -ForegroundColor Red
            Write-output "Error details: $_" -ForegroundColor Red
            Log "Error re-registering app: $manifestPath. Error: $_"
        }
    }

    # Summary of registration results
    Write-output "`nRegistration Summary:" -ForegroundColor Cyan
    Write-output "Successful Registrations: $successfulRegistrations" -ForegroundColor Green
    Write-output "Failed Registrations: $registrationErrors" -ForegroundColor Red

    # Completion
    Write-output "Script execution completed!" -ForegroundColor Green
    Log "Script execution completed successfully."

} catch {
    # Catch any unhandled errors
    Write-output "An unexpected error occurred:" -ForegroundColor Red
    Write-output $_ -ForegroundColor Red
    Log "An unexpected error occurred: $_"
}

# Pause to view output if run interactively
if ($host.Name -eq 'ConsoleHost') {
    Write-output "`nPress any key to continue..." -ForegroundColor Cyan
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}
