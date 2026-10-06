$baseDir = Split-Path -Parent $PSScriptRoot
Set-Location $baseDir

$totalSw = [System.Diagnostics.Stopwatch]::StartNew()

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Import-Module (Join-Path $baseDir "modules\Core.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Apps.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Privacy.psm1") -Force
Import-Module (Join-Path $baseDir "modules\UI.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Tweaks.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Maintenance.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Software.psm1") -Force
Write-Host "1. Import Modułów: $($sw.ElapsedMilliseconds) ms"

$sw.Restart()
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$xamlPath = Join-Path $baseDir "ui\MainWindow.xaml"
[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
Write-Host "2. XAML Load: $($sw.ElapsedMilliseconds) ms"

$sw.Restart()
$tweaks = Get-SystemTweaksStatus
Write-Host "3. Get-SystemTweaksStatus: $($sw.ElapsedMilliseconds) ms"

$sw.Restart()
$apps = Get-BloatwareCatalogStatus
Write-Host "4. Get-BloatwareCatalogStatus: $($sw.ElapsedMilliseconds) ms"

$sw.Restart()
$soft = Get-SoftwareCatalogStatus
Write-Host "5. Get-SoftwareCatalogStatus: $($sw.ElapsedMilliseconds) ms"

Write-Host "`nCałkowity czas silnika: $($totalSw.ElapsedMilliseconds) ms"
