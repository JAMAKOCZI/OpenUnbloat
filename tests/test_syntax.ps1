$files = Get-ChildItem -Path (Split-Path -Parent $PSScriptRoot) -Include *.ps1,*.psm1 -Recurse | Where-Object { $_.FullName -notmatch 'references' -and $_.FullName -notmatch 'tests' }

$allPassed = $true
foreach ($file in $files) {
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errs) | Out-Null
    if ($errs -and $errs.Count -gt 0) {
        Write-Host "[-] SYNTAX ERROR in $($file.Name): $($errs[0].Message)" -ForegroundColor Red
        $allPassed = $false
    } else {
        Write-Host "[+] OK: $($file.Name)" -ForegroundColor Green
    }
}

if ($allPassed) {
    Write-Host "`nAll PowerShell scripts and modules are syntactically valid!" -ForegroundColor Cyan
} else {
    Write-Error "Syntax errors detected."
    exit 1
}
