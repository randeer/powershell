Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser

Import-Module PSWindowsUpdate

Get-WUHistory

Get-WindowsUpdate


Get-ExecutionPolicy
Get-ExecutionPolicy -List
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser+
Set-ExecutionPolicy Restricted -Scope CurrentUser

Install-WindowsUpdate -AcceptAll
Install-WindowsUpdate -AcceptAll -AutoReboot

Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersion" -Value 1



# Set ProductVersion to "Windows 11"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ProductVersion" -Value "Windows 11"

# Set TargetReleaseVersionInfo to "24H2"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersionInfo" -Value "24H2"

# Enable version targeting (set TargetReleaseVersion to 1)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersion" -Value 1


Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" | Format-List
