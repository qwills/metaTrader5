# AutoFibo changelog (formerly myFibo)

## 3.04

- Update shared model/risk/state dependencies for manualFibo's fixed balance basis.
  Risk basis is EA configuration, not another user choice or snapshot field.
- AutoFibo retains its equity-based previews, GUI, automatic analysis and no-trade
  behavior; regression coverage checks both consumers of the shared library.

## 3.03

- Update shared risk/model/state dependencies for manualFibo's All / Per level
  allocation and schema 5 persistence. AutoFibo retains its existing Per level
  defaults, GUI and preview-only behavior; it does not import trading/reconciliation.
- Preserve loading of earlier state schemas and verify the automatic-analysis suite.

## 3.02

- Move shared libraries to Include/_common/Fibo, Swing and Structure; update
  native include paths, source installation instructions and package payloads.

## 3.01

- Prevent native automatic minimization when the main chart is shorter than the
  608-pixel dialog or reports zero height during repaint. Child layout notifications
  are retained, and other events still use the native CAppDialog driver.
- Keep user-requested minimize/maximize and minimized-state timeframe persistence.

## 3.00

- Rename EA/folder/installer to AutoFibo and remove the Manual/Auto selector and
  manual candle-selection workflow. Search automatically from confirmed closed bars.
- Preserve Pivot/Market Structure methods, sensitivity, rolling BOS checkpoints,
  independent annotation retries and chart-timeframe following.
- Add native group frames and the same six-ratio, per-level SL and 5%-equity lot
  calculator as manualFibo; share the implementations under Include/Fibo.
- Preserve risk/SL/ratio/lock across timeframe changes; isolate AutoFibo state/object
  names from manualFibo and the former myFibo namespace.
- Repair stale annotation cache keys after object recreation/property failures.
- Migrate automatic-only regression coverage and update both source-package builders.

## 2.18

- Hapus distribusi dan builder SwingDetector terpisah; header tetap di Include/Swing
  dan disertakan dalam myFibo.zip. Perbarui panduan instalasi dan validasi.

## 2.17

- Rapikan dokumentasi historis ke docs/history dan helper build ke tools.
- Kelompokkan arsip paket menurut proyek; perbarui path, indeks folder dan builder.
- Pertahankan layout source MQL5 dan perilaku EA; bangun ulang paket distribusi.

## 2.16

- Hapus seluruh program contoh Fibonacci/Swing dari source dan ZIP; pindahkan
  pemeriksaan ke tests/fixtures tanpa mengubah algoritma produksi.
- Paket SwingDetector hanya menginstal header dengan CMD copy/overwrite.
- Bersihkan contoh dari arsip lokal dan tambahkan validasi isi paket.

## 2.15

- Hapus script contoh MarketStructureExample dari Scripts dan paket Windows.
- Pertahankan 153 pemeriksaan serta fixture BOS sebagai test pengembangan di
  tests/fixtures/market_structure_checks.mqh; tidak diinstal ke MetaTrader.

## 2.14

- Hapus label TF, Chart dan nama timeframe dari GUI. Analisis tetap mengikuti
  timeframe chart. Hapus parameter timeframe yang tidak dipakai dari API dialog.
- Layout native memakai GUI_v7; label Sumber tetap menunjukkan asal anchor yang
  sedang digambar, terpisah dari metode yang dipilih.

## 2.13

- Auto selalu mengikuti timeframe chart. Ganti dropdown TF dengan label read-only.
- Rebuild analisis setelah perubahan TF tanpa mengambil histori di OnInit; jangan
  memuat checkpoint dari TF berbeda. Setting, GUI, Manual dan anchor terkunci
  dipertahankan. Unlock melanjutkan analisis pada TF chart baru.
- Dukung seluruh 21 timeframe native MT5, termasuk interval yang sebelumnya tidak
  ada di dropdown. Snapshot lama tidak lagi menentukan TF analisis.
- Tegaskan Candle kiri/kanan digunakan Pivot dan Market Structure; sensitivitas
  pivot tetap dipertahankan saat berpindah TF. Layout native memakai GUI_v6.

## 2.12

- Hapus manifest.json dari paket dan builder.
- Sederhanakan installer menjadi ekstrak ZIP lalu XCOPY isi folder MQL5 dengan
  overwrite, tanpa daftar file, pemeriksaan versi/hash atau backup Windows.

## 2.11

- Letakkan label HH/HL/LH/LL, BOS/CHoCH, Fibo dan marker preview pada background
  plane agar tidak menutupi panel native. Prioritas klik anotasi tetap rendah.
- Inisialisasi SwingPoint last/first/other secara eksplisit untuk menghindari
  warning possible use of uninitialized variable pada compiler MQL5.
- Pertahankan cache label, sifat editable Fibo dan driver drag native.

## 2.10

- Pisahkan chart drawing/geometry ke MyFiboChart dan persistence ke MyFiboState.
- Pisahkan AnalysisError, WaitingForPair, PairReady; retry validasi data tanpa
  menandai candle sebagai selesai. Status transient pulih pada pasangan sama.
- Label retry independen dari Fibo/data dan cache menghindari chart writes identik.
- Satu detector snapshot dipakai selector dan structure; tambah continuation
  checkpoint untuk normal sliding windows, termasuk handoff timeframe.
- Simpan endpoint pada event BOS, deteksi revisi overlap, laporkan gap eksplisit.
- Pertahankan Fibo lama selama manual reselection; Cancel/Esc mengembalikan GUI.
- Tampilkan sumber anchor serta edit, pisahkan preview dari hasil completed.
- Snapshot schema 6 + dukungan upgrade schema 5; hentikan schema 1..4.
- Installer memprioritaskan ZIP dan memverifikasi manifest/hash sebelum overwrite.
- README fokus pada penggunaan saat ini; review audit baseline diganti regression
  acceptance tests. Tidak membuat backup Windows.

## 2.00

- Auto method selector Pivot / Market Structure.
- Market Structure memakai confirmed origin sebelum BOS dan extreme candle BOS.
- CHoCH menunda pilihan baru tanpa fallback; pilihan bertahan pada TF handoff.

## 1.90

- Arah struktur dan label BOS/CHoCH memakai konfirmasi close yang kausal.

## 1.80

- Class CMarketStructure: H/L, HH/HL/LH/LL, EH/EL dan maksimal 30 label pivot.

## 1.73

- Segarkan angka default spin edit meskipun nilai internal tidak berubah.

## 1.72

- Pencarian GUI dijadwalkan ke timer; retry partial history, deletion cleanup,
  dan rollback checkbox ketika update lock gagal.

## 1.71

- Wrapper getter GUI kompatibel dengan native Value()/Checked() non-const.

## 1.70 dan sebelumnya

- Manual/Auto Pivot dalam native CAppDialog, TF analisis, anchor locking eksplisit,
  harga tanpa tanggal di GUI, tiga level hitam, dan handoff pergantian timeframe.
- Perbaikan drag mengikuti driver GUI native; tanpa kotak pemisah panel.
