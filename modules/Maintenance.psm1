# Maintenance.psm1 - Narzędzia konserwacji: czyszczenie dysku, reset sieci, naprawa systemu, plan zasilania, Windows Update i WinGet

Import-Module (Join-Path $PSScriptRoot "Core.psm1") -DisableNameChecking

function Invoke-SystemCleanup {
    param([switch]$DryRun)

    Write-LogInfo "Rozpoczynanie czyszczenia plików tymczasowych i pamięci podręcznej..."

    $targets = @(
        $env:TEMP,
        (Join-Path $env:SystemRoot "Temp"),
        (Join-Path $env:SystemRoot "SoftwareDistribution\Download"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Explorer\thumbcache_*.db"),
        (Join-Path $env:LOCALAPPDATA "CrashDumps")
    )

    $totalReclaimedBytes = 0

    foreach ($path in $targets) {
        if (-not (Test-Path -Path $path)) { continue }

        Write-LogInfo "Skanowanie i oczyszczanie: $path..."
        $files = Get-ChildItem -Path $path -Recurse -Force -File -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            $totalReclaimedBytes += $file.Length
            if (-not $DryRun) {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        # Usuń puste podfoldery
        if (-not $DryRun) {
            Get-ChildItem -Path $path -Recurse -Force -Directory -ErrorAction SilentlyContinue |
                Sort-Object -Property FullName -Descending |
                ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        }
    }

    # Opróżnienie Kosza
    if (-not $DryRun) {
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null
            Write-LogSuccess "Kosz systemowy został opróżniony."
        }
        catch { }
    }

    $reclaimedMB = [math]::Round($totalReclaimedBytes / 1MB, 2)
    if ($DryRun) {
        Write-Host "   [TRYB SYMULACJI] Zwolniłby w przybliżeniu: $reclaimedMB MB danych." -ForegroundColor Magenta
    }
    else {
        Write-LogSuccess "Czyszczenie zakończone! Zwolniono około: $reclaimedMB MB miejsca na dysku."
    }
}

function Invoke-NetworkReset {
    param([switch]$DryRun)

    Write-LogInfo "Czyszczenie pamięci podręcznej DNS i resetowanie stosu sieciowego..."

    if ($DryRun) {
        Write-Host "   [TRYB SYMULACJI] Zresetowałby winsock, IP oraz wyczyścił DNS." -ForegroundColor DarkGray
        return
    }

    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-LogSuccess "Stos sieciowy i pamięć podręczna DNS zostały pomyślnie zresetowane."
    }
    catch {
        Write-LogWarning "Wystąpił problem podczas resetowania sieci: $($_.Exception.Message)"
    }
}

function Enable-UltimatePerformancePlan {
    param([switch]$DryRun)

    Write-LogInfo "Odblokowywanie i aktywacja planu zasilania 'Najwyższa wydajność' (Ultimate Performance)..."

    if ($DryRun) {
        Write-Host "   [TRYB SYMULACJI] Aktywowałby plan Ultimate Performance." -ForegroundColor DarkGray
        return
    }

    try {
        $duplicated = powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
        $guid = ($duplicated | Select-String -Pattern '[A-Fa-f0-9-]{36}').Matches.Value
        if ($guid) {
            powercfg /setactive $guid
            Write-LogSuccess "Plan zasilania 'Najwyższa wydajność' został pomyślnie aktywowany."
        }
        else {
            Write-LogWarning "Nie udało się wyodrębnić identyfikatora GUID planu zasilania."
        }
    }
    catch {
        Write-LogError "Błąd podczas aktywacji planu zasilania: $($_.Exception.Message)"
    }
}

function Invoke-SystemRepairScan {
    param([switch]$DryRun)

    Write-LogInfo "Uruchamianie diagnostyki integralności plików systemowych (SFC & DISM)..."

    if ($DryRun) {
        Write-Host "   [TRYB SYMULACJI] Wykonałby DISM /Online /Cleanup-Image /RestoreHealth oraz SFC /scannow." -ForegroundColor DarkGray
        return
    }

    Write-LogInfo "Krok 1/2: Naprawa obrazu za pomocą DISM (może potrwać kilka minut)..."
    & "$env:SystemRoot\System32\Dism.exe" /Online /Cleanup-Image /RestoreHealth

    Write-LogInfo "Krok 2/2: Skanowanie i naprawa plików chronionych za pomocą SFC..."
    & "$env:SystemRoot\System32\sfc.exe" /scannow

    Write-LogSuccess "Diagnostyka i naprawa systemu Windows została ukończona."
}

function Reset-WindowsUpdateCache {
    param([switch]$DryRun)

    Write-LogInfo "Rozpoczynanie resetowania pamięci podręcznej Windows Update..."

    if ($DryRun) {
        Write-Host "   [TRYB SYMULACJI] Zatrzymałby wuauserv, bits, cryptsvc i wyczyścił foldery SoftwareDistribution i Catroot2." -ForegroundColor DarkGray
        return
    }

    try {
        Write-LogInfo "Zatrzymywanie usług aktualizacji..."
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
        Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

        $sd = Join-Path $env:SystemRoot "SoftwareDistribution"
        $cat = Join-Path $env:SystemRoot "System32\catroot2"

        if (Test-Path $sd) {
            Remove-Item -Path "$sd\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-LogInfo "Ponowne uruchamianie usług aktualizacji..."
        Start-Service -Name cryptsvc -ErrorAction SilentlyContinue
        Start-Service -Name bits -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue

        Write-LogSuccess "Pamięć podręczna Windows Update została wyczyszczona, a usługi pomyślnie zrestartowane."
    }
    catch {
        Write-LogWarning "Wystąpił błąd podczas resetowania Windows Update: $($_.Exception.Message)"
    }
}

function Repair-WinGetEnvironment {
    param([switch]$DryRun)

    Write-LogInfo "Weryfikacja i naprawa repozytoriów pakietów WinGet..."

    if ($DryRun) {
        Write-Host "   [TRYB SYMULACJI] Zresetowałby oficjalne źródła winget i odświeżył metadane." -ForegroundColor DarkGray
        return
    }

    try {
        Write-LogInfo "Resetowanie oficjalnych źródeł WinGet..."
        Start-Process -FilePath "winget" -ArgumentList "source reset --force" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -Wait -ErrorAction SilentlyContinue

        $pkg = Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*" -ErrorAction SilentlyContinue
        if ($pkg -and $pkg.InstallLocation) {
            Add-AppxPackage -DisableDevelopmentMode -Register "$($pkg.InstallLocation)\AppxManifest.xml" -ErrorAction SilentlyContinue
        }
        Write-LogSuccess "Środowisko WinGet oraz jego źródła zostały pomyślnie naprawione i zaktualizowane."
    }
    catch {
        Write-LogWarning "Błąd naprawy WinGet: $($_.Exception.Message)"
    }
}

function Export-SystemRegistryBackup {
    param(
        [string]$DestinationPath = ""
    )

    if (-not $DestinationPath) {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $DestinationPath = Join-Path $desktop "Unbloat_Registry_Backup_$((Get-Date).ToString('yyyyMMdd_HHmmss')).reg"
    }

    Write-LogInfo "Eksportowanie kopii zapasowej kluczowych gałęzi rejestru..."

    try {
        $hives = @(
            "HKCU\Software\Policies\Microsoft\Windows",
            "HKLM\SOFTWARE\Policies\Microsoft\Windows",
            "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        )
        $combined = "Windows Registry Editor Version 5.00`r`n`r`n"
        foreach ($h in $hives) {
            $tmp = [System.IO.Path]::GetTempFileName()
            & reg.exe export "$h" "$tmp" /y 2>$null | Out-Null
            if (Test-Path $tmp) {
                $content = [System.IO.File]::ReadAllText($tmp)
                $content = $content -replace "^Windows Registry Editor Version 5\.00\r?\n\r?\n", ""
                $combined += "; Hive: $h`r`n" + $content + "`r`n`r`n"
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }
        [System.IO.File]::WriteAllText($DestinationPath, $combined, [System.Text.Encoding]::Unicode)
        Write-LogSuccess "Kopia rejestru została pomyślnie zapisana w: $DestinationPath"
        return $DestinationPath
    }
    catch {
        Write-LogError "Błąd podczas eksportu kopii rejestru: $($_.Exception.Message)"
        return $null
    }
}

function Set-NetworkDNSProvider {
    param(
        [Parameter(Mandatory=$true)][ValidateSet("Cloudflare", "Quad9", "Google", "DHCP")][string]$Provider,
        [switch]$DryRun
    )

    $dnsServers = switch ($Provider) {
        "Cloudflare" { @("1.1.1.1", "1.0.0.1") }
        "Quad9"      { @("9.9.9.9", "149.112.112.112") }
        "Google"     { @("8.8.8.8", "8.8.4.4") }
        "DHCP"       { @() }
    }

    if ($DryRun) {
        if ($Provider -eq "DHCP") {
            Write-Host "   [TRYB SYMULACJI] Przywróciłby automatyczny DNS (DHCP) dla aktywnych kart sieciowych." -ForegroundColor Magenta
        } else {
            Write-Host "   [TRYB SYMULACJI] Ustawiłby DNS $Provider ($($dnsServers -join ', ')) dla aktywnych kart sieciowych." -ForegroundColor Magenta
        }
        return
    }

    Write-LogInfo "Konfigurowanie profilu DNS ($Provider)..."
    try {
        $activeAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notmatch "Virtual|Hyper-V|VMware|Loopback|TAP" }
        if (-not $activeAdapters) {
            $activeAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        }

        foreach ($adapter in $activeAdapters) {
            if ($Provider -eq "DHCP") {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
                Write-LogSuccess "Karta $($adapter.Name): Przywrócono automatyczny DNS (DHCP)."
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServers -ErrorAction SilentlyContinue
                Write-LogSuccess "Karta $($adapter.Name): Ustawiono serwery DNS $Provider ($($dnsServers -join ', '))."
            }
        }

        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-LogSuccess "Pomyślnie zaktualizowano konfigurację DNS i wyczyszczono pamięć podręczną DNS resolvera."
    }
    catch {
        Write-LogError "Błąd podczas ustawiania DNS: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Invoke-SystemCleanup, Invoke-NetworkReset, Enable-UltimatePerformancePlan, Invoke-SystemRepairScan, Reset-WindowsUpdateCache, Repair-WinGetEnvironment, Export-SystemRegistryBackup, Set-NetworkDNSProvider
