$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\dot_glzr\zebar\pastel-bar\AcrylicLayer.cs.tmpl'
Add-Type -TypeDefinition (Get-Content -Raw -LiteralPath $source)
if ((Get-Content -Raw -LiteralPath $source) -match 'Console.Error.WriteLine') { throw 'Layout constraints must not disconnect the collector via stderr' }

function Check-Layout([int[]]$Sizes, [int]$Width, [int]$PreferredGap, [int]$Margin, [int]$Left = 0) {
    $Sizes = [PastelAcrylic]::FitSizes($Width, $Sizes, $Margin, ($Margin / 16.0))
    $positions = [PastelAcrylic]::Positions($Left, $Width, $Sizes, $PreferredGap, $Margin)
    if ($positions.Length -ne $Sizes.Length) { throw 'Incorrect number of positions' }
    $center = $Sizes.Length - 3
    if ($positions[$center] -ne $Left + [Math]::Floor(($Width - $Sizes[$center]) / 2)) { throw 'Active window is not at the monitor center' }
    $gap = $positions[1] - $positions[0] - $Sizes[0]
    if ($gap -lt 0 -or $gap -gt $PreferredGap) { throw 'Shared gap is outside the allowed range' }
    $end = $Left + $Margin
    for ($i = 0; $i -lt $positions.Length; $i++) {
        if ($positions[$i] -lt $end) { throw 'Pills overlap or extend beyond the left margin' }
        if ($i -gt 0 -and $positions[$i] - $end -ne $gap) { throw 'Every adjacent pill must use the same gap, including active-to-AI and AI-to-weather' }
        $end = $positions[$i] + $Sizes[$i]
        if ($end -gt $Left + $Width - $Margin) { throw 'Pills extend beyond the right margin' }
    }
    if ($gap -lt $PreferredGap -and $positions[0] - $Left - $Margin -ge $center -and $Left + $Width - $Margin - $end -ge $Sizes.Length - $center - 1) { throw 'Shared gap must only shrink when a screen margin requires it' }
    return ,$positions
}

$open = Check-Layout @(400, 132, 320, 351, 166) 1920 56 16
$normalSizes = [PastelAcrylic]::FitSizes(1920, @(400, 132, 320, 351, 166), 16, 1)
if ($normalSizes[1] -ne 132) { throw 'Spotify must retain the user-specified 132px width' }
$mediumSizes = [PastelAcrylic]::FitSizes(1600, @(400, 132, 320, 351, 166), 16, 1)
if ($mediumSizes[1] -ne 132 -or $mediumSizes[2] -ne 320) { throw 'Keep Spotify compact while space permits full active window width' }
$closed = Check-Layout @(400, 320, 351, 166) 1920 56 16
if ($open[1] -le $open[0] -or $open[2] -le $open[1]) { throw 'Spotify is not between hardware and active window' }
if ($open[2] -ne 800 -or $closed[1] -ne 800) { throw '1920px monitor center must remain x=960' }
if (($open -join ',') -ne '156,612,800,1176,1583') { throw '1920px Spotify-open layout must use four 56px gaps around the centered active window' }
if (($closed -join ',') -ne '344,800,1176,1583') { throw '1920px Spotify-closed layout must use three 56px gaps around the centered active window' }
$mediumOpen = Check-Layout @(400, 132, 320, 351, 166) 1600 56 16
$mediumClosed = Check-Layout @(400, 320, 351, 166) 1600 56 16
if ($mediumOpen[1] - $mediumOpen[0] - 400 -ne 46 -or $mediumClosed[1] - $mediumClosed[0] - 400 -ne 53) { throw 'Narrow layouts must share the gap allowed by the more constrained side' }
$null = Check-Layout @(600, 198, 480, 527, 249) 2880 84 24
$null = Check-Layout @(500, 165, 400, 439, 208) 2400 70 20 -2400
$null = Check-Layout @(800, 264, 640, 702, 332) 3840 112 32
$recovered = [PastelAcrylic]::FitSizes(1920, @(400, 132, 126, 351, 166), 16, 1)
if ($recovered[1] -ne 132 -or $recovered[2] -ne 320) { throw 'Active window width must recover on a wider monitor' }
$null = Check-Layout @(400, 132, 320, 351, 166) 1920 56 16 -1920
$null = Check-Layout @(400, 132, 320, 351, 166) 1921 56 16 -1921
$null = Check-Layout @(400, 320, 351, 166) 1921 56 16 -1921
$null = Check-Layout @(400, 132, 320, 351, 166) 1920 56 16 2560
$narrowSizes = [PastelAcrylic]::FitSizes(1366, @(400, 132, 320, 351, 166), 16, 1)
if ($narrowSizes[1] -ne 132 -or $narrowSizes[2] -ne 270) { throw '1366px must fit every pill with a 270px centered active window' }
$null = Check-Layout @(400, 320, 351, 166) 1366 56 16
foreach ($width in @(1216, 1280, 1326, 1360, 1366, 1400, 1600, 1921, 2560, 3840)) {
    $null = Check-Layout @(400, 132, 320, 351, 166) $width 56 16
    $null = Check-Layout @(400, 320, 351, 166) $width 56 16
}
$null = Check-Layout @(400, 320, 351, 166) 1186 56 16
$null = Check-Layout @(400, 320, 351, 166) 1185 56 16
# Without Spotify, 1185px still fits because the centered position rounds down; 1184px is the first impossible width.
foreach ($case in @(@(360, @(400, 132, 320, 351, 166)), @(800, @(400, 132, 320, 351, 166)), @(1100, @(400, 132, 320, 351, 166)), @(1215, @(400, 132, 320, 351, 166)), @(360, @(400, 320, 351, 166)), @(800, @(400, 320, 351, 166)), @(1100, @(400, 320, 351, 166)), @(1184, @(400, 320, 351, 166)))) {
    $width = $case[0]
    $sizes = [PastelAcrylic]::FitSizes($width, [int[]]$case[1], 16, 1)
    $rejected = $false
    try { $null = [PastelAcrylic]::Positions(0, $width, $sizes, 56, 16) } catch { $rejected = $true }
    if (!$rejected) { throw "Physically impossible width $width must report its constraint" }
}
$pack = Get-Content -Raw (Join-Path $PSScriptRoot '../dot_glzr/zebar/pastel-bar/zpack.json.tmpl') | ConvertFrom-Json
if (($pack.widgets | Where-Object name -eq spotify).presets[0].width -ne '132px') { throw 'Spotify preset width differs from tested layout' }
if (($pack.widgets | Where-Object name -eq hardware).presets[0].width -ne '400px') { throw 'Hardware preset width differs from tested layout' }
if (($pack.widgets | Where-Object name -eq ai).presets[0].width -ne '351px') { throw 'AI preset width differs from tested layout' }
if (($pack.widgets | Where-Object name -eq active).presets[0].offsetX -ne '0px') { throw 'Active window must also start centered' }
$tint = Get-Content -Raw (Join-Path $PSScriptRoot '../dot_glzr/zebar/pastel-bar/acrylic.ps1.tmpl')
if ($tint -notmatch 'else \{ \$smoke.A = 153; \$smoke.R = 53; \$smoke.G = 56; \$smoke.B = 61 \}' -or $tint -notmatch 'if \(\$row\[3\]\) \{ \$smoke.A = 110; \$smoke.R = 30; \$smoke.G = 32; \$smoke.B = 36 \}') { throw 'Normal pill tint must be 60% with unchanged RGB and spacer tint' }
Write-Output 'Zebar layout checks passed'
