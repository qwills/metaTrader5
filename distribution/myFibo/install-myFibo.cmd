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
    # Merge the extracted MQL5 contents, overwriting existing package files.
    & xcopy.exe (Join-Path $payload '*') $mql5 /E /I /Y
    if ($LASTEXITCODE -ne 0) { throw 'Penyalinan file gagal. Periksa pesan XCOPY di atas.' }
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
