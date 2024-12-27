#$env:confirmation = 'False'

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
    
    $installedSoftware = @()
    
    foreach ($software in $softwareList) {
        $installed = Get-Package -Name $software -ErrorAction SilentlyContinue
        if ($installed) {
            $installedSoftware += $software
        }
    }
    
    return $installedSoftware
}

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
    param (
        [array]$softwareList
    )
    
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

function Get-ProductCode {
    param (
        [string]$PackageName
    )
    
    $product = Get-CimInstance Win32_Product | Where-Object { $_.Name -eq $PackageName }
    return $product.IdentifyingNumber
}

# Get installed software
$installedOldSoftware = Get-InstalledSoftware -softwareList $oldPackages

# Display installed old software
Write-Output "`nOld installed software on this machine:"
Write-Output "----------------------------------------"

if ($installedOldSoftware.Count -eq 0) {
    Write-Output "No old software found"
} else {
    $installedOldSoftware | ForEach-Object { Write-Output $_ }
    
    # Check environment variable for confirmation
    if ($env:confirmation -eq 'True') {
        $softwareClassification = Get-InstalledSoftwareWithQuietUninstall -softwareList $installedOldSoftware
        
        Write-Output "`nUninstalling software..."
        
        # Handle software with QuietUninstallString
        foreach ($software in $softwareClassification.WithQuietUninstall) {
            Write-Output "Uninstalling $software using QuietUninstallString..."
            $uninstallString = Get-QuietUninstallString -PackageName $software
            if ($uninstallString) {
                Start-Process cmd -ArgumentList "/c $uninstallString" -Wait -NoNewWindow
            }
        }
        
        # Handle software without QuietUninstallString
        foreach ($software in $softwareClassification.WithoutQuietUninstall) {
            Write-Output "Uninstalling $software using product code..."
            $productCode = Get-ProductCode -PackageName $software
            if ($productCode) {
                Start-Process msiexec -ArgumentList "/x $productCode /quiet /norestart" -Wait -NoNewWindow
            }
        }
        
        Write-Output "`nUninstallation process completed."
    } else {
        Write-Output "`nThe following packages need to be uninstalled:"
        $installedOldSoftware | ForEach-Object { Write-Output $_ }
    }
}
