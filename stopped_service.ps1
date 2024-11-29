$svc = ""
$svc = Get-Service 

foreach ($sc in $svc) {
    if ($sc.StartType -eq "Automatic" -and $sc.Status -ne "Running") {
        Write-Host $sc.ServiceName
    }
    
}
