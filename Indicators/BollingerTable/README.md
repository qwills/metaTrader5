# BollingerTable 1.00

Indikator MT5 dengan garis upper, middle, lower Bollinger Bands pada timeframe
chart serta tabel kecil dua kolom: TF dan Middle BB. Default periode **20**,
deviasi **2.0**, shift **0**, applied price **Close**. Middle adalah SMA bawaan
`iBands`; parameter periode/deviasi/applied price berlaku sama untuk chart dan tabel.
Referensi buffer native: [MetaQuotes iBands](https://www.mql5.com/en/docs/indicators/ibands).

Tabel menampilkan simbol chart pada M1, M5, M15, M30, H1, H4, D1, W1, MN1.
Nilai dan warna memakai **candle terakhir yang sudah tutup** di setiap timeframe,
bukan candle chart yang masih berjalan. Tabel diperbarui setiap satu detik.
Garis chart tetap mengikuti candle berjalan seperti BB standar.

| Warna nilai Middle BB | Kondisi |
| --- | --- |
| Hijau | Close di atas middle BB |
| Merah | Close di bawah middle BB |
| Biru | Golden cross: Close sebelumnya <= middle sebelumnya, Close terakhir > middle terakhir |
| Oranye | Dead cross: Close sebelumnya >= middle sebelumnya, Close terakhir < middle terakhir |
| Abu-abu | Close tepat sama dengan middle, atau data belum siap (`Loading...`) |

Istilah golden/dead cross di indikator ini berarti **Close melintasi middle BB**.
Cross mendapat prioritas atas hijau/merah dan berlaku untuk candle tertutup yang
baru melintas. Pada penutupan berikutnya, warna dievaluasi ulang. Masing-masing
Close dibandingkan dengan middle pada candle yang sama, tanpa pembulatan harga.
Middle ditampilkan mengikuti jumlah digit simbol.

Input posisi X/Y mengatur jarak dari kiri/atas chart; ukuran font 8–16.
Jika memasang beberapa instance pada satu chart, atur offset berbeda agar tabel
tidak bertumpuk. Objek setiap instance dibersihkan saat indikator dilepas.

## Instalasi

1. MT5: **File > Open Data Folder**.
2. Salin folder `BollingerTable` ke `MQL5/Indicators/`, termasuk kedua file
   `BollingerTable.mq5` dan `BollingerSignal.mqh`.
3. Buka `BollingerTable.mq5` di MetaEditor, tekan **F7**.
4. Tambahkan indikator melalui Navigator > Indicators > BollingerTable.

Saat histori multi-timeframe belum tersedia, tabel menampilkan `Loading...`
dan mencoba lagi otomatis. Histori MN1 memerlukan setidaknya 22 candle untuk
periode default. Indikator hanya menampilkan data, tanpa order atau alert.

## Validasi

Jalankan `python3 tests/check_bollinger_table.py` dari root workspace untuk
memeriksa logika warna/cross melalui adapter C++. Runner ini bukan compiler MQL5.
F7 dan rendering GUI tetap harus diuji pada MT5 Windows. Cocokkan tiga garis
dengan Bollinger Bands bawaan (20, shift 0, deviasi 2, Close), serta nilai tabel
dengan Data Window BB pada candle tertutup di masing-masing timeframe.
Periksa pembaruan setelah pergantian candle, histori belum siap, pergantian
timeframe chart, dan pembersihan objek saat indikator dilepas.
