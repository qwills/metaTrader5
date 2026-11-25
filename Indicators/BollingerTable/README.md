# BollingerTable 1.07

Indikator MT5 dengan tiga garis Bollinger Bands pada timeframe chart dan tabel
TF/Middle BB untuk simbol chart. Default: periode **20**, deviasi **2**, shift
**0**, applied price **Close**. Input warna garis: `InpUpperColor` = Red,
`InpMiddleColor` = DodgerBlue, `InpLowerColor` = Green.

Timeframe tabel dipilih melalui `InpShowM1`, `InpShowM5`, `InpShowM15`,
`InpShowM30`, `InpShowH1`, `InpShowH4`, `InpShowD1`, `InpShowW1`, `InpShowMN1`.
Default hanya **M15, M30, H1, H4** aktif. Baris berurutan, tanpa celah; tinggi
menyesuaikan pilihan. Jika semua nonaktif, tabel/timer tidak dibuat, garis tetap
berjalan. Posisi diatur melalui X/Y dari kiri atas; font 8–16. Untuk beberapa
instance, gunakan posisi berbeda agar tabel tidak bertumpuk. Judul hanya `BB`.

Tabel menggunakan **current candle (shift 0)**, diperbarui setiap satu detik;
Close berarti harga terakhir candle berjalan. Garis chart diperbarui per tick.
Timer bukan jaminan latensi maksimal satu detik saat terminal sibuk. Pada pemasangan
baru, tabel dibuat oleh timer pertama (sekitar satu detik setelah init); garis
BB tidak menunggu pembuatan tabel.

| Warna nilai Middle BB | Kondisi |
| --- | --- |
| Hijau | Close di atas middle BB |
| Merah | Close di bawah middle BB |
| Biru | Golden cross: Close sebelumnya <= middle sebelumnya, Close berjalan > middle berjalan |
| Oranye | Dead cross: Close sebelumnya >= middle sebelumnya, Close berjalan < middle berjalan |
| Abu-abu | Close sama dengan middle, atau belum ada data awal |

Cross berarti **Close melintasi middle BB**, membandingkan shift 1 dengan shift
0, bukan membandingkan tick berurutan. Cross mendapat prioritas atas hijau/merah
serta bisa muncul/hilang sebelum candle tutup. Pembandingan menggunakan angka
sebelum pembulatan tampilan. Angka ditampilkan sesuai digit simbol.

## Data dan status

Garis menggunakan `iBands` native. Untuk tabel, middle BB adalah SMA yang dihitung
dari **satu snapshot `CopyRates` berisi periode+1 candle** per timeframe. Close,
SMA shift 1 dan SMA shift 0 berasal dari snapshot yang sama, tanpa menggabungkan
Close dengan buffer indikator yang diperbarui secara terpisah. Semua tujuh
applied price didukung; penjumlahan SMA memakai kompensasi galat floating point.
Nilai terakhir ditolak jika data parsial, tidak sinkron, tidak finite, timestamp
candle tidak berurutan, atau snapshot melewati pergantian candle.

`Loading...` hanya untuk baris yang belum memiliki data valid. Jika pembaruan
sementara gagal, angka/warna terakhir tetap tampil. Setelah minimal **3 detik**
sejak pembacaan sukses terakhir, angka mendapat **` *`** sebagai penanda cache.
Tooltip menunjukkan waktu pembaruan lokal terakhir dan status Live/Waiting.
Terputusnya koneksi terminal juga membuat data dianggap menunggu pembaruan.
Tanda `*` hilang ketika pembacaan data kembali berhasil. Tidak ada batas waktu
penghapusan cache; tanda dan timestamp membedakannya dari data baru.

Saat timeframe chart berganti, objek, cache numerik, warna dan timestamp tabel
dipertahankan. Init tidak memaksa pembacaan tabel tambahan. Timer melanjutkan
pembaruan biasa. Jika simbol berganti, cache simbol lama dibuang.
Cache disimpan dalam label metadata yang tidak ditampilkan di timeframe mana pun,
terpisah dari teks nilai yang terlihat; teks cache, warna, schema dan timestamp
harus lolos validasi sebelum pemulihan. Kandidat pending yang rusak dibuang dan
pencarian berlanjut ke kandidat lain. Metadata schema tidak mengikuti versi rilis.

## Pemulihan objek dan efisiensi

- Tabel tidak memakai handle BB multi-timeframe. Hanya ada satu `iBands` untuk
  garis chart, sehingga tidak ada handle BB tabel yang perlu dibangun ulang saat
  mengganti timeframe. SMA jendela kecil tetap dihitung pada refresh normal.
- Default membaca 4 x 21 = **84 candle per detik**, bukan seluruh histori.
  Penyimpanan snapshot dipakai ulang. Biaya meningkat sebanding periode dan jumlah TF.
- Garis setelah init menyalin satu candle per tick, atau dua saat bar baru.
  Reset/perluasan histori memerlukan salinan yang sesuai. Salinan tiga garis
  dikomit bersama setelah semua berhasil; posisi bar baru yang belum tersedia
  ditandai `EMPTY_VALUE`, bukan harga nol.
- Timer memeriksa keberadaan/tipe objek. Label, background, header atau metadata
  yang hilang dibuat kembali menggunakan cache; objek lain di chart tidak dihapus.
  Perbaikan layout yang belum selesai dicoba lagi pada timer berikutnya.
- Setter objek yang mengembalikan true baru menjamin perintah masuk antrean.
  Perubahan layout dikirim secara berkelompok tanpa getter setelah setiap setter.
  Hasilnya diperiksa pada timer berikutnya; teks/warna dibandingkan dengan properti
  aktual setiap refresh sehingga perintah yang gagal dieksekusi tetap dicoba lagi.
  Verifikasi cache saat handoff deinit juga dilakukan sesudah seluruh batch dikirim.
- Init tidak membuat tabel atau membaca histori tabel. Pemulihan cache hanya
  memindai objek bertipe label, bukan seluruh gambar chart. Kegagalan GUI ditangani
  timer dan tidak menggagalkan indikator/garis BB. Ini memperbaiki regresi 1.06,
  yang terlalu banyak melakukan verifikasi sinkron dan menggagalkan init jika
  layout belum siap. Angka jumlah panggilan dari adapter bukan pengukuran latensi MT5.
- Redraw hanya dipaksa saat teks/warna berubah, objek diperbaiki, atau tabel
  dihapus. Tooltip/timestamp/cache saja tidak memaksa redraw. MT5 tetap dapat
  melakukan repaint chart saat timeframe berubah; ini bukan jaminan tanpa repaint.
- Timer diaktifkan di `OnInit`, diproses di `OnTimer`, dimatikan di `OnDeinit`.
  Handle chart dilepas setelah deinit. Objek dibersihkan saat dilepas atau init gagal.

Experts/Journal mencatat `BollingerTable 1.07: initialized` ketika init berhasil.
Kegagalan init mencatat tahap yang gagal dan error terminal. Perbaikan tabel
yang belum selesai dicatat maksimal satu kali setiap 30 detik, sambil dicoba ulang.

## Instalasi dan validasi

1. MT5: **File > Open Data Folder**.
2. Salin folder `BollingerTable`, termasuk `.mq5` dan `BollingerSignal.mqh`, ke
   `MQL5/Indicators/`.
3. Buka `BollingerTable.mq5` di MetaEditor, tekan **F7**.
4. Tambahkan dari Navigator > Indicators > BollingerTable.

Jalankan `python3 tests/check_bollinger_table.py` dari root workspace. Runner
mengompilasi **seluruh source** lewat adapter C++ dan antrean objek simulasi:
init/deinit/timer, kegagalan init, salinan buffer, pemilihan timeframe, SMA tujuh
applied price, deret datar, snapshot/data gagal, status cache, beberapa instance,
label hilang, cache rusak dan perintah diterima tetapi gagal dieksekusi. Regresi
1.07 memeriksa bahwa kegagalan GUI tidak menonaktifkan garis, layout diverifikasi
pada timer berikutnya, dan jumlah panggilan sinkron init/handoff/refresh dibatasi
bahkan dengan 1.000 objek gambar lain di chart simulasi.
Adapter ini **bukan compiler MQL5** dan tidak membuktikan rendering, scheduler,
latensi atau kalkulasi `iBands` native di build terminal pengguna.

Di Windows, lakukan F7 dan cocokkan garis serta nilai tabel dengan Bollinger Bands
bawaan pada timeframe/candle yang sama, termasuk semua applied price. Periksa
pergantian TF cepat, simbol, resize, koneksi terputus/pulih, penanda cache setelah
3 detik, beberapa instance, penghapusan objek, dan pembersihan saat dilepas.
Indikator tidak mengirim order atau alert. Tidak ada ZIP yang dibuat.

Referensi: [iBands](https://www.mql5.com/en/docs/indicators/ibands),
[applied price](https://www.mql5.com/en/docs/constants/indicatorconstants/prices),
[CopyRates](https://www.mql5.com/en/docs/series/copyrates),
[setter objek asynchronous](https://www.mql5.com/en/docs/objects/objectsetstring),
[siklus init/deinit](https://www.mql5.com/en/book/applications/runtime/runtime_oninit_ondeinit),
[EventSetTimer](https://www.mql5.com/en/docs/eventfunctions/eventsettimer).
