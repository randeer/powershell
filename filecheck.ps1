$directory2 = Get-ChildItem "C:\Users\Randeer Lalanga\Desktop\Esoft" -Directory 

$files = Get-ChildItem "C:\Users\Randeer Lalanga\Desktop\Esoft" -File 

Write-Host "Items count in this folder: Directories - $($directory2.length) and other files - $($files.length)" 
Write-Host "               "
Write-Host "----------------------------------------------"

foreach ($subfolder in $directory2) {
    Write-Host "Folder name: $($subfolder.FullName)"
    
    # Get the items inside the subfolder (optional, since you already calculate folder size)
    $subfolderItems = Get-ChildItem $subfolder.FullName -Force -Recurse
    
    # Display the count of files and folders
    Write-Host "Files and folders: $($subfolderItems.Length)"
    
    # Folder size in MB
    $foldersizeInBytes = (Get-ChildItem $subfolder.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
    $foldersizeinMB = $foldersizeInBytes / 1048576  # Convert bytes to MB
    Write-Host "Folder size: $([math]::Round($foldersizeinMB, 2)) MB"  # Corrected variable name
    Write-Host "               "
    Write-Host "---------------"    
}

if ($files.Length -gt 0) {
    Write-Host "This is folder has below files: "
    foreach ($file in $files){
        # Files size in MB
        $filesizeInBytes = $file.Length  # Directly use the Length property
        $filesizeinMB = $filesizeInBytes / 1048576  # Convert bytes to MB
        Write-Host $file.FullName " : " $([math]::Round($filesizeinMB, 2)) "MB"
    }
}
