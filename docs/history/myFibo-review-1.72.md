# Review myFibo 1.71 → 1.72

Cakupan: EA myFibo, GUI, pemilihan pasangan Auto, CFibonacci/CSwingDetector,
persistence, runner pengujian, serta ZIP/CMD Windows. Review source dan pengujian
lokal dilakukan pada macOS; tidak ada profiling atau eksekusi MetaTrader Windows.

## Temuan yang diperbaiki

| Prioritas | Temuan pada 1.71 | Dampak | Perbaikan 1.72 |
|---|---|---|---|
| P2 | Handler mode/TF/Cari Swing memanggil CopyRates langsung. | Callback GUI dapat menunggu pemuatan riwayat. | GUI hanya menjadwalkan permintaan; timer melakukan bulk fetch. Permintaan eksplisit ikut handoff saat pindah timeframe. |
| P2 | Event penghapusan OBJ_FIBO tidak ditangani. | GUI dan g_has_swing masih menyatakan fibo ada setelah pengguna menghapusnya di chart. | Event penghapusan objek milik EA membersihkan model/display, tanpa mengubah checkbox atau membangkitkan pasangan yang sama. |
| P2 | Nilai kunci diperbarui meskipun ApplyAnchorLock gagal. | Checkbox/model bisa menyatakan terkunci sementara properti objek tidak sesuai. | Kegagalan penulisan properti mengembalikan pilihan checkbox/model dan mencoba menerapkan kembali nilai sebelumnya. |
| P2 | No-pair dari CopyRates parsial dicache sebagai bar selesai. | Data tambahan yang tiba pada bar yang sama tidak diperiksa sampai H1/D1 berikutnya. | Hasil negatif parsial tidak dicache sebagai selesai; retry diberi jeda 5 detik. |

Keempat kasus direproduksi oleh regression suite sebelum source diperbaiki,
kemudian suite yang sama lulus pada source baru. Pengujian juga mencakup
pembatalan request mengantre oleh Reset, backoff agar retry tidak berjalan setiap
timer tick, serta kelangsungan request eksplisit saat pindah timeframe.

Kode terkait: `RequestAutoSearch`, `ScheduleAutoRetry`, `RefreshAutoSwing`,
`OnTimer`, `OnChartEvent`, dan handoff state di
[myFibo.mq5](../Experts/myFibo/myFibo.mq5).

**Batas perbaikan GUI:** timer bukan thread terpisah. Semua event EA tetap memakai
antrean yang sama; bila CopyRates di timer menunggu server, event GUI berikutnya
juga dapat tertunda. Perubahan ini membatasi pekerjaan pada callback klik dan
mengendalikan retry, bukan bukti bahwa seluruh lag jaringan hilang. Pengukuran
latensi nyata dan kesiapan history masih perlu diuji di Windows.

## Optimisasi dan struktur yang sudah memadai

- Tidak ada kalkulasi pivot atau CopyRates 500 candle pada jalur mouse move.
- Semua event GUI tetap melalui driver native CAppDialog sekali, tanpa throttle.
- Riwayat biasanya dipindai hanya saat candle analisis baru tutup; pasangan sama
  tidak ditulis ulang. Retry parsial diberi jeda.
- Hanya satu OBJ_FIBO dipakai. Model terakhir dipulihkan jika update gambar gagal.
- Detector memvalidasi data, mendukung AS_SERIES, dan mengeluarkan pivot
  terkonfirmasi tanpa menduplikasi snapshot. Input invalid mempertahankan hasil.
- Pada batas 500 candle dan kiri/kanan maksimum 20, algoritma O(N × (L+R)) masih
  berukuran kecil. Belum ada bukti profiling yang membenarkan penggantian dengan
  algoritma incremental yang lebih kompleks.

## Kekurangan / batas yang masih tersisa

1. **Validasi native Windows belum otomatis.** Runner C++ mensimulasikan API
   platform dan kontrol. Ia tidak mengompilasi MQL5, menjalankan .cmd, merender
   CAppDialog, atau mengukur FPS. Kasus const 1.71 menunjukkan pentingnya F7 dan
   smoke test langsung pada versi Standard Library terminal pengguna.
2. **Modul utama masih besar.** Lifecycle, state, renderer objek, dan orchestration
   berada di myFibo.mq5. Ekstraksi persistence dan renderer layak dilakukan sebelum
   menambah CMarketStructure, agar perubahan struktur tidak menambah coupling GUI.
   Refactor besar tidak dilakukan pada patch ini karena tidak memperbaiki bug
   runtime yang direproduksi dan menambah risiko regresi/dependensi paket.
3. **Auto masih pivot lokal.** Belum ada HH/HL/LH/LL, BOS/CHoCH, filter jarak swing,
   atau pengukuran kualitas pasangan. Window 500 candle, kebijakan equal strict,
   serta pilihan TF GUI masih tetap. Ini batas fitur yang terdokumentasi.
4. **Persistence terbatas pada pergantian timeframe.** Restart terminal/melepas EA
   bukan mekanisme pemulihan sesi. Native GUI file dan metadata chart bukan format
   ekspor yang didesain untuk diedit manual.

## Distribusi dan pengujian

Builder baru [tools/package_myfibo.py](../tools/package_myfibo.py) memvalidasi versi,
daftar file installer, seluruh include proyek, CRC, serta isi ZIP terhadap source.
Paket ditulis melalui file sementara, ZIP versi lama diarsipkan saat release
berganti. Ini mengurangi risiko source baru tidak ikut paket atau include tertinggal.

```bash
python3 tests/check_swing_detector.py
python3 tests/check_myfibo_modes.py
python3 tools/package_myfibo.py
python3 tools/package_myfibo.py --check
```

Hasil lokal: 46 pemeriksaan detector lulus; regresi controller, antrean data,
penghapusan native, kegagalan lock, rollback, persistence, dan GUI melalui API
simulasi lulus dengan AddressSanitizer/UndefinedBehaviorSanitizer. Isi paket dan
versi source/README/INSTALL tervalidasi. EX5 tidak dibuat di macOS ini.

Smoke test Windows: install CMD terbaru → F7 → attach 1.72 → ubah mode/TF dengan
history yang belum siap → coba Cari Swing lalu Reset sebelum timer berjalan →
hapus fibo lewat Objects List → centang/lepas kunci → ganti timeframe. Periksa
hasil GUI, log, kelancaran drag, serta state tidak saling bertabrakan antar-chart.

Referensi perilaku platform:
[CopyRates](https://www.mql5.com/en/docs/series/copyrates),
[antrean OnTimer](https://www.mql5.com/en/docs/event_handlers/ontimer),
[event penghapusan objek](https://www.mql5.com/en/docs/constants/chartconstants/enum_chartevents).
