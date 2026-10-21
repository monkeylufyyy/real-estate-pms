# Generates simple placeholder photos for every property that has no image yet and uploads them.
#   powershell -File scripts/attach-demo-images.ps1 -TargetOrg <alias>
param([Parameter(Mandatory = $true)][string]$TargetOrg)

Add-Type -AssemblyName System.Drawing
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'pms-demo-images'
New-Item -ItemType Directory -Force $tmp | Out-Null

$palette = @(
    @('#1F6FB2', '#7FB8E6'), @('#2E8B57', '#9AD3B0'), @('#C2642B', '#F0B48A'),
    @('#6A4C93', '#BFA8E0'), @('#B23A48', '#F0A3AB'), @('#2A7F8E', '#93D0DA')
)

function New-PlaceholderImage($path, $title, $caption, $colors) {
    $bmp = New-Object System.Drawing.Bitmap 960, 600
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $rect = New-Object System.Drawing.Rectangle 0, 0, 960, 600
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.ColorTranslator]::FromHtml($colors[0])), ([System.Drawing.ColorTranslator]::FromHtml($colors[1])), 45
    $g.FillRectangle($brush, $rect)
    # simple building silhouette
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 255, 255, 255))
    $g.FillRectangle($white, 620, 160, 200, 440)
    $g.FillRectangle($white, 520, 300, 120, 300)
    $win = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(120, 255, 255, 255))
    foreach ($row in 0..4) { foreach ($col in 0..2) { $g.FillRectangle($win, 640 + ($col * 60), 180 + ($row * 80), 36, 48) } }
    $font = New-Object System.Drawing.Font 'Segoe UI', 40, ([System.Drawing.FontStyle]::Bold)
    $small = New-Object System.Drawing.Font 'Segoe UI', 22
    $text = [System.Drawing.Brushes]::White
    $g.DrawString($title, $font, $text, 40, 40)
    $g.DrawString($caption, $small, $text, 44, 120)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $g.Dispose(); $bmp.Dispose()
}

$raw = sf data query --query "SELECT Id, Name, City__c, Type__c FROM Property__c WHERE Image_Count__c = 0 ORDER BY Name" --target-org $TargetOrg --json | ConvertFrom-Json
$i = 0
foreach ($p in $raw.result.records) {
    $colors = $palette[$i % $palette.Count]
    $i++
    foreach ($view in @(@('exterior', "$($p.Type__c) property in $($p.City__c)"), @('living-room', 'Living room'))) {
        $file = Join-Path $tmp "$($p.Name -replace '[^A-Za-z0-9]+', '-')-$($view[0]).jpg"
        New-PlaceholderImage $file $p.Name $view[1] $colors
        sf data create file --file $file --title "$($p.Name) - $($view[0])" --parent-id $p.Id --target-org $TargetOrg --json | Out-Null
        Write-Host "Attached $($view[0]) image to $($p.Name)"
    }
}
