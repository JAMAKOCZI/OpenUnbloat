# Apps.psm1 - Wykrywanie i usuwanie pakietów UWP / Bloatware

Import-Module (Join-Path $PSScriptRoot "Core.psm1") -DisableNameChecking

function Get-BloatwareDefinition {
    $jsonPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\bloat-apps.json"
    if (-not (Test-Path $jsonPath)) {
        Write-LogError "Nie znaleziono pliku definicji aplikacji: $jsonPath"
        return $null
    }
    return (Get-Content -Path $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

# Lista pakietów krytycznych dla działania systemu, które NIGDY nie mogą zostać usunięte
$script:ProtectedPackages = @(
    "*Microsoft.WindowsStore*",
    "*Microsoft.StorePurchaseApp*",
    "*Microsoft.DesktopAppInstaller*",
    "*Microsoft.VCLibs*",
    "*Microsoft.NET.Native*",
    "*Microsoft.UI.Xaml*",
    "*Microsoft.Windows.ShellExperienceHost*",
    "*Microsoft.Windows.StartMenuExperienceHost*",
    "*Microsoft.Windows.Search*",
    "*Microsoft.WindowsTerminal*"
)

$script:CachedInstalledPackages = $null
$script:CachedProvisionedPackages = $null

function Clear-AppxPackageCache {
    $script:CachedInstalledPackages = $null
    $script:CachedProvisionedPackages = $null
}

function Get-InstalledAppxPackages {
    param([switch]$ForceRefresh)

    if ($null -eq $script:CachedInstalledPackages -or $ForceRefresh) {
        Write-LogInfo "Skanowanie zainstalowanych pakietów UWP i Provisioned w systemie..."
        $script:CachedInstalledPackages = try {
            Get-AppxPackage -AllUsers -ErrorAction Stop
        }
        catch {
            Get-AppxPackage -ErrorAction SilentlyContinue
        }

        $script:CachedProvisionedPackages = try {
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }
        catch {
            @()
        }
    }

    return @{
        UserPackages        = $script:CachedInstalledPackages
        ProvisionedPackages = $script:CachedProvisionedPackages
    }
}

function Get-BloatwareCatalogStatus {
    param([switch]$ForceRefresh)

    $definitions = Get-BloatwareDefinition
    if (-not $definitions) { return @() }

    $allPackages = Get-InstalledAppxPackages -ForceRefresh:$ForceRefresh
    $userPkgs = $allPackages.UserPackages
    $provPkgs = $allPackages.ProvisionedPackages

    $catalog = [System.Collections.Generic.List[object]]::new()

    $checkGroup = {
        param($items, [string]$groupName)
        foreach ($item in $items) {
            $patterns = ($item.pattern -split '\|') | ForEach-Object { $_.Trim() }

            $matchedUser = [System.Collections.Generic.List[object]]::new()
            if ($userPkgs) {
                foreach ($pkg in $userPkgs) {
                    $pkgName = $pkg.Name
                    $isProtected = $false
                    foreach ($prot in $script:ProtectedPackages) {
                        if ($pkgName -like $prot) { $isProtected = $true; break }
                    }
                    if ($isProtected) { continue }

                    $fullName = $pkg.PackageFullName
                    foreach ($pat in $patterns) {
                        if ($pkgName -like $pat -or $fullName -like $pat) {
                            $matchedUser.Add($pkg)
                            break
                        }
                    }
                }
            }

            $matchedProv = [System.Collections.Generic.List[object]]::new()
            if ($provPkgs) {
                foreach ($prov in $provPkgs) {
                    $dispName = $prov.DisplayName
                    $isProtected = $false
                    foreach ($prot in $script:ProtectedPackages) {
                        if ($dispName -like $prot) { $isProtected = $true; break }
                    }
                    if ($isProtected) { continue }

                    $pkgName = $prov.PackageName
                    foreach ($pat in $patterns) {
                        if ($dispName -like $pat -or $pkgName -like $pat) {
                            $matchedProv.Add($prov)
                            break
                        }
                    }
                }
            }

            $isInstalled = ($matchedUser.Count -gt 0 -or $matchedProv.Count -gt 0)

            $null = $catalog.Add([PSCustomObject]@{
                DisplayName         = $item.name
                Pattern             = $item.pattern
                Patterns            = $patterns
                Description         = $item.description
                Category            = $groupName
                IsSafe              = ($groupName -eq "SafeToRemove")
                IsInstalled         = $isInstalled
                MatchedUserPackages = $matchedUser
                MatchedProvPackages = $matchedProv
            })
        }
    }

    if ($definitions.SafeToRemove) {
        & $checkGroup $definitions.SafeToRemove "SafeToRemove"
    }
    if ($definitions.Optional) {
        & $checkGroup $definitions.Optional "Optional"
    }

    return ,$catalog.ToArray()
}

function Find-InstalledBloatware {
    param(
        [string]$Category = "SafeToRemove",
        [switch]$ForceRefresh
    )

    $catalog = Get-BloatwareCatalogStatus -ForceRefresh:$ForceRefresh
    return ,@($catalog | Where-Object { $_.Category -eq $Category -and $_.IsInstalled })
}

function Remove-BloatwareList {
    param(
        [Parameter(Mandatory=$false)][array]$Items = @(),
        [switch]$DryRun
    )

    if (-not $Items -or $Items.Count -eq 0) {
        Write-LogSuccess "Brak wybranych aplikacji do usunięcia."
        return
    }

    Write-LogInfo "Rozpoczynam usuwanie $($Items.Count) wybranych pozycji..."

    foreach ($item in $Items) {
        $name = $item.DisplayName
        $patterns = if ($item.Patterns) { @($item.Patterns) } else { @($item.Pattern -split '\|' | ForEach-Object { $_.Trim() }) }

        # Podwójne zabezpieczenie przed usunięciem składnika krytycznego
        $isProtected = [bool]($script:ProtectedPackages | Where-Object {
            $p = $_
            $patterns | Where-Object { $_ -like $p }
        })
        if ($isProtected) {
            Write-LogWarning "Pominięto chroniony komponent ($name) wymagany przez Windows."
            continue
        }

        if ($DryRun) {
            Write-Host "   [TRYB SYMULACJI] Usunąłby aplikację: $name" -ForegroundColor DarkGray
            continue
        }

        # Pre-flight Process Termination (zapobieganie blokowaniu plików i zawieszaniu skryptu błędem 0x80073D02)
        $procKillMap = @{
            "OneDrive"                  = @("OneDrive")
            "Copilot"                   = @("Copilot")
            "Widgets|Feeds"             = @("Widgets", "widgetservice")
            "Cortana"                   = @("Cortana")
            "YourPhone|Phone"           = @("PhoneExperienceHost", "YourPhone")
            "Skype"                     = @("Skype", "SkypeBridge")
            "Teams"                     = @("Teams", "msteams")
            "XboxGamingOverlay|XboxApp" = @("GameBarFTServer", "XboxPcApp")
            "WindowsNotepad"            = @("dllhost")
        }

        foreach ($procKey in $procKillMap.Keys) {
            if ($item.Pattern -match $procKey) {
                foreach ($procName in $procKillMap[$procKey]) {
                    Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false -ErrorAction SilentlyContinue
                }
            }
        }

        if ($item.Pattern -match "XboxGamingOverlay|XboxApp") {
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
        }

        Write-LogInfo "Usuwanie: $name..."

        # 1. Usuń pakiety użytkowników
        try {
            $userPkgs = try { Get-AppxPackage -AllUsers -ErrorAction Stop } catch { Get-AppxPackage -ErrorAction SilentlyContinue }
            $matchedUser = $userPkgs | Where-Object {
                $pkg = $_
                $m = $false
                foreach ($pat in $patterns) {
                    if ($pkg.Name -like $pat -or $pkg.PackageFullName -like $pat) { $m = $true; break }
                }
                $m
            }
            foreach ($pkg in $matchedUser) {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                }
                catch {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-LogWarning "Nie udało się całkowicie usunąć pakietów użytkownika dla $($name): $($_.Exception.Message)"
        }

        # 2. Usuń pakiety przygotowane (Provisioned)
        try {
            $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            $matchedProv = $provPkgs | Where-Object {
                $prov = $_
                $m = $false
                foreach ($pat in $patterns) {
                    if ($prov.DisplayName -like $pat -or $prov.PackageName -like $pat) { $m = $true; break }
                }
                $m
            }
            foreach ($prov in $matchedProv) {
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }
        catch {
            Write-LogWarning "Nie udało się usunąć pakietu provisioned dla $($name)"
        }

        Write-LogSuccess "Usunięto: $name"
    }

    Clear-AppxPackageCache
}

Export-ModuleMember -Function Get-BloatwareDefinition, Get-InstalledAppxPackages, Get-BloatwareCatalogStatus, Find-InstalledBloatware, Remove-BloatwareList, Clear-AppxPackageCache
