@echo off
setlocal DisableDelayedExpansion
set "MYFIBO_INSTALLER=%~f0"
set "MYFIBO_TARGET=%~1"
set "MYFIBO_INTERACTIVE="
if not defined MYFIBO_TARGET (
  set "MYFIBO_INTERACTIVE=1"
  set "MYFIBO_TARGET=C:\Users\qwills\AppData\Roaming\MetaQuotes\Terminal\E3E3B02889D32F38295D39BF94B6AD4A"
)
echo Tujuan: "%MYFIBO_TARGET%"
powershell.exe -NoProfile -Command "$text=[IO.File]::ReadAllText($env:MYFIBO_INSTALLER); & ([scriptblock]::Create(($text -split '(?m)^# POWERSHELL\r?$',2)[1]))"
set "MYFIBO_RESULT=%ERRORLEVEL%"
echo.
if not "%MYFIBO_RESULT%"=="0" echo Instalasi gagal. Lihat pesan di atas.
if defined MYFIBO_INTERACTIVE pause
exit /b %MYFIBO_RESULT%
# POWERSHELL
$ErrorActionPreference = 'Stop'
$tempFolder = $null
try {
    $target = ([string]$env:MYFIBO_TARGET).Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($target)) { throw 'Data Folder belum diisi.' }
    $target = (Resolve-Path -LiteralPath $target).ProviderPath
    $mql5 = if ((Split-Path -Leaf $target) -ieq 'MQL5') { $target } else { Join-Path $target 'MQL5' }
    if (-not (Test-Path -LiteralPath $mql5 -PathType Container)) {
        throw 'Folder MQL5 tidak ditemukan. Gunakan File - Open Data Folder di MetaTrader.'
    }
    $packageRoot = Split-Path -Parent $env:MYFIBO_INSTALLER
    $payloadRoot = $packageRoot
    $zip = Join-Path $packageRoot 'myFibo.zip'
    # Prefer the adjacent release ZIP over any old extracted directory.
    if (Test-Path -LiteralPath $zip -PathType Leaf) {
        $tempFolder = Join-Path ([IO.Path]::GetTempPath()) ('myFibo-' + [Guid]::NewGuid().ToString('N'))
        Expand-Archive -LiteralPath $zip -DestinationPath $tempFolder
        $payloadRoot = $tempFolder
    }
    $payload = Join-Path $payloadRoot 'MQL5'
    if (-not (Test-Path -LiteralPath $payload -PathType Container)) {
        throw 'Letakkan myFibo.zip di sebelah CMD, atau jalankan CMD dari hasil ekstrak lengkap.'
    }
    # Only these package files are installed. Other terminal files are untouched.
    $files = @(
        'Experts\myFibo\myFibo.mq5',
        'Experts\myFibo\MyFiboDialog.mqh',
        'Experts\myFibo\MyFiboAuto.mqh',
        'Experts\myFibo\MyFiboTypes.mqh',
        'Experts\myFibo\MyFiboChart.mqh',
        'Experts\myFibo\MyFiboState.mqh',
        'Experts\myFibo\README.md',
        'Experts\myFibo\CHANGELOG.md',
        'Include\Fibo\Fibonacci.mqh',
        'Include\Swing\SwingTypes.mqh',
        'Include\Swing\SwingDetector.mqh',
        'Include\Structure\MarketStructure.mqh',
        'Include\Structure\README.md',
        'Scripts\Structure\MarketStructureExample.mq5'
    )
    $expectedVersion = '2.10'
    $manifestPath = Join-Path $payloadRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Manifest paket tidak ditemukan.' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.version -cne $expectedVersion -or @($manifest.files).Count -ne $files.Count) {
        throw 'Versi atau daftar file manifest tidak sesuai CMD. Gunakan CMD dan paket rilis yang sama.'
    }
    # Verify every incoming file before the first destination overwrite.
    foreach ($file in $files) {
        $incoming = Join-Path $payload $file
        $entry = @($manifest.files | Where-Object { $_.path -ceq $file.Replace('\', '/') })
        if ($entry.Count -ne 1 -or -not (Test-Path -LiteralPath $incoming -PathType Leaf)) {
            throw ('Isi paket tidak lengkap: ' + $file)
        }
        if ((Get-FileHash -LiteralPath $incoming -Algorithm SHA256).Hash -ine $entry[0].sha256) {
            throw ('File paket tidak sesuai manifest: ' + $file)
        }
    }
    # Validate destination types before overwriting package files.
    foreach ($file in $files) {
        $destination = Join-Path $mql5 $file
        if ((Test-Path -LiteralPath $destination) -and
            -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            throw ('Tujuan bukan file: ' + $destination)
        }
    }
    foreach ($file in $files) {
        $destination = Join-Path $mql5 $file
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $payload $file) -Destination $destination -Force
        Write-Host ('Disalin: ' + $destination)
    }
    Write-Host ''
    Write-Host 'Selesai. Buka Experts\myFibo\myFibo.mq5 di MetaEditor, lalu tekan F7.'
    Write-Host 'Paket berisi source; file EX5 dibuat setelah kompilasi.'
} catch {
    Write-Host ('GAGAL: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if ($tempFolder -and (Test-Path -LiteralPath $tempFolder)) {
        Remove-Item -LiteralPath $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
