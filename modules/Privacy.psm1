# Privacy.psm1 - Telemetria, diagnostyka, ochrona prywatności i usługi w tle

Import-Module (Join-Path $PSScriptRoot "Core.psm1") -DisableNameChecking

function Disable-WindowsTelemetry {
    param([switch]$DryRun)

    Write-LogInfo "Konfiguracja telemetrii i diagnostyki..."

    if ($DryRun) {
        Write-Host " [TRYB SYMULACJI] Zablokowałby telemetrię i zbieranie danych diagnostycznych." -ForegroundColor DarkGray
        return
    }

    # 1. Wyłączenie zbierania danych telemetrii (Security / Minimal level)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1

    # 2. Wyłączenie spersonalizowanych doświadczeń na podstawie danych diagnostycznych
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0

    # 3. Wyłączenie identyfikatora reklam (Advertising ID)
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0

    # 4. Wyłączenie historii aktywności (Timeline / Activity Feed)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0

    # 5. Blokada automatycznego doinstalowywania aplikacji sponsorowanych (Consumer Features)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1

    Write-LogSuccess "Zasady telemetrii i prywatności zostały zaktualizowane."
}

function Disable-TelemetryServices {
    param([switch]$DryRun)

    $services = @("DiagTrack", "dmwappushservice")

    foreach ($svcName in $services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($DryRun) {
                Write-Host " [TRYB SYMULACJI] Zatrzymałby i wyłączył usługę: $svcName" -ForegroundColor DarkGray
                continue
            }

            try {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-LogSuccess "Usługa wyłączona: $svcName"
            }
            catch {
                Write-LogWarning "Nie udało się wyłączyć usługi: $svcName"
            }
        }
    }
}

Export-ModuleMember -Function Disable-WindowsTelemetry, Disable-TelemetryServices
