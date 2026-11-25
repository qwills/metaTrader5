# BollingerTable 1.04

Indikator MT5 dengan garis upper, middle, lower Bollinger Bands pada timeframe
chart serta tabel kecil dua kolom: TF dan Middle BB. Default periode **20**,
deviasi **2.0**, shift **0**, applied price **Close**. Middle adalah SMA bawaan
`iBands`; parameter periode/deviasi/applied price berlaku sama untuk chart dan tabel.
Referensi buffer native: [MetaQuotes iBands](https://www.mql5.com/en/docs/indicators/ibands).

Warna garis dapat dipilih di Inputs: `InpUpperColor` (default merah),
`InpMiddleColor` (DodgerBlue), dan `InpLowerColor` (Green).
Pilihan ini mengatur garis BB; aturan warna sinyal tabel tetap mengikuti tabel di bawah.

Timeframe tabel dapat dipilih melalui Inputs `InpShowM1`, `InpShowM5`,
`InpShowM15`, `InpShowM30`, `InpShowH1`, `InpShowH4`, `InpShowD1`, `InpShowW1`,
dan `InpShowMN1`. Default hanya **M15, M30, H1, H4** yang aktif.
Aktifkan/nonaktifkan setiap pilihan dengan `true`/`false`. Baris tetap berurutan
dari timeframe terkecil dan tinggi tabel menyesuaikan jumlah pilihan tanpa baris
kosong. Jika semua dinonaktifkan, tabel dan timer tidak dibuat; garis BB tetap tampil.
Nilai dan warna memakai **candle berjalan (shift 0)** di setiap timeframe.
Close berarti harga terakhir pada candle yang sedang terbentuk.
Tabel diperbarui setiap satu detik, sehingga dapat tertinggal hingga sekitar satu
detik dari tick chart ketika terminal berjalan normal.
Garis chart tetap mengikuti candle berjalan seperti BB standar.

| Warna nilai Middle BB | Kondisi |
| --- | --- |
| Hijau | Close di atas middle BB |
| Merah | Close di bawah middle BB |
| Biru | Golden cross: Close candle sebelumnya <= middle sebelumnya, Close berjalan > middle berjalan |
| Oranye | Dead cross: Close candle sebelumnya >= middle sebelumnya, Close berjalan < middle berjalan |
| Abu-abu | Close tepat sama dengan middle, atau data belum siap (`Loading...`) |

Istilah golden/dead cross di indikator ini berarti **Close melintasi middle BB**.
Cross mendapat prioritas atas hijau/merah. Pembandingnya selalu candle sebelumnya
yang sudah tutup (shift 1), bukan tick sebelumnya. Sinyal dievaluasi ulang setiap
refresh dan bisa muncul/hilang sebelum candle berjalan tutup. Masing-masing
Close dibandingkan dengan middle pada candle yang sama, tanpa pembulatan harga.
Middle ditampilkan mengikuti jumlah digit simbol.

Input posisi X/Y mengatur jarak dari kiri/atas chart; ukuran font 8–16.
Jika memasang beberapa instance pada satu chart, atur offset berbeda agar tabel
tidak bertumpuk. Judul tabel hanya `BB`.

Saat timeframe chart diganti, tabel dan nilai/warna terakhir dipertahankan;
tidak dikosongkan atau dibaca ulang secara paksa pada init. Timer melanjutkan
pembaruan normal untuk timeframe tabel yang tetap sama. Jika simbol berubah,
nilai lama dibuang agar tidak menampilkan nilai simbol sebelumnya. Objek setiap
instance dibersihkan saat indikator dilepas atau inisialisasinya gagal.

## Instalasi

1. MT5: **File > Open Data Folder**.
2. Salin folder `BollingerTable` ke `MQL5/Indicators/`, termasuk kedua file
   `BollingerTable.mq5` dan `BollingerSignal.mqh`.
3. Buka `BollingerTable.mq5` di MetaEditor, tekan **F7**.
4. Tambahkan indikator melalui Navigator > Indicators > BollingerTable.

`Loading...` hanya ditampilkan jika belum pernah ada nilai valid untuk baris itu.
Jika pembacaan sementara belum siap (termasuk handle baru setelah pergantian
timeframe), nilai dan warna valid terakhir tetap tampil sambil mencoba lagi.
Tooltip nilai menjelaskan apakah data live atau nilai terakhir yang sedang
menunggu pembaruan; nilai cache belum tentu mencerminkan harga terbaru.
Cache data valid diperbarui walaupun perintah pembaruan tampilan gagal, sehingga
percobaan berikutnya tetap memakai data valid terbaru.
Histori MN1 memerlukan setidaknya 21 candle untuk
periode default. Indikator hanya menampilkan data, tanpa order atau alert.

## Efisiensi

- Garis menggunakan buffer indikator native; objek tabel dibuat sekali saat init.
- Handle `iBands` dibuat sekali hanya untuk timeframe terpilih; baris timeframe
  chart memakai handle chart yang sama. Timeframe nonaktif tidak dibaca.
- Setelah pemuatan awal, garis menyalin satu bar per tick; saat bar baru, hanya
  bar sebelumnya dan bar baru yang disalin. Reset/perluasan histori menyalin ulang.
- Penyimpanan sementara hasil salinan garis dipakai ulang. Kegagalan sementara
  pembacaan mempertahankan progres agar percobaan berikutnya tidak menyalin
  seluruh histori tanpa kebutuhan.
- Tabel membaca dua bar per timeframe terpilih setiap satu detik, bukan seluruh histori
  atau seluruh timeframe pada setiap tick. Identitas candle dicek sebelum/sesudah
  pembacaan untuk menolak snapshot saat pergantian candle.
- Perintah teks/warna hanya dikirim jika tampilan berubah. `ChartRedraw` tabel
  hanya dipanggil ketika ada perubahan objek yang berhasil dikirim.
- Pergantian timeframe chart tidak memicu kalkulasi manual atau pembacaan
  histori penuh untuk middle tabel. MT5 tetap memuat ulang indikator dan
  handle native harus diperoleh kembali; jangan menyimpan handle integer
  dari instance sebelumnya. Cache kalkulasi `iBands` dikelola terminal.
  Tabel memakai kembali objek/nilai tampilan, lalu melanjutkan salinan dua bar
  per refresh. Garis BB chart tetap harus dimuat untuk timeframe chart baru.

Siklus reload indikator: [MetaQuotes OnInit/OnDeinit](https://www.mql5.com/en/book/applications/runtime/runtime_oninit_ondeinit).

Ini pemeriksaan kode dan simulasi, belum pengukuran CPU/latensi di terminal MT5.

## Validasi

Jalankan `python3 tests/check_bollinger_table.py` dari root workspace untuk
memeriksa pemilihan timeframe default/custom/kosong, pengabaian baris nonaktif,
logika warna/cross, pembacaan shift 0/1, perubahan intrabar, cache
tampilan, penolakan snapshot rollover, dan pemulihan data melalui adapter C++.
Tes reload memeriksa pemulihan tabel tanpa pembacaan harga, beberapa instance,
pembersihan objek, dan penolakan snapshot simbol/konfigurasi berbeda atau rusak.
Regresi warm-up memeriksa bahwa timer setelah restore tidak menimpa nilai
dengan `Loading...`; kegagalan data/sinkronisasi/rollover dan kegagalan render
tetap mempertahankan data valid terbaru sampai data baru tersedia.
Runner ini bukan compiler MQL5 dan tidak membuktikan kalkulasi native `iBands`.
F7 dan rendering GUI tetap harus diuji pada MT5 Windows. Cocokkan tiga garis
dengan Bollinger Bands bawaan (20, shift 0, deviasi 2, Close), serta nilai tabel
dengan Data Window BB pada candle berjalan di masing-masing timeframe.
Periksa pembaruan setelah pergantian candle, histori belum siap, pergantian
timeframe chart, pilihan timeframe (termasuk semua nonaktif), tinggi tabel,
dan pembersihan objek saat indikator dilepas.
