@echo off
setlocal DisableDelayedExpansion
set "SWING_INSTALLER=%~f0"
set "SWING_TARGET=%~1"
set "SWING_EDITOR=%~2"
set "SWING_INTERACTIVE="
if not defined SWING_TARGET (
  set "SWING_INTERACTIVE=1"
  set "SWING_TARGET=C:\Users\qwills\AppData\Roaming\MetaQuotes\Terminal\E3E3B02889D32F38295D39BF94B6AD4A"
)
echo Tujuan: "%SWING_TARGET%"
powershell.exe -NoProfile -Command "$text=[IO.File]::ReadAllText($env:SWING_INSTALLER); & ([scriptblock]::Create(($text -split '(?m)^# POWERSHELL\r?$',2)[1]))"
set "SWING_RESULT=%ERRORLEVEL%"
echo.
if not "%SWING_RESULT%"=="0" echo Instalasi gagal. Lihat pesan di atas.
if defined SWING_INTERACTIVE pause
exit /b %SWING_RESULT%
# POWERSHELL
$ErrorActionPreference = 'Stop'
$tempFolder = $null
try {
    $target = ([string]$env:SWING_TARGET).Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($target)) { throw 'Data Folder belum diisi.' }
    $target = (Resolve-Path -LiteralPath $target).ProviderPath
    $mql5 = if ((Split-Path -Leaf $target) -ieq 'MQL5') { $target } else { Join-Path $target 'MQL5' }
    if (-not (Test-Path -LiteralPath $mql5 -PathType Container)) {
        throw 'Folder MQL5 tidak ditemukan. Gunakan File - Open Data Folder di MetaTrader.'
    }
    $packageRoot = Split-Path -Parent $env:SWING_INSTALLER
    $payload = Join-Path $packageRoot 'MQL5'
    if (-not (Test-Path -LiteralPath $payload -PathType Container)) {
        $zip = Join-Path $packageRoot 'swingDetector.zip'
        if (-not (Test-Path -LiteralPath $zip -PathType Leaf)) {
            throw 'Letakkan swingDetector.zip di sebelah build-swingDetector.cmd, atau ekstrak ZIP lalu jalankan CMD di dalamnya.'
        }
        $tempFolder = Join-Path ([IO.Path]::GetTempPath()) ('swingDetector-' + [Guid]::NewGuid().ToString('N'))
        Expand-Archive -LiteralPath $zip -DestinationPath $tempFolder
        $payload = Join-Path $tempFolder 'MQL5'
    }
    # Only these package files are installed. Other terminal files are untouched.
    $files = @(
        'Include\Swing\SwingTypes.mqh',
        'Include\Swing\SwingDetector.mqh',
        'Include\Swing\README.md',
        'Scripts\Swing\SwingDetectorExample.mq5',
        'Scripts\Swing\README.md'
    )
    foreach ($file in $files) {
        if (-not (Test-Path -LiteralPath (Join-Path $payload $file) -PathType Leaf)) {
            throw ('Isi paket tidak lengkap: ' + $file)
        }
    }
    # Locate the terminal's MetaEditor before changing destination files.
    $candidates = @()
    if ($env:SWING_EDITOR) {
        $candidates += $env:SWING_EDITOR
    } else {
        $origin = Join-Path (Split-Path -Parent $mql5) 'origin.txt'
        if (Test-Path -LiteralPath $origin -PathType Leaf) {
            $installFolder = [IO.File]::ReadAllText($origin).Trim().Trim([char]0)
            $candidates += Join-Path $installFolder 'metaeditor64.exe'
        }
        $candidates += Join-Path $env:ProgramFiles 'MetaTrader 5\metaeditor64.exe'
    }
    $editor = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $editor) { throw 'MetaEditor tidak ditemukan. Gunakan argumen kedua: path lengkap metaeditor64.exe.' }
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
    $source = Join-Path $mql5 'Scripts\Swing\SwingDetectorExample.mq5'
    $log = [IO.Path]::ChangeExtension($source, '.log')
    $output = [IO.Path]::ChangeExtension($source, '.ex5')
    if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
    Write-Host ('Compiler: ' + $editor)
    Start-Process -FilePath $editor -ArgumentList @(
        "/compile:`"$source`"", "/include:`"$mql5`"", '/log'
    ) -Wait
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { throw 'Compiler tidak menghasilkan log.' }
    $result = [IO.File]::ReadAllText($log)
    Write-Host $result
    if ($result -notmatch 'Result:\s*0 errors?,\s*[0-9]+ warnings?' -or
        -not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw 'Build gagal. Periksa pesan compiler di atas.'
    }
    Write-Host ('BUILD OK: ' + $output)
    Write-Host 'Jalankan Scripts/Swing/SwingDetectorExample pada chart untuk menjalankan 46 pemeriksaan.' 
} catch {
    Write-Host ('GAGAL: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if ($tempFolder -and (Test-Path -LiteralPath $tempFolder)) {
        Remove-Item -LiteralPath $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
