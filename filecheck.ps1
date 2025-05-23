$userinput = Read-Host "Please enter the directory path"

Write-host $userinput

$path = $userinput

$directory2 = Get-ChildItem $path -Directory 

$files = Get-ChildItem $path -File

$usagesize = 0

Write-Host "Items count in this folder: Directories - $($directory2.length) and other files - $($files.length)" 
Write-Host "               "
Write-Host "----------------------------------------------"


if ($directory2.Length -gt 0) {
foreach ($subfolder in $directory2) {
    Write-Host "Folder name: $($subfolder.FullName)"
    
    # Get the items inside the subfolder (optional, since you already calculate folder size)
    $subfolderItems = Get-ChildItem $subfolder.FullName -Force -Recurse
    
    # Display the count of files and folders
    Write-Host "Files and folders: $($subfolderItems.Length)"
    
    # Folder size in MB
    $foldersizeInBytes = (Get-ChildItem $subfolder.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
    $foldersizeinMB = $foldersizeInBytes / 1048576  # Convert bytes to MB
    $usagesize = $usagesize + $foldersizeinMB
    Write-Host "Folder size: $([math]::Round($foldersizeinMB, 2)) MB"  # Corrected variable name
    Write-Host "               "
    Write-Host "---------------"    
}
} else {
    Write-host "No Folders in this directory"
}

if ($files.Length -gt 0) {
    Write-Host "This is folder has below files: "
    foreach ($file in $files){
        # Files size in MB
        $filesizeInBytes = $file.Length  # Directly use the Length property
        $filesizeinMB = $filesizeInBytes / 1048576  # Convert bytes to MB
        $usagesize = $usagesize + $filesizeinMB
        Write-Host $file.FullName " : " $([math]::Round($filesizeinMB, 2)) "MB"
    }
} else {
    Write-host "No Files in this directory"
}

Write-Host "               " 
Write-Host "---------------" 
Write-Host "               " 
Write-Host "Full Data Usage size in the folder is: "$([math]::Round($usagesize, 2)) "MB"
