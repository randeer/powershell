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

# Run the winget upgrade command and capture both the StandardOutput and StandardError
Write-Output "Running winget upgrade..."

$process = Start-Process -FilePath $wingetPath -ArgumentList "upgrade" -PassThru -Wait

# Capture the standard output and standard error
$standardOutput = $process.StandardOutput.ReadToEnd()
$standardError = $process.StandardError.ReadToEnd()

# Prepare the log content
$logContent = "Winget upgrade completed. Output:`r`n"

if ($standardOutput) {
    $logContent += $standardOutput
} else {
    $logContent += "No output from StandardOutput.`r`n"
}

if ($standardError) {
    $logContent += "Error Output:`r`n$standardError"
} else {
    $logContent += "No errors detected in StandardError.`r`n"
}

# Write the log content to the file
Set-Content -Path $logFilePath -Value $logContent -Force

Write-Output "Upgrade process finished."
Write-Output "Log written to: $logFilePath"


---------------
Current UserContext: AOIW\stsadmin01
Copying script from winget.exe
Winget Path for stsadmin01: C:\Users\stsadmin01\AppData\Local\Microsoft\WindowsApps\winget.exe
Final Winget Path: C:\Users\stsadmin01\AppData\Local\Microsoft\WindowsApps\winget.exe
Running winget upgrade...
Upgrade process finished.
Log written to: C:\Temp\storeupdate.log

Log file content;
Winget upgrade completed. Output:
No output from StandardOutput.      
No errors detected in StandardError.
