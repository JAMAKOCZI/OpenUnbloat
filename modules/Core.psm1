# Core.psm1 - Podstawowe narzędzia: uprawnienia, logowanie, punkt przywracania, rejestr

function Test-IsAdmin {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    param(
        [switch]$AllowNonAdmin,
        [string[]]$ForwardArgs
    )
    if (-not (Test-IsAdmin)) {
        if ($AllowNonAdmin) {
            Write-LogWarning "Skrypt działa bez uprawnień Administratora. Część operacji (np. usuwanie z rejestru HKLM, usługi) wymaga podwyższonych uprawnień."
            return
        }
        Write-Host " [!] Wymagane są uprawnienia Administratora. Uruchamianie z podwyższonymi uprawnieniami..." -ForegroundColor Yellow
        $scriptPath = $PSCommandPath
        if (-not $scriptPath -and $MyInvocation.PSCommandPath) {
            $scriptPath = $MyInvocation.PSCommandPath
        }
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"")
        if ($ForwardArgs) {
            $argList += ($ForwardArgs -join " ")
        }
        $argString = $argList -join " "
        Start-Process -FilePath "powershell.exe" -ArgumentList $argString -Verb RunAs
        exit
    }
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host " [i] $Message" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host " [+] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host " [!] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host " [-] $Message" -ForegroundColor Red
}

function New-SystemRestorePoint {
    param(
        [string]$Description = "Przed wykonaniem OpenUnbloat"
    )
    Write-LogInfo "Tworzenie punktu przywracania systemu: '$Description'..."
    try {
        # Upewnij się, że usługa System Restore jest włączona na dysku systemowym (zazwyczaj C:)
        $systemDrive = $env:SystemDrive
        Enable-ComputerRestore -Drive $systemDrive -ErrorAction SilentlyContinue

        # Usunięcie 24-godzinnego limitu tworzenia punktów w Windows (pozwala na utworzenie punktu przed każdą sesją)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-LogSuccess "Punkt przywracania został pomyślnie utworzony."
        return $true
    }
    catch {
        Write-LogWarning "Nie udało się utworzyć punktu przywracania: $($_.Exception.Message)"
        Write-LogWarning "Uwaga: Windows pozwala na tworzenie tylko jednego punktu co 24h przez PowerShell (chyba że zmieniono limit w rejestrze)."
        return $false
    }
}

function Set-RegistryValueSafe {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)]$Value,
        [ValidateSet("DWord", "QWord", "String", "ExpandedString", "Binary", "MultiString")][string]$PropertyType = "DWord"
    )
    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
        return $true
    }
    catch {
        Write-LogError "Błąd podczas modyfikacji rejestru ($($Path)\$($Name)): $($_.Exception.Message)"
        return $false
    }
}

Export-ModuleMember -Function Test-IsAdmin, Assert-Admin, Write-LogInfo, Write-LogSuccess, Write-LogWarning, Write-LogError, New-SystemRestorePoint, Set-RegistryValueSafe
