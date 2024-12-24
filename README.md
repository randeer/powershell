# Get the current user context
$UserContext = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name
# Split the UserContext by backslash and get the second part (the username)
$username = ($UserContext.Split('\'))[1]
# Initialize $wingetPath variable
$wingetPath = ""

Write-Output "Current UserContext: $UserContext"
if($UserContext -ne "NT AUTHORITY\SYSTEM"){
    Write-Output "Copying script from winget.exe"
    # Copy winget.exe for non-SYSTEM users
    Copy-Item ./winget.exe -Destination "C:\Users\$username\AppData\Local\Microsoft\WindowsApps\winget.exe" -Force
    $wingetPath = "C:\Users\$username\AppData\Local\Microsoft\WindowsApps\winget.exe"
    Write-Output "Winget Path for ${username}: $wingetPath"
} else {
    # For SYSTEM user, find the winget.exe in the WindowsApps folder
    $wingetPath = Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -Filter "winget.exe" | 
                  Sort-Object FullName -Descending | 
                  Select-Object -First 1 -ExpandProperty FullName
    Write-Output "Winget Path for SYSTEM: $wingetPath"
}

# Output the final winget path
Write-Output "Final Winget Path: $wingetPath"

# Prepare log file path
$logFilePath = "C:\Temp\storeupdate.log"

# Ensure the directory exists
if (-not (Test-Path "C:\Temp")) {
    New-Item -Path "C:\" -Name "Temp" -ItemType "Directory" -Force
}

# Run the winget upgrade command and capture the output
Write-Output "Running winget upgrade..."
try {
    # Use Start-Process with RedirectStandardOutput and RedirectStandardError
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $wingetPath
    $processStartInfo.Arguments = "upgrade"
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.UseShellExecute = $false
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo
    $process.Start() | Out-Null
    
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    
    # Prepare the log content
    $logContent = "Winget upgrade completed at $(Get-Date)`r`n`r`nOutput:`r`n"
    if ($standardOutput) {
        $logContent += $standardOutput
        Write-Output $standardOutput  # Display output in console
    } else {
        $logContent += "No output from StandardOutput.`r`n"
    }
    
    if ($standardError) {
        $logContent += "`r`nError Output:`r`n$standardError"
        Write-Error $standardError  # Display errors in console
    } else {
        $logContent += "`r`nNo errors detected in StandardError.`r`n"
    }
    
    # Write the log content to the file
    Set-Content -Path $logFilePath -Value $logContent -Force
    
} catch {
    $errorMessage = "Error running winget: $_"
    Write-Error $errorMessage
    Add-Content -Path $logFilePath -Value $errorMessage
}

Write-Output "Upgrade process finished."
Write-Output "Log written to: $logFilePath"
