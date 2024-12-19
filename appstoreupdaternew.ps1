# Set stronger preferences for silent operation
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

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
    # Pre-accept all agreements through registry
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty -Path $registryPath -Name "SilentInstalledAppsEnabled" -Value 1 -ErrorAction SilentlyContinue
    
    # Updating Winget source silently
    write-host "Updating Winget source..." -ForegroundColor Cyan
    Log "Updating Winget source..."
    & $wingetPath source update --accept-source-agreements 2>&1 | Out-Null
    write-host "Winget source update completed." -ForegroundColor Green
    Log "Winget source update completed."

    # Set environment variable to suppress prompts
    $env:WINGET_SILENT = "1"
    
    # Check available upgrades first
    write-host "Checking available upgrades..." -ForegroundColor Cyan
    Log "Checking available upgrades..."
    
    $listCommand = @(
        "upgrade",
        "--include-unknown",
        "--accept-source-agreements"
    )
    
    $availableUpgrades = & $wingetPath $listCommand 2>&1 | Out-String
    
    # Parse and log available upgrades
    $upgradeLines = $availableUpgrades -split "`n" | Where-Object { $_ -match '\S' }
    
    if ($upgradeLines.Count -gt 2) {
        write-host "`nAvailable Updates:" -ForegroundColor Green
        Log "Available Updates:"
        
        foreach ($line in $upgradeLines[2..($upgradeLines.Count-1)]) {
            if ($line -match '\S' -and $line -notmatch 'No available upgrades') {
                write-host $line -ForegroundColor Yellow
                Log "Update Available: $line"
            }
        }
    }
    
    # Force silent upgrade with all possible silent flags
    write-host "`nStarting forced silent update..." -ForegroundColor Cyan
    Log "Starting forced silent update..."
    
    $upgradeCommand = @(
        "upgrade",
        "--all",
        "--include-unknown",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent",
        "--force",  # Added force flag
        "--disable-interactivity"  # Disable any remaining interactive prompts
    )
    
    write-host "`nStarting updates..." -ForegroundColor Cyan
    Log "Starting package updates..."
    
    $upgradeOutput = & $wingetPath $upgradeCommand 2>&1 | ForEach-Object {
        $line = $_
        
        # Skip empty lines and headers
        if ($line -match '\S' -and $line -notmatch '(^Name|^-{2,}$)') {
            # Check if line contains package information
            if ($line -match '^[\w\.\-]+\s+') {
                write-host "Updating: $line" -ForegroundColor Yellow
                Log "Updating package: $line"
            }
            # Check for success messages
            elseif ($line -match 'Successfully installed') {
                $packageInfo = $line -replace 'Successfully installed', 'Successfully updated'
                write-host $packageInfo -ForegroundColor Green
                Log $packageInfo
            }
            # Check for error messages
            elseif ($line -match 'Error') {
                write-host "Error: $line" -ForegroundColor Red
                Log "Error during update: $line"
            }
        }
        $line
    }
    
    # Final summary
    $successCount = ($upgradeOutput | Select-String "Successfully" | Measure-Object).Count
    $errorCount = ($upgradeOutput | Select-String "Error" | Measure-Object).Count
    
    write-host "`nUpdate Summary:" -ForegroundColor Cyan
    write-host "Successfully updated packages: $successCount" -ForegroundColor Green
    if ($errorCount -gt 0) {
        write-host "Failed updates: $errorCount" -ForegroundColor Red
    }
    
    Log "Update Summary - Successful: $successCount, Failed: $errorCount"
    
    if ($upgradeOutput -match "No installed package found matching input criteria") {
        write-host "No matching packages were found for update." -ForegroundColor Yellow
        Log "No matching packages were found for update."
    }

    # Repair Microsoft Store registration silently
    write-host "Repairing Microsoft Store registration..." -ForegroundColor Cyan
    Log "Repairing Microsoft Store registration..."

    $registrationErrors = 0
    $successfulRegistrations = 0

    Get-ChildItem "C:\Program Files\WindowsApps\" -Recurse -Filter "AppxManifest.xml" | 
    Where-Object { $_.DirectoryName -notlike "*\*\*" } | 
    ForEach-Object {
        try {
            $manifestPath = $_.FullName
            $result = Start-Process powershell -ArgumentList "Add-AppxPackage -Register '$manifestPath' -DisableDevelopmentMode -ForceApplicationShutdown" -Wait -PassThru -NoNewWindow
            
            if ($result.ExitCode -eq 0) {
                $successfulRegistrations++
                Log "Successfully registered: $manifestPath"
            } else {
                $registrationErrors++
                Log "Failed to register: $manifestPath (Exit Code: $($result.ExitCode))"
            }
        } catch {
            $registrationErrors++
            Log "Error re-registering app: $manifestPath. Error: $_"
        }
    }

    # Summary
    write-host "`nRegistration Summary:" -ForegroundColor Cyan
    write-host "Successful Registrations: $successfulRegistrations" -ForegroundColor Green
    write-host "Failed Registrations: $registrationErrors" -ForegroundColor Red

    write-host "Script execution completed!" -ForegroundColor Green
    Log "Script execution completed successfully."

} catch {
    write-host "An unexpected error occurred:" -ForegroundColor Red
    write-host $_ -ForegroundColor Red
    Log "An unexpected error occurred: $_"
}

# Remove environment variable
Remove-Item Env:\WINGET_SILENT -ErrorAction SilentlyContinue
