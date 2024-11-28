$directory2 = Get-ChildItem "C:\Users\RandeerLalanga\Desktop\Patch Reprt" -Directory 

foreach ($subfolder in $directory2) {
    #Write-Host "Folder name: $($subfolder.PSPath)"

    #Write-Host "Folder name (optional): " $subfolder.PSPath.ToString()

    Write-Host "Folder name: " $subfolder.FullName
    
    # Get the items inside the subfolder
    $subfolderItems = Get-ChildItem $subfolder.FullName -Force -Recurse
    
    # Display the count of files and folders
    Write-Host "Files and folders: $($subfolderItems.Length)"

    #folder size in MB
    $foldersizeInBytes = (Get-ChildItem $subfolder.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
    $foldersizeinMB = $foldersizeInBytes / 1048576
    Write-Host "Folder size: $([math]::Round($folderinMB, 2)) MB"
}