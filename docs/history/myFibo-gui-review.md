# Review GUI myFibo 1.50

Pengguna melaporkan drag memburuk setelah versi 1.40. Pemeriksaan ini mencakup
source proyek, pola driver Standard Library, dan contoh resmi MetaQuotes.
Tidak ada profiling atau akses langsung ke MetaTrader Windows pengguna.

## Temuan

- Jalur lama memakai `CDialog` langsung dan memanggil `OnMouseEvent`/`OnEvent`
  secara manual. Hook drag memindahkan kontrol, tetapi wrapper proyek tidak
  menyediakan seluruh penanganan fokus, prioritas, dan redraw driver aplikasi.
- Versi 1.40 menambahkan filter event 16 ms pada jalur yang sama. Filter itu
  mengurangi event yang diterima driver; uji fungsi filter saja tidak membuktikan
  drag Standard Library bekerja benar. Hasil uji itu tidak cukup sebagai
  validasi perbaikan pengalaman drag pengguna.
- Ada empat objek dekorasi tambahan: dua kotak dan dua garis. Semua ikut dipindah
  bersama dialog dan sekarang dihapus sesuai permintaan.

Bukti source tersebut menjelaskan mengapa integrasi perlu diperbaiki. Itu belum
membuktikan besarnya kontribusi masing-masing faktor terhadap latensi Windows.

## Perubahan

Turunkan GUI dari `CAppDialog`, yang juga turunan `CDialog`. Ikuti lifecycle
Create, Run, ChartEvent, Destroy. Semua event diteruskan sekali tanpa throttle,
termasuk event fokus dan prioritas. Tidak ada override proses drag atau reposition
pada tiap perubahan chart. State scrolling dan flag event chart dikembalikan
saat EA dilepas. Pemilihan candle, kalkulasi, hitamnya fibo, dan pengeditan anchor
tetap dipertahankan. Heading dan spacing tetap menjadi kelompok GUI.

## Contoh dan dokumentasi

1. [Contoh panel CButton](https://www.mql5.com/en/docs/standardlibrary/controls/cbutton)
   menyediakan contoh lengkap lifecycle EA; menjadi acuan utama karena kecil.
2. [CAppDialog](https://www.mql5.com/en/docs/standardlibrary/controls/cappdialog) dan
   [ChartEvent](https://www.mql5.com/en/docs/standardlibrary/controls/cappdialog/cappdialogchartevent)
   mendokumentasikan kelas driver aplikasi dan entry point event.
3. [Panel dan hook drag](https://www.mql5.com/en/articles/4575) memperlihatkan pola
   lain berbasis CAppDialog serta merujuk contoh bawaan terminal di
   `MQL5/Experts/Examples/Controls/` dan
   `MQL5/Indicators/Examples/Panels/SimplePanel/`.
4. Di workspace ini, `Experts/AutoSL` juga memakai CAppDialog, Run, dan ChartEvent.

Contoh-contoh ini adalah referensi integrasi, bukan hasil benchmark kecepatan.

## Validasi dan batasan

Harness C++ menjalankan body fungsi EA yang diekstrak tanpa perubahan, dengan
API platform simulasi. Ia memeriksa penerusan 1000 mouse event tanpa drop,
release di luar panel, custom event, guard saat EA berhenti, routing edit fibo,
sinkronisasi perhitungan/GUI, dan rollback edit tidak valid. Pemeriksaan source
memastikan candle picking serta fungsi gambar dan kalkulasi tidak berubah,
serta kotak/garis dan driver manual telah dihapus.

Harness tidak menjalankan CAppDialog milik terminal. Kompilasi MQL5 dan uji drag
Windows tetap harus dilakukan pada terminal. Prosedur: lepas EA lama, instal ZIP
1.50, F7, attach ulang, lalu drag header perlahan/cepat, lepas mouse di luar panel,
minimize/restore, klik tombol, pilih dua candle, dan edit fibo. Periksa chart tidak
ikut terseret saat memilih serta scrolling pulih setelah selesai.

## Tambahan 1.60: timeframe

Reset ketika pindah timeframe berasal dari cleanup tanpa syarat di OnDeinit dan
OnInit. Cleanup sekarang dibedakan berdasarkan REASON_CHARTCHANGE. Swing tetap
menjadi objek chart yang sama, sementara state seleksi dan anchor melewati handoff
chart-local yang tak ditampilkan. GUI menggunakan file native CAppDialog dengan
nama unik per ChartID. Driver mouse 1.50 tidak diubah. Perubahan symbol dibedakan
melalui identitas symbol pada handoff; state harga lama tidak diterapkan ke symbol
baru. State tidak dijanjikan bertahan setelah EA dilepas atau terminal ditutup.

Pengujian tambahan mencakup round-trip state selesai/pending/kosong, presisi harga,
status, edit anchor terakhir, isolasi antar-chart dan symbol, handoff invalid,
serta penghapusan objek secara manual tanpa kebangkitan ulang saat pindah timeframe.
Test memakai fungsi aktual dan API simulasi; native GUI save/load tetap perlu
pengujian pada terminal pengguna.

Referensi: [OnDeinit dan REASON_CHARTCHANGE](https://www.mql5.com/en/docs/event_handlers/ondeinit),
[visibilitas objek](https://www.mql5.com/en/docs/constants/objectconstants/visible).

## Tambahan 1.70: Manual/Auto dan checkbox

GUI menambahkan combo Manual/Auto, TF analisis, CSpinEdit kiri/kanan, serta
CCheckBox Kunci anchor dengan default false. Tanggal dihilangkan dari label dan
status pemilihan; timestamp tetap menjadi bagian model. Group tetap memakai
heading/spacing. Pengaturan pivot di-hide pada Manual, form direflow hanya saat
mode berganti. Tampilan minimize/restore mengaplikasikan ulang visibilitas kontrol.

Auto memakai CSwingDetector dan CMyFiboAuto sebagai selector pasangan. Ini belum
BOS/CHoCH. CopyRates dimulai dari shift 1, maksimal 500 candle, pada TF analisis
tersendiri. Timer memeriksa candle baru tanpa melakukan pekerjaan riwayat selama
mouse ditekan atau dialog digeser. Pasangan yang sama tidak ditulis ulang; edit
manual tidak mengaktifkan kunci. Hanya checkbox yang mengubah kunci, termasuk
penghentian Auto dan pembatasan editing objek.

Snapshot versi 2 menyimpan mode, TF, kiri/kanan, checkbox, bar terakhir dan identitas
pasangan Auto di samping state sebelumnya. Nama layout native diganti GUI_v3 agar
struktur kontrol baru tidak membaca file binary layout 1.60 yang berbeda.

Pengujian tambahan pada tests/check_myfibo_modes.py menjalankan source EA,
selector/detector, dan class dialog aktual melalui adapter C++ dan API simulasi.
Mencakup default kontrol, event mapping, perubahan layout yang idempotent,
minimize/restore, harga tanpa tanggal, locking, update Auto, rollback, dan snapshot.
Test ini tidak merender GUI MetaTrader atau menggantikan kompilasi Windows.
