# test_full_suite.ps1 - Kompleksowy zestaw testów weryfikacyjnych dla OpenUnbloat
$baseDir = Split-Path -Parent $PSScriptRoot
Set-Location $baseDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     KOMPLEKSOWY TEST WERYFIKACYJNY OPENUNBLOAT           " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$testResults = [System.Collections.Generic.List[object]]::new()

function Record-TestResult {
    param([string]$Name, [bool]$Passed, [string]$Details = "")
    $testResults.Add([PSCustomObject]@{
        Name    = $Name
        Passed  = $Passed
        Details = $Details
    })
    if ($Passed) {
        Write-Host " [PASS] $Name $(if($Details){ "($Details)" })" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $($Name): $Details" -ForegroundColor Red
    }
}

# --- TEST 1: Walidacja bazy bloat-apps.json ---
try {
    $appsJsonPath = Join-Path $baseDir "data\bloat-apps.json"
    $appsData = Get-Content -Path $appsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $allApps = @()
    if ($appsData.SafeToRemove) { $allApps += $appsData.SafeToRemove }
    if ($appsData.Optional) { $allApps += $appsData.Optional }
    $hasRequiredFields = $true
    foreach ($app in $allApps) {
        if (-not $app.name -or -not $app.pattern -or -not $app.description) {
            $hasRequiredFields = $false; break
        }
    }
    Record-TestResult -Name "Katalog Bloatware (bloat-apps.json)" -Passed ($allApps.Count -ge 40 -and $hasRequiredFields) -Details "$($allApps.Count) definicji aplikacji (Safe: $($appsData.SafeToRemove.Count), Opt: $($appsData.Optional.Count))"
} catch {
    Record-TestResult -Name "Katalog Bloatware (bloat-apps.json)" -Passed $false -Details $_.Exception.Message
}

# --- TEST 2: Walidacja bazy software.json ---
try {
    $softJsonPath = Join-Path $baseDir "data\software.json"
    $softData = Get-Content -Path $softJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $hasDetect = $true
    $packages = $softData.Packages
    foreach ($soft in $packages) {
        if (-not $soft.detectPatterns -or $soft.detectPatterns.Count -eq 0 -or -not $soft.id -or -not $soft.name) {
            $hasDetect = $false; break
        }
    }
    Record-TestResult -Name "Katalog Oprogramowania (software.json)" -Passed ($packages.Count -ge 25 -and $hasDetect) -Details "$($packages.Count) programów w $($softData.Categories.Count) kategoriach ze wzorcami detekcji rejestru"
} catch {
    Record-TestResult -Name "Katalog Oprogramowania (software.json)" -Passed $false -Details $_.Exception.Message
}

# --- TEST 3: Walidacja bazy tweaks.json ---
try {
    $tweaksJsonPath = Join-Path $baseDir "data\tweaks.json"
    $tweaksData = Get-Content -Path $tweaksJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $validTweaks = $true
    foreach ($t in $tweaksData.tweaks) {
        if (-not $t.id -or -not $t.apply -or -not $t.revert) {
            $validTweaks = $false; break
        }
    }
    Record-TestResult -Name "Katalog Tweaków (tweaks.json)" -Passed ($tweaksData.tweaks.Count -ge 45 -and $validTweaks) -Details "$($tweaksData.tweaks.Count) reguł optymalizacji w $($tweaksData.categories.Count) kategoriach"
} catch {
    Record-TestResult -Name "Katalog Tweaków (tweaks.json)" -Passed $false -Details $_.Exception.Message
}

# --- TEST 4: Moduły i Detekcja ---
try {
    Import-Module (Join-Path $baseDir "modules\Core.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path $baseDir "modules\Apps.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path $baseDir "modules\Software.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path $baseDir "modules\Tweaks.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path $baseDir "modules\Maintenance.psm1") -Force -DisableNameChecking
    Record-TestResult -Name "Import modułów PowerShell" -Passed $true -Details "Wszystkie moduły zaimportowane pomyślnie"
} catch {
    Record-TestResult -Name "Import modułów PowerShell" -Passed $false -Details $_.Exception.Message
}

# --- TEST 5: Szybka detekcja programów w rejestrze (sub-5s z winget) ---
try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $installedSoftware = Get-SoftwareCatalogStatus
    $sw.Stop()
    $detectedCount = ($installedSoftware | Where-Object { $_.IsInstalled }).Count
    Record-TestResult -Name "Detekcja Oprogramowania WinGet/Rejestr" -Passed ($sw.ElapsedMilliseconds -lt 6000) -Details "Wykryto $detectedCount zainstalowanych programów w $($sw.ElapsedMilliseconds)ms"
} catch {
    Record-TestResult -Name "Detekcja Oprogramowania WinGet/Rejestr" -Passed $false -Details $_.Exception.Message
}

# --- TEST 6: Szybka detekcja tweaków i funkcji systemu ---
try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $tweaksStatus = Get-SystemTweaksStatus
    $sw.Stop()
    $appliedCount = ($tweaksStatus | Where-Object { $_.IsApplied }).Count
    Record-TestResult -Name "Detekcja Tweaków i Funkcji Systemowych" -Passed ($tweaksStatus.Count -ge 45) -Details "Zbadano $($tweaksStatus.Count) tweaków (aktywnych: $appliedCount) w $($sw.ElapsedMilliseconds)ms"
} catch {
    Record-TestResult -Name "Detekcja Tweaków i Funkcji Systemowych" -Passed $false -Details $_.Exception.Message
}

# --- TEST 7: Skanowanie aplikacji UWP Bloatware ---
try {
    $bloatCatalog = Get-BloatwareCatalogStatus
    $installedBloat = ($bloatCatalog | Where-Object { $_.IsInstalled }).Count
    Record-TestResult -Name "Detekcja Aplikacji Bloatware (UWP)" -Passed ($bloatCatalog.Count -ge 40) -Details "Zbadano $($bloatCatalog.Count) aplikacji (wykryto w systemie: $installedBloat)"
} catch {
    Record-TestResult -Name "Detekcja Aplikacji Bloatware (UWP)" -Passed $false -Details $_.Exception.Message
}

# --- TEST 8: Parsowanie XAML MainWindow.xaml w WPF ---
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $xamlContent = Get-Content -Path (Join-Path $baseDir "ui\MainWindow.xaml") -Raw -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlContent)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    $requiredControls = @(
        "mainTabControl", "chkDryRun", "btnPresetRecommended", "btnPresetGaming", "btnPresetPrivacy", "btnPresetRevert",
        "panelTweaksList", "txtSearchTweaks", "btnClearSearchTweaks", "btnSelectAllTweaks", "btnUnselectAllTweaks",
        "panelAppsList", "txtSearchApps", "btnClearSearchApps", "chkOnlyInstalledApps", "btnScanApps", "btnSelectSafeApps", "btnUnselectApps",
        "panelSoftwareList", "txtSearchSoftware", "btnClearSearchSoftware", "btnSelectRecSoftware", "btnUnselectSoftware",
        "btnActionCleanup", "btnActionResetNetwork", "btnActionUltimatePower", "btnActionRepair", "btnActionResetUpdate",
        "btnActionRepairWinget", "btnActionBackupRegistry", "txtLogConsole", "btnCopyLog", "btnSaveLog", "btnClearLog",
        "badgeSelectionCount", "lblSelectionCount", "btnCreateRestorePoint", "btnApplyAllSelected", "pbProgress",
        "btnDnsCloudflare", "btnDnsQuad9", "btnDnsDhcp"
    )
    $missing = @()
    foreach ($ctrlName in $requiredControls) {
        if (-not $window.FindName($ctrlName)) {
            $missing += $ctrlName
        }
    }
    Record-TestResult -Name "Weryfikacja interfejsu WPF (MainWindow.xaml)" -Passed ($missing.Count -eq 0) -Details $(if($missing.Count -eq 0){"Wszystkie $(($requiredControls).Count) wymagane kontrolki podpięte"}else{"Brak kontrolek: $($missing -join ', ')"})
} catch {
    Record-TestResult -Name "Weryfikacja interfejsu WPF (MainWindow.xaml)" -Passed $false -Details $_.Exception.Message
}

# --- TEST 9: Test konsolowy -DryRun ---
try {
    $dryAudit = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $baseDir "OpenUnbloat.ps1") -DryRun -Audit
    $drySuccess = $dryAudit -and ($dryAudit -match "Stan" -or $dryAudit -match "Kategoria" -or $dryAudit -match "Tweak")
    Record-TestResult -Name "Konsolowy Dry-Run (-Audit)" -Passed $drySuccess -Details "Wygenerowano tabelę audytu bez błędów"
} catch {
    Record-TestResult -Name "Konsolowy Dry-Run (-Audit)" -Passed $false -Details $_.Exception.Message
}

# --- TEST 10: Launcher OpenUnbloat.exe ---
$exePath = Join-Path $baseDir "OpenUnbloat.exe"
if (Test-Path $exePath) {
    $exeSize = (Get-Item $exePath).Length
    Record-TestResult -Name "Skompilowany plik OpenUnbloat.exe" -Passed ($exeSize -gt 1000) -Details "Rozmiar: $exeSize bajtów"
} else {
    Record-TestResult -Name "Skompilowany plik OpenUnbloat.exe" -Passed $false -Details "Plik nie istnieje"
}

Write-Host "----------------------------------------------------------" -ForegroundColor Gray
$failed = $testResults | Where-Object { -not $_.Passed }
if ($failed.Count -eq 0) {
    Write-Host "WSZYSTKIE TESTY ZAKOŃCZONE SUKCESEM! (10/10 PASS)" -ForegroundColor Green
} else {
    Write-Host "NIEKTÓRE TESTY NIE POWIODŁY SIĘ: $($failed.Count) BŁĘDÓW" -ForegroundColor Red
    exit 1
}
