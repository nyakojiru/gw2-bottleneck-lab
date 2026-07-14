<#
.SYNOPSIS
    Capture a 60s PresentMon trace of Guild Wars 2.

.DESCRIPTION
    Requires PresentMon (https://github.com/GameTechDev/PresentMon/releases).
    Needs admin for ETW tracing - you will get a UAC prompt.

    Set GW2's Frame Limiter to "Unlimited" and VSync OFF before measuring.
    A frame cap makes both CPU and GPU look idle (they're waiting on the limiter)
    and every run will report "neither saturated".

.EXAMPLE
    .\capture.ps1 -Label lionsarch_baseline
    .\capture.ps1 -Label lionsarch_cml_lowest -Seconds 90
#>
param(
    [Parameter(Mandatory=$true)][string]$Label,
    [int]$Seconds = 60,
    [int]$Delay = 8,
    [string]$PresentMon = "$PSScriptRoot\PresentMon.exe",
    [string]$OutDir = "$PSScriptRoot\..\data"
)

if (-not (Test-Path $PresentMon)) {
    Write-Host "PresentMon not found at: $PresentMon"
    Write-Host "Download the x64 CLI from https://github.com/GameTechDev/PresentMon/releases"
    Write-Host "and place it here as PresentMon.exe (or pass -PresentMon <path>)."
    exit 1
}

if (-not (Get-Process Gw2-64 -ErrorAction SilentlyContinue)) {
    Write-Host "Guild Wars 2 (Gw2-64.exe) is not running. Launch it first."
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$csv = Join-Path $OutDir "$Label.csv"
Remove-Item $csv -ErrorAction SilentlyContinue

$args = @(
    '--process_name','Gw2-64.exe'
    '--output_file',"`"$csv`""
    '--v2_metrics'
    '--delay',"$Delay"
    '--timed',"$Seconds"
    '--stop_existing_session'
    '--no_console_stats'
)

Write-Host "Capturing '$Label': ${Delay}s delay, then ${Seconds}s recording."
Write-Host "ALT-TAB TO GUILD WARS 2 NOW. Hold your position and pan slowly."

Start-Process -FilePath $PresentMon -ArgumentList $args -Verb RunAs | Out-Null

# Poll for the file to stop growing. Start-Process -Wait is unreliable across
# the elevation boundary, so we watch the output instead.
$last = -1; $stable = 0
for ($i = 0; $i -lt ($Delay + $Seconds + 40); $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $csv) {
        $sz = (Get-Item $csv).Length
        if ($sz -eq $last -and $sz -gt 0) { $stable++ } else { $stable = 0 }
        $last = $sz
        if ($stable -ge 4) { break }
    }
}
Get-Process -Name '*PresentMon*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if (Test-Path $csv) {
    Write-Host "Captured: $csv  ($([math]::Round((Get-Item $csv).Length/1KB)) KB)"
    Write-Host "Analyze with:  .\analyze.ps1 -Csv `"$csv`""
} else {
    Write-Host "No CSV produced. Was UAC declined, or was GW2 not rendering?"
    exit 1
}
