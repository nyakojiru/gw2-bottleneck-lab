<#
.SYNOPSIS
    Analyze a PresentMon v2-metrics CSV: FPS, lows, frametime spread,
    CPU-vs-GPU bottleneck, and presentation path (VRR capability).

.EXAMPLE
    .\analyze.ps1 -Csv ..\data\lionsarch_baseline.csv
#>
param([Parameter(Mandatory=$true)][string]$Csv)

if (-not (Test-Path $Csv)) { Write-Host "No such file: $Csv"; exit 1 }
$rows = Import-Csv $Csv
if ($rows.Count -lt 10) { Write-Host "Too few frames ($($rows.Count)). Was GW2 focused and rendering?"; exit 1 }

# PresentMon 2.x --v2_metrics columns, all in ms
$ft  = $rows | ForEach-Object { [double]$_.FrameTime } | Where-Object { $_ -gt 0 }
$cpu = $rows | ForEach-Object { [double]$_.CPUBusy }
$gpu = $rows | ForEach-Object { [double]$_.GPUBusy }

$n      = $ft.Count
$desc   = $ft | Sort-Object -Descending   # worst frames first
$asc    = $ft | Sort-Object

$avgFt  = ($ft  | Measure-Object -Average).Average
$avgCpu = ($cpu | Measure-Object -Average).Average
$avgGpu = ($gpu | Measure-Object -Average).Average

$avgFps = 1000.0 / $avgFt
$low1   = 1000.0 / $desc[[math]::Floor($n * 0.01)]
$low01  = 1000.0 / $desc[[math]::Floor($n * 0.001)]

$cpuRatio = $avgCpu / $avgFt
$gpuRatio = $avgGpu / $avgFt

# Whichever side is busy for a larger share of the frame is the limiter.
$lead = [math]::Max($gpuRatio, $cpuRatio)
if ($lead -lt 0.80) {
    $bound = "MIXED / neither saturated (frame cap or vsync active? re-run uncapped)"
    $headroom = $null
} elseif ($gpuRatio -gt $cpuRatio) {
    $bound = if ($gpuRatio -ge 0.92) { "GPU-BOUND (hard)" } else { "GPU-bound (mostly)" }
    $headroom = 1000.0 / $avgCpu
} else {
    $bound = if ($cpuRatio -ge 0.92) { "CPU-BOUND (hard)" } else { "CPU-bound (mostly)" }
    $headroom = 1000.0 / $avgGpu
}

$stutter = ($ft | Where-Object { $_ -gt ($avgFt * 2) }).Count
$sd = [math]::Sqrt((($ft | ForEach-Object { [math]::Pow($_ - $avgFt, 2) }) | Measure-Object -Sum).Sum / $n)
$cv = $sd / $avgFt

# Presentation path decides whether VRR can engage at all.
$modes   = $rows | Group-Object PresentMode | Sort-Object Count -Descending
$topMode = $modes[0].Name
if     ($topMode -match 'Independent Flip') { $flip = "OK  - flip model engaged. VRR can work, even in borderless." }
elseif ($topMode -match 'Composed: Flip')   { $flip = "MEH - composed flip. VRR may be degraded by DWM." }
elseif ($topMode -match 'Copy|GDI|blt')     { $flip = "BAD - LEGACY BLT PATH. VRR CANNOT ENGAGE." }
else                                        { $flip = "UNKNOWN: $topMode" }

"=================================================="
"  {0}" -f (Split-Path $Csv -Leaf)
"=================================================="
"  Frames captured   : {0}   ({1:N1} s)" -f $n, (($ft | Measure-Object -Sum).Sum / 1000)
""
"  Average FPS       : {0,7:N1}" -f $avgFps
"  1% low  FPS       : {0,7:N1}" -f $low1
"  0.1% low FPS      : {0,7:N1}" -f $low01
""
"  Avg frametime     : {0,7:N2} ms" -f $avgFt
"  Avg CPU busy      : {0,7:N2} ms   ({1:P0} of frame)" -f $avgCpu, $cpuRatio
"  Avg GPU busy      : {0,7:N2} ms   ({1:P0} of frame)" -f $avgGpu, $gpuRatio
""
if ($headroom) {
    "  >>> VERDICT: $bound   | other side could sustain ~{0:N0} FPS" -f $headroom
} else {
    "  >>> VERDICT: $bound"
}
""
"  Stutter frames (>2x avg): {0}  ({1:P1})" -f $stutter, ($stutter / $n)
"  Frametime stddev  : {0,7:N2} ms   (CV {1:P1} - lower = smoother)" -f $sd, $cv
"  Frametime p50/p95/p99: {0:N2} / {1:N2} / {2:N2} ms" -f `
    $asc[[math]::Floor($n*0.50)], $asc[[math]::Floor($n*0.95)], $asc[[math]::Floor($n*0.99)]
""
"  Present mode      : $topMode"
"  >>> VRR PATH: $flip"
foreach ($m in $modes) { "        {0,-42} {1,6} frames" -f $m.Name, $m.Count }
"=================================================="
