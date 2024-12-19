# Ensure all errors will be captured
$ErrorActionPreference = "Stop"
try {
    # Define the temp path and create if it doesn't exist
    $tempPath = "C:\Temp\scripts"
    if (-not (Test-Path $tempPath)) {
        Write-Output "Creating directory: $tempPath"
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    }
    # Define script URL and destination path
    $scriptUrl = "https://raw.githubusercontent.com/randeer/powershell/main/appstoreupdaternew.ps1"
    $scriptPath = Join-Path $tempPath "appstoreupdaternew.ps1"
    # Check if the script file already exists, and if so, delete it
    if (Test-Path $scriptPath) {
        Write-Output "Script file already exists, deleting: $scriptPath"
        Remove-Item $scriptPath -Force
    }
    # Force TLS 1.2 for secure downloads
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Output "Downloading script from GitHub to $scriptPath"
    
    # Download the file
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($scriptUrl, $scriptPath)
    Write-Output "Script downloaded successfully to $scriptPath"

    # Create action for both tasks
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File $scriptPath"

    # Create monthly trigger for last Friday at 7:00 PM
    $trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Friday -At "19:00"

    # Task 1: System-level task
    Write-Output "Creating scheduled task 'WinStore Update'"
    $principalSystem = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settingsSystem = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries

    Register-ScheduledTask -TaskName "WinStore Update" `
        -Action $action `
        -Trigger $trigger `
        -Principal $principalSystem `
        -Settings $settingsSystem `
        -Force

    # Task 2: User-level task (without highest privileges)
    Write-Output "Creating scheduled task 'WinStore Update User'"
    $principalUser = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Limited
    $settingsUser = New-ScheduledTaskSettingsSet

    Register-ScheduledTask -TaskName "WinStore Update User" `
        -Action $action `
        -Trigger $trigger `
        -Principal $principalUser `
        -Settings $settingsUser `
        -Force

    Write-Output "Both scheduled tasks created successfully"
}
catch {
    Write-Error "Failed to execute script: $_"
    exit 1
}
