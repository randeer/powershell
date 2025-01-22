# Create an empty object with the desired column headers
$columns = [PSCustomObject]@{"Device Name" = $null; "Last Reboot" = $null; "Last Reboot Days" = $null; "Last Seen" = $null}
# Export to a CSV file (the file will only contain the headers)
$columns | Export-Csv -Path "C:\Temp\output.csv" -NoTypeInformation
# Output confirmation message
Write-Output "CSV file 'output.csv' with headers created successfully."
#---------------------------------------------------------------------
# Import the CSV files
$vsData = Import-Csv -Path "C:\Temp\vs.csv"
$rmmData = Import-Csv -Path "C:\temp\rmm.csv"
# Retrieve the HostName data from both CSVs
$vsHostNames = $vsData | Select-Object -ExpandProperty HostName
# Find matching rows in rmm.csv based on HostName
$matchingRows = $rmmData | Where-Object { $_.Hostname -in $vsHostNames }
# Get the current date (today)
$today = Get-Date

# Calculate Last Seen Days and display the result
if ($matchingRows) {
    Write-Output "Matching devices found:"
    $matchingRows | ForEach-Object {
        $lastSeenDate = [datetime]::Parse($_."Last Seen")  # Parse the actual Last Seen value
        $lastSeenDays = (($today - $lastSeenDate).Days).ToString() + " days ago"
        if($lastSeenDays -eq "0 days ago"){
            $lastSeenDays = "Currently Online"
        }
        $lastRebootDate = [datetime]::Parse($_."Last Reboot")  # Parse the actual Last Seen value
        $lastRebootDays = (($today - $lastRebootDate).Days).ToString() + " days ago"
        if($lastRebootDays -eq "0 days ago"){
            $lastRebootDays = "Rebooted Today"
        }
        [PSCustomObject]@{
            Hostname      = $_.Hostname
            LastSeen     = $_."Last Seen"
            LastSeenDays = $lastSeenDays
            LastReboot = $_."Last Reboot"
            LastRebootDays = $lastRebootDays
        }
    } | Export-Csv -Path "C:\Temp\report.csv" -NoTypeInformation
    Write-Output "Report has been exported to C:\Temp\report.csv"
} else {
    Write-Output "No matching devices found."
}
