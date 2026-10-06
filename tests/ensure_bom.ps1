$baseDir = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -Path $baseDir -Include *.ps1,*.psm1,*.json,*.xaml,*.cs -Recurse | Where-Object { 
    $_.FullName -notmatch 'tests' 
}
$utf8Bom = [System.Text.UTF8Encoding]::new($true)
foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($file.FullName, $content, $utf8Bom)
    Write-Host "[BOM Applied] $($file.Name)" -ForegroundColor Green
}
Write-Host "`nAll files encoded with UTF-8 BOM successfully." -ForegroundColor Cyan
