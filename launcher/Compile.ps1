# Compile.ps1 - Skrypt kompilacji natywnego launchera OpenUnbloat.exe

$baseDir = Split-Path -Parent $PSScriptRoot
$cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path $cscPath)) {
    Write-Error "Nie znaleziono kompilatora csc.exe w $cscPath"
    exit 1
}

$outputExe = Join-Path $baseDir "OpenUnbloat.exe"
$sourceFile = Join-Path $PSScriptRoot "Program.cs"
$manifestFile = Join-Path $PSScriptRoot "app.manifest"
$iconFile = Join-Path $PSScriptRoot "app.ico"

Write-Host "Kompilowanie $outputExe..." -ForegroundColor Cyan

if (Test-Path $outputExe) {
    Remove-Item $outputExe -Force -ErrorAction SilentlyContinue
}

$compileArgs = @("/nologo", "/target:winexe", "/win32manifest:`"$manifestFile`"")
if (Test-Path $iconFile) {
    $compileArgs += "/win32icon:`"$iconFile`""
}
$compileArgs += @("/out:`"$outputExe`"", "/r:System.dll", "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll", "`"$sourceFile`"")

& $cscPath $compileArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "Pomyślnie skompilowano OpenUnbloat.exe!" -ForegroundColor Green
} else {
    Write-Error "Błąd kompilacji OpenUnbloat.exe"
}
