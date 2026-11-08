# Workspace MetaTrader 5

Kumpulan EA, indikator, library MQL5, dan Pine Script. Panduan compiler dan
alternatif build tanpa instalasi MT5 di Mac ada di [docs/BUILD.md](docs/BUILD.md).
Hasil pemeriksaan awal ada di [docs/history/REVIEW.md](docs/history/REVIEW.md);
catatan perapihan paket di [docs/package-review.md](docs/package-review.md).

```text
Experts/
  AutoSL/          Pending limit order, lot sebagai input, SL dihitung dari risiko
  exeAutoSL/       Market BUY/SELL, lot sebagai input, SL dihitung dari risiko
  myCalc/          Pending limit order, SL sebagai input, lot dihitung dari risiko
  exeMyCalc/       Market BUY/SELL, SL per sisi, lot dihitung dari risiko
  EA1/            Alat menggambar Fibonacci (tanpa pengiriman order)
  AutoFibo/       Swing otomatis Pivot/Market Structure, risiko/SL/lot per level
  manualFibo/     Manual, enam rasio, SL per level dan lot berdasarkan % equity
Indicators/
  RiskReward/     Visualisasi risk/reward Long dan Short
Include/
  _common/
    Fibo/         Model, risiko, GUI, chart/state bersama + Fibonacci.mqh
    Swing/        CSwingDetector dan tipe swing terkonfirmasi
    Structure/    CMarketStructure: pivot, arah, BOS/CHoCH
PineScript/
  smc.txt         Source Pine Script, terpisah dari MQL5
archive/
  backups/        Arsip sebelum perapihan, program contoh dihapus
  packages/       ZIP rilis lama EA1/myFibo, tanpa program contoh
  logs/           Log kompilasi historis, bukan hasil validasi saat ini
  metadata/       Metadata dan catatan perapihan lama
distribution/
  AutoFibo/       Source otomatis, CMD Windows dan petunjuk (ZIP sesuai permintaan)
  manualFibo/     ZIP/CMD terpisah untuk EA manual saja
docs/            Panduan aktif, reference API, dan history/ untuk dokumen lama
tests/           Fibonacci, detector, structure, controller dan GUI melalui adapter
tools/           Helper build, builder/validator paket, history/ untuk helper lama
```

Varian pending dan market dikelompokkan sebagai EA, tetapi kode tidak disatukan:
perilaku order dan isi header berbeda meskipun beberapa nama file sama.
Workspace memakai satu repositori Git di root. ZIP, EX5, log dan arsip lokal
berada di `.gitignore`. Metadata repositori lama dipertahankan di
`archive/git-history/`. Helper initial commit lama dipindahkan ke `tools/history/`;
tidak diperlukan untuk commit harian.

Commit rilis memakai annotated tag per EA, misalnya `AutoFibo-v3.02` dan
`manualFibo-v1.15`. Panduan commit, tag dan push ada di
[docs/releases.md](docs/releases.md).

```bash
./tools/compile_mql5.sh --doctor
# Setelah compiler tersedia:
./tools/compile_mql5.sh Experts/AutoSL/AutoSL.mq5
```

File `.ex5` yang ada adalah hasil build lama dan dipertahankan. File itu belum
dikompilasi ulang atau diuji di MT5 pada sesi perapihan ini. Pada sesi perapihan, source lama hanya berubah pada path include Fibonacci
di EA1; logika trading tetap sama. EA `AutoFibo` dan `manualFibo` perlu dikompilasi dengan MetaEditor Windows.

Untuk instalasi, gunakan **File > Open Data Folder** pada terminal tujuan.
Salin `.ex5` dari `Experts` ke `MQL5/Experts`, dari `Indicators` ke
`MQL5/Indicators`. Gunakan folder proyeknya
agar nama tidak bertabrakan. Saat membangun source di terminal, pertahankan
struktur `Experts` dan `Include` di bawah satu root.

Backup sebelum perubahan dan hash file asli tercatat di
[docs/history/cleanup-manifest.json](docs/history/cleanup-manifest.json). Arsip disimpan di `archive/backups/`; isinya telah dibersihkan dari program contoh.

Referensi Standard Library lokal: [panduan](docs/reference/standard-library-guide.md).
Downloader manual resmi Windows ada di `docs/reference/download-reference.cmd`.

Semua program contoh telah dihapus dari source dan paket ZIP, termasuk arsip
rilis lokal. Pemeriksaan library berada di `tests/fixtures/`, dijalankan melalui
runner `tests/check_*.py`, dan tidak diinstal ke MetaTrader. EA1 tetap dipertahankan
sebagai EA yang dapat digunakan. Arsip lama telah dikemas ulang tanpa contoh;
catatan hash pemindahan lama merupakan catatan historis sebelum perubahan ini.

Mulai dari indeks [docs](docs/README.md), [tools](tools/README.md),
[tests](tests/README.md), atau [distribution](distribution/README.md). Folder source
mempertahankan layout MetaEditor; binary EX5 lama tetap di samping source.

EA manual baru: [manualFibo](Experts/manualFibo/README.md), dengan enam checkbox
rasio termasuk 88.6%. Source, ZIP dan state chart terpisah dari AutoFibo, tetap
menggunakan satu repositori Git dan class kalkulasi Fibonacci bersama.

`myFibo` telah diganti menjadi [AutoFibo](Experts/AutoFibo/README.md), khusus swing
otomatis tanpa pilihan Manual/Auto. Group box mengikuti manualFibo. Keduanya
berbagi kelas Include/_common/Fibo untuk rasio, SL per level dan lot berdasarkan % equity.
Untuk Windows, salin folder EA beserta Include/_common/Fibo lengkap; AutoFibo juga
memerlukan Include/_common/Swing dan Include/_common/Structure. ZIP tidak dibuat kecuali diminta.
