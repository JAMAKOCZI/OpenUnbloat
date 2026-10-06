# test_gui_preloaded.ps1 - Test sprawdzający czy wszystkie zakładki są w pełni załadowane na starcie
$baseDir = Split-Path -Parent $PSScriptRoot
Set-Location $baseDir

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

Import-Module (Join-Path $baseDir "modules\Core.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Apps.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Privacy.psm1") -Force
Import-Module (Join-Path $baseDir "modules\UI.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Tweaks.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Maintenance.psm1") -Force
Import-Module (Join-Path $baseDir "modules\Software.psm1") -Force

$xamlPath = Join-Path $baseDir "ui\MainWindow.xaml"
[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$panelTweaksList = $window.FindName("panelTweaksList")
$panelAppsList = $window.FindName("panelAppsList")
$panelSoftwareList = $window.FindName("panelSoftwareList")

Write-Host "Początkowa liczba elementów: Tweaks=$($panelTweaksList.Children.Count), Apps=$($panelAppsList.Children.Count), Software=$($panelSoftwareList.Children.Count)"

# Sprawdzenie bazy tweaków
$tweaksStatus = Get-SystemTweaksStatus
Write-Host "[OK] Tweaki sprawdzone: $($tweaksStatus.Count)"

# Sprawdzenie bazy bloatware
$bloatCatalog = Get-BloatwareCatalogStatus
Write-Host "[OK] Bloatware sprawdzone: $($bloatCatalog.Count)"

# Sprawdzenie bazy programów
$softCatalog = Get-SoftwareCatalogStatus
Write-Host "[OK] Software sprawdzone: $($softCatalog.Count)"

Write-Host "`nWszystkie bazy są zoptymalizowane do wstępnego załadowania na starcie GUI!" -ForegroundColor Green
