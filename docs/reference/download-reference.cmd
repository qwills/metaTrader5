@echo off
setlocal
set "MQL5_REFERENCE_FOLDER=%~dp0"
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { foreach ($name in @('mql5.pdf','mql5.chm')) { $out=Join-Path $env:MQL5_REFERENCE_FOLDER $name; $temp=$out+'.download'; Invoke-WebRequest -UseBasicParsing -Uri ('https://www.mql5.com/files/docs/'+$name) -OutFile $temp; Move-Item -LiteralPath $temp -Destination $out -Force; Write-Host ('Saved: '+$out) } } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
 echo Download gagal. Buka https://www.mql5.com/en/docs untuk unduhan manual.
 pause
 exit /b 1
)
echo Selesai. PDF dan CHM tersedia di folder ini.
pause
