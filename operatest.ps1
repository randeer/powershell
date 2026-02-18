$OperaUrl = "https://net.geo.opera.com/opera/stable/windows"
$InstallerPath = "C:\Temp\OperaSetup.exe"
$LogFile = "C:\Temp\OperaUpdate.log

if (-not (Test-Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
}

Write-Host "Downloading Opera..."
Start-BitsTransfer -Source $OperaUrl -Destination $InstallerPath

Write-Host "Installing / updating Opera..."
Start-Process -FilePath $InstallerPath -ArgumentList "/silent /allusers=1 /language=en /launchbrowser=0" -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile 

Write-Host "Check after 5 minutes and it is installed and check"
