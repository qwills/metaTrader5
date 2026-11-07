# myFibo changelog

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
