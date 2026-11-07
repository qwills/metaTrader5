# Workspace MetaTrader 5

Kumpulan EA, indikator, library MQL5, dan Pine Script. Panduan compiler dan
alternatif build tanpa instalasi MT5 di Mac ada di [docs/BUILD.md](docs/BUILD.md).
Hasil pemeriksaan ada di [docs/REVIEW.md](docs/REVIEW.md).

```text
Experts/
  AutoSL/          Pending limit order, lot sebagai input, SL dihitung dari risiko
  exeAutoSL/       Market BUY/SELL, lot sebagai input, SL dihitung dari risiko
  myCalc/          Pending limit order, SL sebagai input, lot dihitung dari risiko
  exeMyCalc/       Market BUY/SELL, SL per sisi, lot dihitung dari risiko
  EA1/            Alat menggambar Fibonacci (tanpa pengiriman order)
  myFibo/         Manual/Auto Pivot atau Market Structure, TF, kunci, tiga level fibo
Indicators/
  RiskReward/     Visualisasi risk/reward Long dan Short
Include/
  Fibo/           Library Fibonacci.mqh
  Swing/          CSwingDetector dan tipe swing terkonfirmasi
  Structure/      CMarketStructure: pivot, arah, BOS/CHoCH
Scripts/
  Fibo/           Contoh sekaligus pemeriksaan library Fibonacci
  Swing/          46 pemeriksaan deterministik CSwingDetector
  Structure/      153 pemeriksaan pivot, arah, BOS/CHoCH dan streaming
PineScript/
  smc.txt         Source Pine Script, terpisah dari MQL5
archive/
  backups/        Backup lengkap sebelum perapihan
  packages/       ZIP rilis lama EA1 dengan layout aslinya
  logs/           Log kompilasi historis, bukan hasil validasi saat ini
  finder/         Metadata Finder lama
distribution/
  myFibo/         ZIP struktur MQL5, installer Windows .cmd, petunjuk
  swingDetector/  Class, script pemeriksaan, dan CMD install/build Windows
compile_mql5.sh   Helper kompilasi macOS/Wine dan pemeriksaan --doctor
docs/            Panduan build, review, dan manifest pemindahan
tests/           Detector, structure, controller, geometry, checkpoint dan GUI melalui adapter
tools/           Builder/validator ZIP myFibo
```

Varian pending dan market dikelompokkan sebagai EA, tetapi kode tidak disatukan:
perilaku order dan isi header berbeda meskipun beberapa nama file sama.
Workspace memakai repositori Git di root. Untuk initial commit, jalankan
`bash tools/first_commit.sh` dari Terminal. Helper mengimpor source kedua subproyek
sebagai file biasa dan memindahkan metadata Git lamanya ke
`archive/git-history/` (diabaikan Git), sehingga histori dan perubahan lokal tetap
tersimpan. Helper hanya berjalan jika root belum memiliki commit. ZIP, EX5,
log dan arsip lokal tidak masuk commit.

```bash
./compile_mql5.sh --doctor
# Setelah compiler tersedia:
./compile_mql5.sh Experts/AutoSL/AutoSL.mq5
```

File `.ex5` yang ada adalah hasil build lama dan dipertahankan. File itu belum
dikompilasi ulang atau diuji di MT5 pada sesi perapihan ini. Pada sesi perapihan, source lama hanya berubah pada path include Fibonacci
di EA1 dan contoh library; logika trading tetap sama. EA baru `myFibo` belum
memiliki binary hasil kompilasi.

Untuk instalasi, gunakan **File > Open Data Folder** pada terminal tujuan.
Salin `.ex5` dari `Experts` ke `MQL5/Experts`, dari `Indicators` ke
`MQL5/Indicators`, dan dari `Scripts` ke `MQL5/Scripts`. Gunakan folder proyeknya
agar nama tidak bertabrakan. Saat membangun source di terminal, pertahankan
struktur `Experts`, `Include`, dan `Scripts` di bawah satu root.

Backup sebelum perubahan dan hash file asli tercatat di
[docs/cleanup-manifest.json](docs/cleanup-manifest.json). Backup lengkap disimpan di `archive/backups/`; salinan sementara juga tersedia
di `/private/tmp`.

Referensi Standard Library lokal: [panduan](docs/reference/standard-library-guide.md).
Downloader manual resmi Windows ada di `docs/reference/download-reference.cmd`.
