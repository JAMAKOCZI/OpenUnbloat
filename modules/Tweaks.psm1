# Tweaks.psm1 - Silnik deklaratywnych tweaków: badanie stanu (check), aplikowanie (apply) i cofanie (revert)

Import-Module (Join-Path $PSScriptRoot "Core.psm1") -DisableNameChecking

function Get-TweaksDatabase {
    $jsonPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\tweaks.json"
    if (-not (Test-Path $jsonPath)) {
        Write-LogError "Nie znaleziono pliku bazy tweaków: $jsonPath"
        return $null
    }
    return (Get-Content -Path $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

$script:CachedScheduledTasks = $null
$script:CachedWindowsCapabilities = $null

function Clear-TweaksCache {
    $script:CachedScheduledTasks = $null
    $script:CachedWindowsCapabilities = $null
}

function Test-TweakApplied {
    param([Parameter(Mandatory=$true)]$Tweak)

    $check = $Tweak.check
    if (-not $check) { return $false }

    try {
        switch ($check.type) {
            "registry" {
                if (-not (Test-Path -Path $check.path)) { return $false }
                $val = (Get-ItemProperty -Path $check.path -Name $check.name -ErrorAction SilentlyContinue).$($check.name)
                if ($null -eq $val) { return $false }
                return ([string]$val -eq [string]$check.expected)
            }
            "registry_path_exists" {
                return (Test-Path -Path $check.path)
            }
            "service" {
                $svc = Get-Service -Name $check.name -ErrorAction SilentlyContinue
                if (-not $svc) { return $false }
                $expected = switch ($check.expectedStartup) {
                    "Auto" { "Automatic" }
                    default { $check.expectedStartup }
                }
                return ($svc.StartType.ToString() -eq $expected -or $svc.StartType.ToString() -eq $check.expectedStartup)
            }
            "scheduled_task" {
                $patterns = if ($check.patterns) { @($check.patterns) } else { @($check.name) }
                if ($null -eq $script:CachedScheduledTasks) {
                    $script:CachedScheduledTasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
                }
                $matched = $script:CachedScheduledTasks | Where-Object {
                    $tName = $_.TaskName
                    $hasMatch = $false
                    foreach ($pat in $patterns) {
                        if ($tName -like $pat) { $hasMatch = $true; break }
                    }
                    $hasMatch
                }
                if (-not $matched) { return $false }
                
                # Wszystkie znalezione pasujące zadania muszą mieć oczekiwany stan (np. Disabled)
                $allMatch = $true
                foreach ($t in $matched) {
                    if ($t.State.ToString() -ne $check.expectedState) {
                        $allMatch = $false
                        break
                    }
                }
                return $allMatch
            }
            "optional_feature" {
                try {
                    $feat = Get-WindowsOptionalFeature -Online -FeatureName $check.name -ErrorAction Stop
                    if ($feat) {
                        return ($feat.State.ToString() -eq $check.expectedState)
                    }
                }
                catch {
                    return $false
                }
                return $false
            }
            "capability" {
                try {
                    if ($null -eq $script:CachedWindowsCapabilities) {
                        $script:CachedWindowsCapabilities = @(Get-WindowsCapability -Online -ErrorAction SilentlyContinue)
                    }
                    $caps = $script:CachedWindowsCapabilities | Where-Object { $_.Name -like "$($check.name)*" }
                    if ($caps) {
                        return ($caps[0].State.ToString() -eq $check.expectedState)
                    }
                }
                catch {
                    return $false
                }
                return $false
            }
            default {
                return $false
            }
        }
    }
    catch {
        return $false
    }
}

function Invoke-TweakAction {
    param(
        [Parameter(Mandatory=$true)]$Tweak,
        [ValidateSet("Apply", "Revert")][string]$Mode = "Apply",
        [switch]$DryRun
    )

    $actionList = if ($Mode -eq "Apply") { $Tweak.apply } else { $Tweak.revert }
    if (-not $actionList) { return }

    $verb = if ($Mode -eq "Apply") { "Aplikowanie" } else { "Cofanie" }
    Write-LogInfo "$($verb) - $($Tweak.name)..."

    foreach ($act in $actionList) {
        if ($DryRun) {
            Write-Host "   [TRYB SYMULACJI] Akcja: $($act.type) ($($act.name))" -ForegroundColor DarkGray
            continue
        }

        try {
            switch ($act.type) {
                "registry" {
                    $propType = if ($act.propertyType) { $act.propertyType } else { "DWord" }
                    Set-RegistryValueSafe -Path $act.path -Name $act.name -Value $act.value -PropertyType $propType | Out-Null
                }
                "registry_default" {
                    if (-not (Test-Path -Path $act.path)) {
                        New-Item -Path $act.path -Force | Out-Null
                    }
                    Set-ItemProperty -Path $act.path -Name "(Default)" -Value $act.value -Force | Out-Null
                }
                "registry_delete" {
                    if (Test-Path -Path $act.path) {
                        Remove-ItemProperty -Path $act.path -Name $act.name -Force -ErrorAction SilentlyContinue
                    }
                }
                "registry_key_delete" {
                    if (Test-Path -Path $act.path) {
                        Remove-Item -Path $act.path -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                "service" {
                    $svc = Get-Service -Name $act.name -ErrorAction SilentlyContinue
                    if ($svc) {
                        if ($act.state -eq "Stopped" -and $svc.Status -ne "Stopped") {
                            Stop-Service -Name $act.name -Force -ErrorAction SilentlyContinue
                        }
                        elseif ($act.state -eq "Running" -and $svc.Status -ne "Running") {
                            Start-Service -Name $act.name -ErrorAction SilentlyContinue
                        }
                        if ($act.startupType) {
                            Set-Service -Name $act.name -StartupType $act.startupType -ErrorAction SilentlyContinue
                        }
                    }
                }
                "scheduled_task" {
                    $patterns = if ($act.patterns) { @($act.patterns) } else { @($act.name) }
                    $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
                    $matching = $allTasks | Where-Object {
                        $tName = $_.TaskName
                        $match = $false
                        foreach ($pat in $patterns) {
                            if ($tName -like $pat) { $match = $true; break }
                        }
                        $match
                    }
                    foreach ($t in $matching) {
                        if ($act.state -eq "Disabled") {
                            Disable-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue | Out-Null
                        }
                        elseif ($act.state -eq "Ready") {
                            Enable-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
                "optional_feature" {
                    if ($act.state -eq "Disabled") {
                        Disable-WindowsOptionalFeature -Online -FeatureName $act.name -NoRestart -ErrorAction SilentlyContinue | Out-Null
                    }
                    elseif ($act.state -eq "Enabled") {
                        Enable-WindowsOptionalFeature -Online -FeatureName $act.name -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
                    }
                }
                "capability" {
                    $caps = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($act.name)*" }
                    foreach ($c in $caps) {
                        if ($act.state -eq "NotPresent") {
                            Remove-WindowsCapability -Online -Name $c.Name -ErrorAction SilentlyContinue | Out-Null
                        }
                        elseif ($act.state -eq "Installed") {
                            Add-WindowsCapability -Online -Name $c.Name -ErrorAction SilentlyContinue | Out-Null
                        }
                    }
                }
            }
        }
        catch {
            Write-LogWarning "   Błąd wykonania akcji ($($act.type)): $($_.Exception.Message)"
        }
    }

    if (-not $DryRun) {
        Write-LogSuccess "$($Tweak.name) -> pomyślnie zaktualizowano."
    }
}

function Get-SystemTweaksStatus {
    $db = Get-TweaksDatabase
    if (-not $db) { return @() }

    $statusList = @()
    foreach ($tw in $db.Tweaks) {
        $isApplied = Test-TweakApplied -Tweak $tw
        $statusList += [PSCustomObject]@{
            Id          = $tw.id
            Name        = $tw.name
            Category    = $tw.category
            Description = $tw.description
            Risk        = $tw.risk
            Presets     = $tw.presets
            IsApplied   = $isApplied
            RawTweak    = $tw
        }
    }
    return ,$statusList
}

function Reset-AllSystemTweaks {
    param([switch]$IsDryRun)
    $db = Get-TweaksDatabase
    if (-not $db) { return }
    foreach ($tw in $db.Tweaks) {
        Invoke-TweakAction -Tweak $tw -Mode "Revert" -DryRun:$IsDryRun
    }
}

Set-Alias -Name Revert-AllSystemTweaks -Value Reset-AllSystemTweaks -Scope Global

Export-ModuleMember -Function Get-TweaksDatabase, Test-TweakApplied, Invoke-TweakAction, Get-SystemTweaksStatus, Reset-AllSystemTweaks, Clear-TweaksCache -Alias Revert-AllSystemTweaks
