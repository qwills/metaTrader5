# Build MQL5

## Kondisi mesin saat diperiksa

Mesin melaporkan macOS 27.2, arsitektur arm64. Aplikasi MT5, executable Wine di
PATH, MetaEditor, serta prefix default MT5 tidak ditemukan di lokasi umum yang
diperiksa. Helper lama menunjuk `/Users/qwills`, sementara akun sekarang `will`.
Penyebab installer gagal belum dapat dipastikan tanpa pesan error instalasinya.

MetaQuotes masih menyediakan [installer macOS resmi](https://www.metatrader5.com/en/terminal/help/start_advanced/install_mac).
Installer itu menyiapkan Wine serta terminal. Ketersediaan installer tidak
membuktikan kompatibilitas dengan versi macOS mesin ini. Editor teks saja tidak
menggantikan MetaEditor untuk menghasilkan `.ex5`.

## macOS dengan instalasi Wine/MetaEditor yang tersedia

```bash
./compile_mql5.sh --doctor
./compile_mql5.sh Experts/AutoSL/AutoSL.mq5
# Atau dari folder proyek:
cd Experts/AutoSL
../../compile_mql5.sh AutoSL.mq5 compile.log
```

Helper menggunakan `$HOME` untuk prefix default dan mencari Wine di bundle MT5
atau PATH. Jika instalasi berada di tempat lain, isi path yang benar sebelum build:

```bash
export WINE64="/path/to/wine64"
export WINEPREFIX="$HOME/path/to/existing-wine-prefix"
export METAEDITOR="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/metaeditor64.exe"
export MQL5_ROOT="$WINEPREFIX/drive_c/Program Files/MetaTrader 5/MQL5"
./compile_mql5.sh --doctor
./compile_mql5.sh Experts/exeMyCalc/ExeMyCalc.mq5
```

`METAEDITOR` berupa path Unix, bukan `C:\...`. `MQL5_ROOT` menunjuk folder **MQL5**
yang memiliki `Include/Controls` dan `Include/Trade`, bukan folder Include itu
sendiri. Standard library ini berasal dari instalasi MT5; tidak ada di workspace.
Wine prefix harus sudah ada. Helper memakai `winepath`, atau mapping standar
`dosdevices/z:` ke `/`, untuk mengakses source dan log.

Log default ada di samping source (`compile.log`), UTF-16 atau UTF-8 sesuai
compiler. Hasil sukses memerlukan ringkasan `0 errors` dan output `.ex5` yang
ada; warning tetap ditampilkan. Log yang gagal/hilang tidak dianggap sukses
meskipun proses keluar dengan kode 0. Helper tidak menginstal aplikasi dan tidak
menyalin hasil ke terminal.

## Build di Windows tanpa memasang MT5 di Mac

Gunakan komputer Windows yang memiliki MT5/MetaEditor, termasuk mesin remote
atau VM Windows yang sudah tersedia. Salin workspace ini ke Windows dengan
struktur foldernya tetap utuh. Pilihan ini memindahkan proses build dari Mac;
compiler MetaEditor tetap diperlukan pada mesin tujuan.

Cara GUI: buka `.mq5` di MetaEditor, tekan F7, periksa Errors, lalu ambil `.ex5`
di sebelah source. Untuk EA1 dan contoh Fibonacci, pertahankan folder relatif
`Experts`, `Include`, dan `Scripts`.

Cara command line di PowerShell (sesuaikan ketiga path):

```powershell
$editor = 'C:\Program Files\MetaTrader 5\metaeditor64.exe'
$source = 'C:\Work\metaTrader5\Experts\AutoSL\AutoSL.mq5'
$mql5 = 'C:\Users\YOUR_USER\AppData\Roaming\MetaQuotes\Terminal\YOUR_INSTANCE\MQL5'
Start-Process -FilePath $editor -ArgumentList @(
    "/compile:`"$source`"",
    "/include:`"$mql5`"",
    '/log'
) -Wait
Get-Content -LiteralPath ([IO.Path]::ChangeExtension($source, '.log'))
```

Temukan data folder lewat **File > Open Data Folder**. Parameter `/include`
menunjuk root MQL5 yang memiliki standard library. Periksa ringkasan log; kode
exit proses saja tidak cukup. Salin output ke folder terminal sesuai jenisnya.
Perintah Windows ini disediakan sebagai panduan dan belum dijalankan pada mesin ini.

Referensi: [integrasi MetaEditor dengan IDE dan parameter compiler](https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide),
[proses kompilasi dan output EX5](https://www.metatrader5.com/en/metaeditor/help/development/compile).
