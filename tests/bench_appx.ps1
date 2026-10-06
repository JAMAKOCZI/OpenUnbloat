$sw = [System.Diagnostics.Stopwatch]::StartNew()
$appx = Get-AppxPackage
$t1 = $sw.ElapsedMilliseconds
Write-Host "Get-AppxPackage: $t1 ms (Count: $($appx.Count))"

$sw.Restart()
$appxAll = Get-AppxPackage -AllUsers
$t2 = $sw.ElapsedMilliseconds
Write-Host "Get-AppxPackage -AllUsers: $t2 ms (Count: $($appxAll.Count))"

$sw.Restart()
$prov = Get-AppxProvisionedPackage -Online
$t3 = $sw.ElapsedMilliseconds
Write-Host "Get-AppxProvisionedPackage -Online: $t3 ms (Count: $($prov.Count))"
