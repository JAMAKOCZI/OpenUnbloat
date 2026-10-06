<#
.SYNOPSIS
    OpenUnbloat - Modułowe narzędzie do bezpiecznego odchudzania, optymalizacji i konfiguracji systemu Windows 10 i Windows 11.
.DESCRIPTION
    Narzędzie pozwala usunąć preinstalowane aplikacje sponsorowane (UWP),
    wyłączyć telemetrię, zbędne usługi w tle, asystentów AI (Copilot, Recall),
    optymalizować gry, zarządzać OneDrive, instalować czyste programy przez WinGet
    oraz przeprowadzać konserwację systemu za pomocą GUI lub konsoli.
.PARAMETER GUI
    Uruchamia nowoczesny interfejs graficzny okna (WPF).
.PARAMETER DryRun
    Wyświetla listę zmian bez faktycznego ich wprowadzania do systemu.
.PARAMETER All
    Wykonuje pełny, zalecany zestaw zmian (bezpieczne aplikacje + zalecane tweaki).
#>

[CmdletBinding()]
param(
    [switch]$GUI,
    [switch]$DryRun,
    [switch]$All,
    [switch]$Apps,
    [switch]$Privacy,
    [switch]$Audit,
    [switch]$Cleanup,
    [switch]$ResetNetwork,
    [switch]$UltimatePower,
    [switch]$RepairScan,
    [switch]$InstallSoftware,
    [switch]$SoftwareList,
    [switch]$RevertAll,
    [switch]$RestorePoint
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Załadowanie modułów
Import-Module (Join-Path $scriptDir "modules\Core.psm1") -DisableNameChecking
Import-Module (Join-Path $scriptDir "modules\Apps.psm1") -DisableNameChecking
Import-Module (Join-Path $scriptDir "modules\Privacy.psm1") -DisableNameChecking
Import-Module (Join-Path $scriptDir "modules\UI.psm1") -DisableNameChecking
Import-Module (Join-Path $scriptDir "modules\Tweaks.psm1") -DisableNameChecking
Import-Module (Join-Path $scriptDir "modules\Maintenance.psm1") -DisableNameChecking
Import-Module (Join-Path $scriptDir "modules\Software.psm1") -DisableNameChecking
Import-Module (Join-Path $scriptDir "modules\GUI.psm1") -DisableNameChecking

# Upewnienie się, że skrypt działa jako Administrator (chyba że uruchomiono w trybie symulacji DryRun)
$passedArgs = @()
foreach ($key in $PSBoundParameters.Keys) {
    if ($PSBoundParameters[$key] -is [switch] -and $PSBoundParameters[$key]) {
        $passedArgs += "-$key"
    } elseif ($PSBoundParameters[$key] -isnot [switch]) {
        $passedArgs += "-$key `"$($PSBoundParameters[$key])`""
    }
}
Assert-Admin -AllowNonAdmin:$DryRun -ForwardArgs $passedArgs

function Show-Header {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "                  OPENUNBLOAT v1.0                        " -ForegroundColor White
    Write-Host "         Modułowe narzędzie optymalizacji systemu         " -ForegroundColor DarkCyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host " [TRYB SYMULACJI (DRY-RUN) - Brak zmian w systemie]" -ForegroundColor Magenta
    }
    Write-Host ""
}

function Run-RecommendedDebloat {
    param([switch]$IsDryRun)

    Write-Host "`n>>> ROZPOCZYNAM ZALECANY DEBLOAT <<<`n" -ForegroundColor Yellow

    if (-not $IsDryRun) {
        New-SystemRestorePoint -Description "Przed OpenUnbloat"
    }

    # 1. Aplikacje Bloatware
    Write-Host "`n--- Krok 1: Usuwanie aplikacji sponsorowanych (Bloatware) ---" -ForegroundColor Cyan
    $appsToRemove = Find-InstalledBloatware -Category "SafeToRemove"
    Remove-BloatwareList -Items $appsToRemove -DryRun:$IsDryRun

    # 2. Deklaratywne Tweaki z presetu 'Recommended'
    Write-Host "`n--- Krok 2: Aplikowanie zalecanych optymalizacji i prywatności ---" -ForegroundColor Cyan
    $db = Get-TweaksDatabase
    $recommended = $db.Tweaks | Where-Object { $_.presets -contains "Recommended" }
    
    foreach ($tw in $recommended) {
        $alreadyApplied = Test-TweakApplied -Tweak $tw
        if ($alreadyApplied) {
            Write-Host "   [POMINIĘTO - JUŻ AKTYWNE] $($tw.name)" -ForegroundColor DarkGray
        } else {
            Invoke-TweakAction -Tweak $tw -Mode "Apply" -DryRun:$IsDryRun
        }
    }

    if (-not $IsDryRun) {
        Restart-ExplorerProcess
    }

    Write-Host "`n>>> ZALECANY DEBLOAT ZAKOŃCZONY POMYŚLNIE! <<<`n" -ForegroundColor Green
}

function Show-SystemAuditMenu {
    param([switch]$IsDryRun)

    do {
        Show-Header
        Write-Host " AUDYT STANU SYSTEMU I PRZEŁĄCZNIK TWEAKÓW:" -ForegroundColor Yellow
        Write-Host " (Wpisz numer, aby włączyć lub cofnąć dany tweak)`n" -ForegroundColor DarkGray

        $statusList = Get-SystemTweaksStatus
        for ($i = 0; $i -lt $statusList.Count; $i++) {
            $item = $statusList[$i]
            $num = "{0,2}" -f ($i + 1)
            $badge = if ($item.IsApplied) { "[✓ WŁĄCZONE] " } else { "[  NIEAKTYWNE]" }
            $badgeColor = if ($item.IsApplied) { "Green" } else { "DarkGray" }

            Write-Host " $num. " -NoNewline -ForegroundColor White
            Write-Host "$badge " -NoNewline -ForegroundColor $badgeColor
            Write-Host "$($item.Name)" -ForegroundColor White
        }

        Write-Host "`n  0. Powrót do menu głównego" -ForegroundColor Cyan
        Write-Host ""

        $subChoice = Read-Host "Wybierz numer tweaka [1-$($statusList.Count)] lub 0"
        if ($subChoice -eq "0" -or -not $subChoice) {
            break
        }

        $idx = [int]$subChoice - 1
        if ($idx -ge 0 -and $idx -lt $statusList.Count) {
            $selected = $statusList[$idx]
            $targetMode = if ($selected.IsApplied) { "Revert" } else { "Apply" }
            $modeLabel = if ($targetMode -eq "Apply") { "włączyć" } else { "cofnąć" }

            Write-Host "`nCzy na pewno chcesz $($modeLabel): $($selected.Name)?" -ForegroundColor Yellow
            $confirm = Read-Host "Potwierdź (t/n)"
            if ($confirm -eq "t" -or $confirm -eq "y" -or $confirm -eq "tak") {
                Invoke-TweakAction -Tweak $selected.RawTweak -Mode $targetMode -DryRun:$IsDryRun
                if (-not $IsDryRun -and $selected.Category -in @("StartAndTaskbar", "UIAndExplorer", "OneDriveAndCloud")) {
                    Restart-ExplorerProcess
                }
                Read-Host "`nNaciśnij Enter, aby odświeżyć listę..."
            }
        }
    } while ($true)
}

function Show-MaintenanceMenu {
    param([switch]$IsDryRun)

    do {
        Show-Header
        Write-Host " NARZĘDZIA KONSERWACJI I NAPRAWY SYSTEMU:" -ForegroundColor Yellow
        Write-Host "  1. Czyszczenie plików tymczasowych, Kosza i cache aktualizacji" -ForegroundColor White
        Write-Host "  2. Reset stosu sieciowego i czyszczenie DNS" -ForegroundColor White
        Write-Host "  3. Aktywuj plan zasilania 'Najwyższa wydajność' (Ultimate Performance)" -ForegroundColor White
        Write-Host "  4. Skanowanie i naprawa plików systemowych (SFC & DISM)" -ForegroundColor White
        Write-Host "`n  0. Powrót do menu głównego" -ForegroundColor Cyan
        Write-Host ""

        $mChoice = Read-Host "Wybór [0-4]"
        switch ($mChoice) {
            "1" {
                Invoke-SystemCleanup -DryRun:$IsDryRun
                Read-Host "`nNaciśnij Enter, aby kontynuować..."
            }
            "2" {
                Invoke-NetworkReset -DryRun:$IsDryRun
                Read-Host "`nNaciśnij Enter, aby kontynuować..."
            }
            "3" {
                Enable-UltimatePerformancePlan -DryRun:$IsDryRun
                Read-Host "`nNaciśnij Enter, aby kontynuować..."
            }
            "4" {
                Invoke-SystemRepairScan -DryRun:$IsDryRun
                Read-Host "`nNaciśnij Enter, aby kontynuować..."
            }
            "0" {
                break
            }
        }
    } while ($mChoice -ne "0" -and $mChoice)
}

function Show-SoftwareMenu {
    param([switch]$IsDryRun)

    if (-not (Test-WinGetAvailable)) {
        Write-LogError "Menedżer pakietów 'winget' nie jest zainstalowany lub dostępny w PATH."
        Read-Host "`nNaciśnij Enter, aby powrócić..."
        return
    }

    do {
        Show-Header
        Write-Host " INSTALATOR CZYSTEGO OPROGRAMOWANIA (WINGET):" -ForegroundColor Yellow
        Write-Host " Wybierz aplikacje, które chcesz zainstalować na komputerze:`n" -ForegroundColor DarkGray

        $catalog = Get-SoftwareCatalogStatus
        for ($i = 0; $i -lt $catalog.Count; $i++) {
            $pkg = $catalog[$i]
            $num = "{0,2}" -f ($i + 1)
            $badge = if ($pkg.IsInstalled) { "[ZAINSTALOWANY]   " } else { "[NIEZAINSTALOWANY]" }
            $badgeColor = if ($pkg.IsInstalled) { "DarkGreen" } else { "DarkGray" }
            $recTag = if ($pkg.Recommended) { " (Zalecany)" } else { "" }

            Write-Host " $num. " -NoNewline -ForegroundColor White
            Write-Host "$badge " -NoNewline -ForegroundColor $badgeColor
            Write-Host "$($pkg.Name)" -NoNewline -ForegroundColor White
            if ($recTag) { Write-Host "$recTag" -NoNewline -ForegroundColor Green }
            Write-Host " - $($pkg.Description)" -ForegroundColor DarkGray
        }

        Write-Host "`n  A. Zainstaluj wszystkie brakujące programy zalecane" -ForegroundColor Green
        Write-Host "  [Numery]: Wpisz numery oddzielone przecinkami (np. 1, 2, 8)" -ForegroundColor White
        Write-Host "  0. Powrót do menu głównego" -ForegroundColor Cyan
        Write-Host ""

        $sChoice = Read-Host "Wybór [Numery / A / 0]"
        if ($sChoice -eq "0" -or -not $sChoice) {
            break
        }

        if ($sChoice -eq "A" -or $sChoice -eq "a") {
            $toInstall = $catalog | Where-Object { $_.Recommended -and -not $_.IsInstalled }
            if ($toInstall.Count -eq 0) {
                Write-LogSuccess "Wszystkie zalecane programy są już zainstalowane na Twoim komputerze!"
            } else {
                Install-SoftwareList -Packages $toInstall -DryRun:$IsDryRun
            }
            Read-Host "`nNaciśnij Enter, aby kontynuować..."
            continue
        }

        $selectedNums = $sChoice.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
        $toInstall = @()

        foreach ($n in $selectedNums) {
            $idx = [int]$n - 1
            if ($idx -ge 0 -and $idx -lt $catalog.Count) {
                $pkg = $catalog[$idx]
                if ($pkg.IsInstalled) {
                    Write-LogWarning "Pakiet $($pkg.Name) jest już zainstalowany. Pomijanie..."
                } else {
                    $toInstall += $pkg
                }
            }
        }

        if ($toInstall.Count -gt 0) {
            Install-SoftwareList -Packages $toInstall -DryRun:$IsDryRun
            Read-Host "`nNaciśnij Enter, aby kontynuować..."
        }

    } while ($true)
}

function Revert-AllSystemTweaks {
    param([switch]$IsDryRun)

    Write-Host "`n>>> PRZYWRACANIE DOMYŚLNYCH USTAWIEŃ SYSTEMU <<<`n" -ForegroundColor Yellow
    $db = Get-TweaksDatabase

    foreach ($tw in $db.Tweaks) {
        $applied = Test-TweakApplied -Tweak $tw
        if ($applied) {
            Invoke-TweakAction -Tweak $tw -Mode "Revert" -DryRun:$IsDryRun
        }
    }

    if (-not $IsDryRun) {
        Restart-ExplorerProcess
    }
    Write-Host "`n>>> PRZYWRACANIE ZAKOŃCZONE! <<<`n" -ForegroundColor Green
}

# Obsługa parametrów wiersza poleceń (tryb bezobsługowy)
$hasCommandLineFlags = $GUI -or $All -or $Apps -or $Privacy -or $Audit -or $Cleanup -or $ResetNetwork -or $UltimatePower -or $RepairScan -or $InstallSoftware -or $SoftwareList -or $RevertAll -or $RestorePoint

if ($hasCommandLineFlags) {
    if ($GUI) {
        Start-UnbloatGUI -DryRun:$DryRun
        exit
    }

    Show-Header

    if ($RestorePoint) {
        New-SystemRestorePoint
    }
    if ($All) {
        Run-RecommendedDebloat -IsDryRun:$DryRun
        exit
    }
    if ($Audit) {
        $status = Get-SystemTweaksStatus
        $status | Select-Object @{Name="Stan"; Expression={if($_.IsApplied){"[WŁĄCZONE]"}else{"[NIEAKTYWNE]"}}}, Name, Category | Format-Table -AutoSize
        exit
    }
    if ($SoftwareList) {
        $catalog = Get-SoftwareCatalogStatus
        $catalog | Select-Object @{Name="Stan"; Expression={if($_.IsInstalled){"[ZAINSTALOWANY]"}else{"[BRAK]"}}}, Name, Category | Format-Table -AutoSize
        exit
    }
    if ($InstallSoftware) {
        $catalog = Get-SoftwareCatalogStatus
        $toInstall = $catalog | Where-Object { $_.Recommended -and -not $_.IsInstalled }
        Install-SoftwareList -Packages $toInstall -DryRun:$DryRun
        exit
    }
    if ($Cleanup) {
        Invoke-SystemCleanup -DryRun:$DryRun
    }
    if ($ResetNetwork) {
        Invoke-NetworkReset -DryRun:$DryRun
    }
    if ($UltimatePower) {
        Enable-UltimatePerformancePlan -DryRun:$DryRun
    }
    if ($RepairScan) {
        Invoke-SystemRepairScan -DryRun:$DryRun
    }
    if ($Apps) {
        $found = Find-InstalledBloatware -Category "SafeToRemove"
        Remove-BloatwareList -Items $found -DryRun:$DryRun
    }
    if ($Privacy) {
        Disable-WindowsTelemetry -DryRun:$DryRun
        Disable-TelemetryServices -DryRun:$DryRun
    }
    if ($RevertAll) {
        Revert-AllSystemTweaks -IsDryRun:$DryRun
    }
    exit
}

# Tryb interaktywny (Główne menu w konsoli)
do {
    Show-Header
    $db = Get-TweaksDatabase
    $tweakCount = if ($db -and $db.Tweaks) { $db.Tweaks.Count } else { 0 }

    Write-Host " Wybierz opcję:" -ForegroundColor White
    Write-Host "  1. Uruchom nowoczesny interfejs graficzny (WPF GUI)" -ForegroundColor Green
    Write-Host "  2. Zalecany debloat w konsoli (Punkt przywracania + Bloatware + Zalecane tweaki)" -ForegroundColor White
    Write-Host "  3. Audyt stanu systemu i przełącznik pojedynczych tweaków ($tweakCount opcji)" -ForegroundColor Cyan
    Write-Host "  4. Wykryj i usuń bezpieczne aplikacje sponsorowane (UWP)" -ForegroundColor White
    Write-Host "  5. Wykryj i usuń aplikacje opcjonalne (Xbox, Twój Telefon itp.)" -ForegroundColor White
    Write-Host "  6. Instalator czystego oprogramowania (WinGet - przeglądarki, narzędzia, VLC)" -ForegroundColor White
    Write-Host "  7. Narzędzia konserwacji i naprawy systemu (Dysk, Sieć, Zasilanie, SFC)" -ForegroundColor Yellow
    Write-Host "  8. Przywróć wszystkie domyślne ustawienia systemu (Revert Defaults)" -ForegroundColor White
    Write-Host "  9. Utwórz ręcznie punkt przywracania systemu" -ForegroundColor White
    Write-Host " 10. Przełącz tryb symulacji (Dry-Run) [Aktualnie: $(if($DryRun){'WŁĄCZONY'}else{'WYŁĄCZONY'})]" -ForegroundColor Magenta
    Write-Host "  0. Wyjście" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Wybór [0-10]"

    switch ($choice) {
        "1" {
            Start-UnbloatGUI -DryRun:$DryRun
        }
        "2" {
            Run-RecommendedDebloat -IsDryRun:$DryRun
            Read-Host "`nNaciśnij Enter, aby kontynuować..."
        }
        "3" {
            Show-SystemAuditMenu -IsDryRun:$DryRun
        }
        "4" {
            $found = Find-InstalledBloatware -Category "SafeToRemove"
            Remove-BloatwareList -Items $found -DryRun:$DryRun
            Read-Host "`nNaciśnij Enter, aby kontynuować..."
        }
        "5" {
            $found = Find-InstalledBloatware -Category "Optional"
            Remove-BloatwareList -Items $found -DryRun:$DryRun
            Read-Host "`nNaciśnij Enter, aby kontynuować..."
        }
        "6" {
            Show-SoftwareMenu -IsDryRun:$DryRun
        }
        "7" {
            Show-MaintenanceMenu -IsDryRun:$DryRun
        }
        "8" {
            Revert-AllSystemTweaks -IsDryRun:$DryRun
            Read-Host "`nNaciśnij Enter, aby kontynuować..."
        }
        "9" {
            New-SystemRestorePoint
            Read-Host "`nNaciśnij Enter, aby kontynuować..."
        }
        "10" {
            $DryRun = -not $DryRun
        }
        "0" {
            Write-Host "Do widzenia!" -ForegroundColor Cyan
            break
        }
        default {
            Write-Host "Nieprawidłowy wybór!" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "0")
