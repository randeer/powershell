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
}
catch {
    Write-Error "Failed to download script: $_"
    exit 1
}
