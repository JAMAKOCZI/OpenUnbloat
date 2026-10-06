# Software.psm1 - Zarządzanie instalacją czystego oprogramowania za pomocą Windows Package Manager (winget)

Import-Module (Join-Path $PSScriptRoot "Core.psm1") -DisableNameChecking

function Test-WinGetAvailable {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-SoftwareDatabase {
    $jsonPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\software.json"
    if (-not (Test-Path $jsonPath)) {
        Write-LogError "Nie znaleziono bazy oprogramowania: $jsonPath"
        return $null
    }
    return (Get-Content -Path $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

$script:CachedSoftwareCatalog = $null

function Clear-SoftwareCatalogCache {
    $script:CachedSoftwareCatalog = $null
}

function Get-SoftwareCatalogStatus {
    param(
        [switch]$ForceRefresh,
        [switch]$IncludeWinGet
    )

    if ($null -ne $script:CachedSoftwareCatalog -and -not $ForceRefresh) {
        return $script:CachedSoftwareCatalog
    }

    $db = Get-SoftwareDatabase
    if (-not $db) { return @() }

    # 1. Błyskawiczne odpytanie rejestru odinstalowywania (HKLM, WOW6432Node, HKCU) - trwa ok. 25 ms
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $installedReg = try {
        Get-ItemProperty -Path $regPaths -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName } | 
            Select-Object DisplayName, DisplayVersion, Publisher
    } catch {
        @()
    }

    # 2. Pobierz winget list tylko jeśli zażądano głębokiego skanowania (domyślnie rejestr jest 50x szybszy na starcie)
    $wingetListText = ""
    if ($IncludeWinGet -and (Test-WinGetAvailable)) {
        try {
            $prevEnc = [Console]::OutputEncoding
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
            
            $tmpFile = Join-Path $env:TEMP "unbloat_winget_list.txt"
            if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue }
            
            $proc = Start-Process -FilePath "winget" -ArgumentList "list --accept-source-agreements --disable-interactivity" -NoNewWindow -PassThru -RedirectStandardOutput $tmpFile -ErrorAction SilentlyContinue
            if ($proc -and $proc.WaitForExit(7000)) {
                if (Test-Path $tmpFile) {
                    $wingetListText = [System.IO.File]::ReadAllText($tmpFile, [System.Text.Encoding]::UTF8)
                    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
                }
            } else {
                if ($proc) { $proc.Kill() }
            }
            [Console]::OutputEncoding = $prevEnc
        } catch {
            $wingetListText = ""
        }
    }

    $results = @()
    foreach ($pkg in $db.Packages) {
        $patterns = if ($pkg.detectPatterns) { @($pkg.detectPatterns) } else { @("*$($pkg.name)*") }

        # A. Weryfikacja w rejestrze Windows (obsługuje instalatory MSI, EXE, portable itp.)
        $regMatch = $installedReg | Where-Object {
            $disp = $_.DisplayName
            $matched = $false
            foreach ($pat in $patterns) {
                if ($disp -like $pat) {
                    $matched = $true
                    break
                }
            }
            $matched
        }

        # B. Weryfikacja w katalogu WinGet (obsługuje pakiety instalowane bezpośrednio przez winget)
        $wingetMatch = $false
        if ($wingetListText) {
            if ($pkg.id -and $wingetListText -match [regex]::Escape($pkg.id)) {
                $wingetMatch = $true
            } elseif ($pkg.name -and $wingetListText -match [regex]::Escape($pkg.name)) {
                $wingetMatch = $true
            }
        }

        $isInstalled = [bool]($regMatch -or $wingetMatch)

        $results += [PSCustomObject]@{
            Id             = $pkg.id
            Name           = $pkg.name
            Category       = $pkg.category
            Description    = $pkg.description
            Recommended    = [bool]$pkg.recommended
            IsInstalled    = $isInstalled
            DetectPatterns = $patterns
            RawPackage     = $pkg
        }
    }

    $script:CachedSoftwareCatalog = ,$results
    return ,$results
}

function Install-SoftwarePackage {
    param(
        [Parameter(Mandatory=$true)][string]$PackageId,
        [Parameter(Mandatory=$false)][string]$Name = "",
        [switch]$DryRun
    )

    $displayName = if ($Name) { $Name } else { $PackageId }

    if ($DryRun) {
        Write-Host "   [TRYB SYMULACJI] Zainstalowałby pakiet: $displayName ($PackageId)" -ForegroundColor Magenta
        return $true
    }

    Write-LogInfo "Pobieranie i instalowanie: $displayName ($PackageId)..."
    try {
        $process = Start-Process -FilePath "winget" -ArgumentList "install --id `"$PackageId`" --exact --accept-package-agreements --accept-source-agreements --silent" -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-LogSuccess "$displayName został pomyślnie zainstalowany."
            Clear-SoftwareCatalogCache
            return $true
        }
        else {
            Write-LogWarning "Instalacja $displayName zakończyła się kodem wyjścia: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-LogError "Błąd podczas wywoływania winget dla $($displayName): $($_.Exception.Message)"
        return $false
    }
}

function Install-SoftwareList {
    param(
        [Parameter(Mandatory=$true)][array]$Packages,
        [switch]$DryRun
    )

    if ($Packages.Count -eq 0) {
        Write-LogWarning "Brak wybranych pakietów do zainstalowania."
        return
    }

    Write-Host "`n>>> ROZPOCZYNAM INSTALACJĘ $($Packages.Count) PAKIETÓW <<<`n" -ForegroundColor Yellow

    foreach ($pkg in $Packages) {
        $null = Install-SoftwarePackage -PackageId $pkg.Id -Name $pkg.Name -DryRun:$DryRun
    }

    Clear-SoftwareCatalogCache

    # Odświeżenie zmiennych środowiskowych PATH w bieżącej sesji po instalacji nowych programów
    try {
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"
    } catch {}

    Write-Host "`n>>> PROCES INSTALACJI ZAKOŃCZONY <<<`n" -ForegroundColor Green
}

Export-ModuleMember -Function Test-WinGetAvailable, Get-SoftwareDatabase, Get-SoftwareCatalogStatus, Clear-SoftwareCatalogCache, Install-SoftwarePackage, Install-SoftwareList
