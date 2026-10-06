# Make-Icon.ps1 - Generowanie ikony app.ico oraz zasobów graficznych dla Unbloat.exe
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $PSCommandPath
$sourceImagePath = "C:\Users\wiktor\.gemini\antigravity\brain\484ba76b-711c-459d-8d24-73c239b83121\unbloat_app_icon_1791292204789.jpg"

if (-not (Test-Path $sourceImagePath)) {
    Write-Error "Nie znaleziono pliku źródłowego: $sourceImagePath"
    exit 1
}

# 1. Zapisz kopię źródłową jako PNG w projekcie
$pngMasterPath = Join-Path $scriptDir "app_icon.png"
$uiPngPath = Join-Path (Join-Path (Split-Path $scriptDir -Parent) "ui") "app_icon.png"
$icoPath = Join-Path $scriptDir "app.ico"

$srcImg = [System.Drawing.Image]::FromFile($sourceImagePath)
$srcImg.Save($pngMasterPath, [System.Drawing.Imaging.ImageFormat]::Png)
$srcImg.Save($uiPngPath, [System.Drawing.Imaging.ImageFormat]::Png)

Write-Host "Zapisano wzorzec PNG: $pngMasterPath" -ForegroundColor Cyan

# 2. Utwórz multi-resolution ikony ICO (256x256, 48x48, 32x32, 16x16)
$sizes = @(256, 128, 64, 48, 32, 16)
$pngStreams = @()

foreach ($sz in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $sz, $sz
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # Rysuj przeskalowany obraz
    $destRect = New-Object System.Drawing.Rectangle 0, 0, $sz, $sz
    $g.DrawImage($srcImg, $destRect, 0, 0, $srcImg.Width, $srcImg.Height, [System.Drawing.GraphicsUnit]::Pixel)
    
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngStreams += ,$ms.ToArray()

    $ms.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

$srcImg.Dispose()

# 3. Zapisz plik ICO zgodny ze standardem Microsoft Icon Format (PNG format dla każdej rozdzielczości)
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fs)

$bw.Write([uint16]0) # Reserved
$bw.Write([uint16]1) # Icon type = 1
$bw.Write([uint16]$sizes.Count)

$offset = 6 + (16 * $sizes.Count)

for ($i = 0; $i -lt $sizes.Count; $i++) {
    $sz = $sizes[$i]
    $data = $pngStreams[$i]
    $w = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }
    $h = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }

    $bw.Write([byte]$w)
    $bw.Write([byte]$h)
    $bw.Write([byte]0)   # Colors
    $bw.Write([byte]0)   # Reserved
    $bw.Write([uint16]1) # Planes
    $bw.Write([uint16]32) # BitCount
    $bw.Write([uint32]$data.Length) # BytesInRes
    $bw.Write([uint32]$offset)      # ImageOffset

    $offset += $data.Length
}

for ($i = 0; $i -lt $sizes.Count; $i++) {
    $bw.Write($pngStreams[$i])
}

$bw.Flush()
$bw.Close()
$fs.Close()

Write-Host "Pomyślnie wygenerowano wielorozdzielczy plik ICO: $icoPath ($((Get-Item $icoPath).Length) bajtów)" -ForegroundColor Green
