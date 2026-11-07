# Review workspace — 5 November 2026

Pemeriksaan mencakup struktur, dependensi include, helper build, artefak lama,
dan status repositori. Ini bukan audit menyeluruh terhadap logika trading.

## Temuan dan tindakan

1. **Compiler lokal tidak tersedia di lokasi umum.** Tidak ada aplikasi MT5 di
   `/Applications`, Wine di PATH, atau prefix default di akun saat ini. Path
   helper lama memakai akun `qwills`. Helper kini menggunakan `$HOME`, menerima
   konfigurasi path, dan menyediakan `--doctor`. Kegagalan installer sendiri
   belum terdiagnosis; perlu pesan error dari percobaan instalasi.
2. **Helper lama bisa melaporkan sukses palsu.** Ketika tidak menemukan hasil
   sukses di log, helper mengembalikan kode proses yang mungkin 0. File log
   sementara juga sudah dibuat sebelum compiler berjalan, sehingga pemeriksaan
   keberadaan file saja tidak memadai. Kini log harus berisi hasil 0 errors,
   tidak kosong, dan output EX5 harus tersedia.
3. **Proyek sejenis tersebar di root.** Semua EA masuk `Experts`, indikator masuk
   `Indicators`, library masuk `Include`, contoh eksekusi masuk `Scripts`, dan
   Pine Script masuk `PineScript`. File ZIP, log historis, dan metadata Finder
   masuk `archive`. Semua file asli diinventarisasi sebelum pemindahan.
4. **Nama mirip tidak berarti duplikat.** AutoSL dan ExeAutoSL memiliki alur
   pending vs market; myCalc dan ExeMyCalc juga berbeda. Header bernama sama pada
   kedua kalkulator memiliki isi berbeda, sehingga tidak digabung/dihapus.
5. **Dua proyek memiliki Git sendiri dan perubahan lokal.** Folder `.git` ikut
   dipindahkan bersama proyek; tidak ada reset, commit, atau penghapusan sejarah.
6. **Include relatif EA1 dan contoh Fibonacci bergantung layout lama.** Keduanya
   disesuaikan ke `../../Include/Fibo/Fibonacci.mqh`; dokumentasi instalasi dan
   pemanggilan helper diperbarui mengikuti struktur baru. Paket ZIP lama tetap
   mempertahankan layout rilis aslinya.
7. **Binary dan log lama bukan bukti build source terkini.** EX5 lama dipertahankan,
   tetapi belum dikompilasi ulang. Log lama disimpan di arsip, bukan disajikan
   sebagai hasil pengujian sesi ini.

## Validasi

- Semua 144 file asli ditemukan pada lokasi baru; 11 file lama diedit dengan
  sengaja (helper, dokumentasi, dan dua path include). File lain identik menurut SHA-256.
- Metadata kedua repositori Git identik byte demi byte dengan kondisi awal.
- Semua 26 include lokal pada 29 file source/header mengarah ke file yang tersedia.
- `bash -n compile_mql5.sh` lulus.
- Pengujian helper menggunakan Wine simulasi: log UTF-16/UTF-8 sukses, error dengan
  exit proses 0, log hilang, output hilang, doctor, source hilang, serta pemilihan
  source default yang tidak valid menghasilkan status yang sesuai. Path dengan
  spasi juga diuji. Simulasi ini hanya memverifikasi helper, bukan compiler MQL5.
- `--doctor` pada lingkungan nyata mendeteksi Wine, prefix, MetaEditor, dan standard
  library yang belum tersedia.
- Kompilasi MQL5, alur PowerShell, dan uji interaktif MT5 belum dijalankan.

Backup lengkap sebelum perubahan tersimpan di `../archive/backups/`; lokasi dan
hash asli tercatat dalam `cleanup-manifest.json`.
