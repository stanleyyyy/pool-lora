# Build pool-tx.yaml and flash it to the XIAO nRF52840 through its UF2 drive.
# Usage: run flash-tx.bat, then double-press the XIAO reset button when asked.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:PYTHONUTF8 = '1'

Write-Host "Building pool-tx.yaml ..." -ForegroundColor Cyan
& ".venv\Scripts\esphome.exe" compile pool-tx.yaml
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

$uf2 = Get-ChildItem ".esphome\build\pool-lora-tx" -Recurse -Filter "zephyr.uf2" |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $uf2) { throw "zephyr.uf2 not found under .esphome\build\pool-lora-tx" }
New-Item -ItemType Directory -Force firmware | Out-Null
Copy-Item $uf2.FullName "firmware\pool-lora-tx.uf2" -Force
Write-Host "Firmware: $($uf2.FullName)" -ForegroundColor Green

Write-Host "`nDouble-press the XIAO reset button now (waiting up to 2 minutes for its USB drive) ..." -ForegroundColor Yellow
$drive = $null
for ($i = 0; $i -lt 240 -and -not $drive; $i++) {
    $drive = Get-PSDrive -PSProvider FileSystem | Where-Object {
        Test-Path (Join-Path $_.Root 'INFO_UF2.TXT') -ErrorAction SilentlyContinue
    } | Select-Object -First 1
    if (-not $drive) { Start-Sleep -Milliseconds 500 }
}
if (-not $drive) { throw "No UF2 drive appeared. Check the USB cable (use a data cable) and double-press reset again." }

Write-Host "Found bootloader drive $($drive.Root)" -ForegroundColor Green
Get-Content (Join-Path $drive.Root 'INFO_UF2.TXT') | Select-Object -First 2
try {
    Copy-Item "firmware\pool-lora-tx.uf2" $drive.Root -Force
} catch {
    # The board reboots as soon as the copy completes, so Windows often reports an error here.
}
Write-Host "`nFlashed. The board restarts with the new firmware (blue LED flashes on each send)." -ForegroundColor Green
