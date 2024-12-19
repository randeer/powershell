# Ensure all errors will be captured
$ErrorActionPreference = "Stop"

function Download-UpdateScript {
    param (
        [string]$ScriptUrl,  # URL of the script to download
        [string]$ScriptName = "update.ps1"  # Name to save the script as
    )

    try {
        # Create base temp folder if it doesn't exist
        $tempPath = "$env:TEMP\scripts"
        if (-not (Test-Path $tempPath)) {
            Write-Output "Creating directory: $tempPath"
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
        }

        # Full path for the script
        $scriptPath = Join-Path $tempPath $ScriptName

        # Force TLS 1.2 for secure downloads
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Write-Output "Downloading script from $ScriptUrl to $scriptPath"
        
        # Download the file
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($ScriptUrl, $scriptPath)

        Write-Output "Script downloaded successfully to $scriptPath"
        return $scriptPath
    }
    catch {
        Write-Error "Failed to download script: $_"
        return $null
    }
}

# Example usage:
# $scriptUrl = "https://your-domain.com/path/update.ps1"
# $downloadedPath = Download-UpdateScript -ScriptUrl $scriptUrl
