$oldPackages = 0

$oldPackages = @(
    "Microsoft .NET AppHost Pack - 6.0.12 (x64)",
    "Microsoft .NET AppHost Pack - 6.0.12 (x64_arm)",
    "Microsoft .NET AppHost Pack - 6.0.12 (x64_arm64)",
    "Microsoft .NET AppHost Pack - 6.0.12 (x64_x86)",
    "Microsoft .NET Host - 5.0.17 (x86)",
    "Microsoft .NET Host - 5.0.7 (x86)",
    "Microsoft .NET Host - 6.0.12 (x64)",
    "Microsoft .NET Host - 6.0.25 (x86)",
    "Microsoft .NET Host - 6.0.36 (x64)",
    "Microsoft .NET Host - 6.0.36 (x86)",
    "Microsoft .NET Host FX Resolver - 5.0.17 (x86)",
    "Microsoft .NET Host FX Resolver - 5.0.7 (x86)",
    "Microsoft .NET Runtime - 5.0.17 (x86)",
    "Microsoft .NET Runtime - 5.0.7 (x86)",
    "Microsoft .NET Runtime - 6.0.12 (x64)",
    "Microsoft .NET Runtime - 6.0.25 (x86)",
    "Microsoft .NET Runtime - 6.0.36 (x64)",
    "Microsoft .NET Runtime - 6.0.36 (x86)",
    "Microsoft ASP.NET Core 6.0.12 Shared Framework (x64)",
    "Microsoft ASP.NET Core 6.0.12 Targeting Pack (x64)",
    "Microsoft Visual C++ 2012 Redistributable (x64) - 11.0.61030",
    "Microsoft Visual C++ 2012 Redistributable (x86) - 11.0.61030",
    "Microsoft Visual C++ 2012 x64 Additional Runtime - 11.0.61030",
    "Microsoft Visual C++ 2012 x64 Minimum Runtime - 11.0.61030",
    "Microsoft Visual C++ 2012 x86 Additional Runtime - 11.0.61030",
    "Microsoft Visual C++ 2012 x86 Minimum Runtime - 11.0.61030",
    "Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.30501",
    "Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.40660",
    "Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.40664",
    "Microsoft Visual C++ 2013 Redistributable (x86) - 12.0.40664",
    "Microsoft Visual C++ 2013 x64 Additional Runtime - 12.0.21005",
    "Microsoft Visual C++ 2013 x64 Additional Runtime - 12.0.40660",
    "Microsoft Visual C++ 2013 x64 Additional Runtime - 12.0.40664",
    "Microsoft Visual C++ 2013 x64 Minimum Runtime - 12.0.21005",
    "Microsoft Visual C++ 2013 x64 Minimum Runtime - 12.0.40660",
    "Microsoft Visual C++ 2013 x64 Minimum Runtime - 12.0.40664",
    "Microsoft Visual C++ 2013 x86 Additional Runtime - 12.0.40664",
    "Microsoft Visual C++ 2013 x86 Minimum Runtime - 12.0.40664"
)



function Get-InstalledSoftware {
    param (
        [array]$softwareList
    )

    # Initialize an empty array to store the matching software
    $installedSoftware = @()

    # Loop through each software in the list and check if it's installed
    foreach ($software in $softwareList) {
        # Use Get-Package to check if the software is installed on the machine
        $installed = Get-Package -Name $software -ErrorAction SilentlyContinue
        
        if ($installed) {
            # If the software is found, add it to the result array
            $installedSoftware += $software
        }
    }

    # Return the array of installed software
    return $installedSoftware
}


# Get the installed software that matches the list
$installedOldSoftware = Get-InstalledSoftware -softwareList $oldPackages

function Get-QuietUninstallString {
    param (
        [Parameter(Mandatory=$true)]
        [string]$PackageName
    )
    $package = Get-Package -Name $PackageName -ErrorAction SilentlyContinue
    if ($package.SwidTagText) {
        [xml]$swidTag = $package.SwidTagText
        $quietUninstallString = $swidTag.SoftwareIdentity.Meta.QuietUninstallString
        if ($quietUninstallString) {
            return $quietUninstallString -replace "&quot;", '"'
        }
    }
    return $null
}

function Get-InstalledSoftwareWithQuietUninstall {
    param ([array]$softwareList)
    $softwareWithQuietUninstall = @()
    $softwareWithoutQuietUninstall = @()
    
    foreach ($software in $softwareList) {
        $installed = Get-Package -Name $software -ErrorAction SilentlyContinue
        if ($installed) {
            $quietUninstallString = Get-QuietUninstallString -PackageName $software
            if ($quietUninstallString) {
                $softwareWithQuietUninstall += $software
            } else {
                $softwareWithoutQuietUninstall += $software
            }
        }
    }
    
    return @{
        WithQuietUninstall = $softwareWithQuietUninstall
        WithoutQuietUninstall = $softwareWithoutQuietUninstall
    }
}

# New function to get product code
function Get-ProductCode {
    param (
        [string]$PackageName
    )
    $product = Get-WmiObject Win32_Product | Where-Object { $_.Name -eq $PackageName }
    return $product.IdentifyingNumber
}

# Display installed old software
Write-Host "`nOld installed software on this machine:" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$installedOldSoftware = Get-InstalledSoftware -softwareList $oldPackages
$installedOldSoftware | ForEach-Object { Write-Host $_ }

# Ask for user confirmation
$response = Read-Host "`nDo you want to uninstall these old software packages? (yes/no)"

if ($response.ToLower() -eq 'yes') {
    $softwareClassification = Get-InstalledSoftwareWithQuietUninstall -softwareList $installedOldSoftware
    
    Write-Host "`nUninstalling software..." -ForegroundColor Yellow
    
    # Handle software with QuietUninstallString
    foreach ($software in $softwareClassification.WithQuietUninstall) {
        Write-Host "Uninstalling $software using QuietUninstallString..."
        $uninstallString = Get-QuietUninstallString -PackageName $software
        if ($uninstallString) {
            Start-Process cmd -ArgumentList "/c $uninstallString" -Wait -NoNewWindow
        }
    }
    
    # Handle software without QuietUninstallString
    foreach ($software in $softwareClassification.WithoutQuietUninstall) {
        Write-Host "Uninstalling $software using product code..."
        $productCode = Get-ProductCode -PackageName $software
        if ($productCode) {
            Start-Process msiexec -ArgumentList "/x $productCode /quiet /norestart" -Wait -NoNewWindow
        }
    }
    
    Write-Host "`nUninstallation process completed." -ForegroundColor Green
} else {
    Write-Host "`nUninstallation cancelled." -ForegroundColor Red
}
