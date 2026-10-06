# UI.psm1 - Optymalizacje interfejsu, usuwanie reklam i Binga, konfiguracja paska zadań

Import-Module (Join-Path $PSScriptRoot "Core.psm1") -DisableNameChecking

function Disable-BingSearchInStart {
    param([switch]$DryRun)

    Write-LogInfo "Wyłączanie wyszukiwania Bing i sugestii w Menu Start..."

    if ($DryRun) {
        Write-Host " [TRYB SYMULACJI] Wyłączyłby Bing w Menu Start." -ForegroundColor DarkGray
        return
    }

    Set-RegistryValueSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
    Write-LogSuccess "Wyszukiwarka Bing w Menu Start została wyłączona."
}

function Disable-WindowsTipsAndAds {
    param([switch]$DryRun)

    Write-LogInfo "Wyłączanie porad, wskazówek i reklam w systemie Windows..."

    if ($DryRun) {
        Write-Host " [TRYB SYMULACJI] Zablokowałby porady i sugestie reklamowe w interfejsie." -ForegroundColor DarkGray
        return
    }

    $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-RegistryValueSafe -Path $cdmPath -Name "SubscribedContent-338388Enabled" -Value 0 # Sugestie w menu Start
    Set-RegistryValueSafe -Path $cdmPath -Name "SubscribedContent-338389Enabled" -Value 0 # Porady i wskazówki w Ustawieniach
    Set-RegistryValueSafe -Path $cdmPath -Name "SystemPaneSuggestionsEnabled" -Value 0
    Set-RegistryValueSafe -Path $cdmPath -Name "SoftLandingEnabled" -Value 0

    Write-LogSuccess "Porady i sugestie sponsorowane zostały wyłączone."
}

function Disable-TaskbarWidgets {
    param([switch]$DryRun)

    Write-LogInfo "Ukrywanie widżetów na pasku zadań..."

    if ($DryRun) {
        Write-Host " [TRYB SYMULACJI] Ukryłby widżety paska zadań." -ForegroundColor DarkGray
        return
    }

    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
    Write-LogSuccess "Widżety paska zadań zostały ukryte."
}

function Enable-ClassicContextMenu {
    param([switch]$DryRun)

    Write-LogInfo "Przywracanie klasycznego menu kontekstowego (styl Windows 10)..."

    if ($DryRun) {
        Write-Host " [TRYB SYMULACJI] Włączyłby klasyczne menu kontekstowe." -ForegroundColor DarkGray
        return
    }

    $clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    if (-not (Test-Path $clsidPath)) {
        New-Item -Path $clsidPath -Force | Out-Null
    }
    Set-ItemProperty -Path $clsidPath -Name "(Default)" -Value "" -Force | Out-Null

    Write-LogSuccess "Klasyczne menu kontekstowe zostało włączone."
}

function Disable-ClassicContextMenu {
    param([switch]$DryRun)

    Write-LogInfo "Przywracanie domyślnego menu kontekstowego Windows 11..."

    if ($DryRun) {
        Write-Host " [TRYB SYMULACJI] Przywróciłby domyślne menu Windows 11." -ForegroundColor DarkGray
        return
    }

    $clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    if (Test-Path $clsidPath) {
        Remove-Item -Path $clsidPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-LogSuccess "Domyślne menu kontekstowe Windows 11 zostało przywrócone."
}

function Restart-ExplorerProcess {
    Write-LogInfo "Restartowanie procesu Eksploratora Windows, aby zastosować zmiany..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer.exe
    Write-LogSuccess "Eksplorator Windows został zrestartowany."
}

Export-ModuleMember -Function Disable-BingSearchInStart, Disable-WindowsTipsAndAds, Disable-TaskbarWidgets, Enable-ClassicContextMenu, Disable-ClassicContextMenu, Restart-ExplorerProcess
