# myFibo 2.10

EA untuk memilih anchor dan menggambar Fibonacci **50%, 61.8%, 78.6%**.
GUI memakai Standard Library `CAppDialog`, objek gambar `OBJ_FIBO` berwarna hitam.
EA tidak mengirim order.

```text
Mode [Manual / Auto]                 TF [H1]
Metode [Pivot / Market Structure]    Struktur: Bullish/Bearish/Belum jelas
Candle kiri [2]  Candle kanan [2]     (baris Metode/pivot hanya terlihat di Auto)

Swing
[Pilih Swing / Cari Swing / Batal] [Reset]
Awal : harga
Akhir: harga
Arah : Naik/Turun          Sumber: Manual/Pivot/Market Structure (edit)

Fibonacci
50.0% : harga
61.8% : harga
78.6% : harga
[ ] Kunci anchor
Status
```

## Manual

Default Manual, Kunci anchor tidak dicentang. Pilih Swing lalu dua candle dekat
high/low yang diinginkan. Titik memakai ekstrem candle terpilih, bukan harga bebas;
jarak sama ke high/low memilih high. Klik ruang kosong sesudah candle terakhir
ditolak. Manual memakai timeframe chart; TF di GUI untuk analisis Auto.

Saat memilih pengganti, Fibo lama tetap ada. Batal/Esc mengembalikan GUI ke hasil
lama; pengganti baru diterapkan setelah dua titik valid dipilih. Preview dan hasil
lama sama-sama dipertahankan saat mengganti timeframe chart. Reset menghapus hasil.

Double-click Fibo untuk mengedit anchor atau Properties. Edit memakai harga bebas
(tidak di-snap ulang ke candle), disinkronkan setelah drag/Properties selesai.
Edit invalid dikembalikan ke hasil valid terakhir. Sumber anchor tetap ditampilkan,
dengan penanda `(edit)`; metode terpilih tidak menyamarkan asal Fibo yang masih ada.

## Auto

TF analisis default H1; pilihan M1/M5/M15/M30/H1/H4/D1/W1/MN1. Candle kiri/kanan
langsung terisi 2/2, rentang 1..20. Kedua metode memakai konfigurasi pivot yang sama.
Deteksi strict: equal high/low menggugurkan pivot. Candle yang sekaligus menjadi
pivot high dan low dilewati karena urutan intrabar tidak diketahui.

| Metode | Anchor awal | Anchor akhir |
| --- | --- | --- |
| Pivot (default) | Pivot berlawanan terbaru yang valid | Pivot confirmed terbaru yang tidak ambigu |
| Market Structure bullish | Low confirmed yang diketahui sebelum BOS | High candle BOS tertutup |
| Market Structure bearish | High confirmed yang diketahui sebelum BOS | Low candle BOS tertutup |

Endpoint Market Structure adalah ekstrem candle tertutup, bukan pivot yang sudah
menunggu candle kanan. Origin BOS dibekukan saat event terjadi. Setelah CHoCH atau
sebelum BOS valid, tidak ada pasangan baru: gambar sebelumnya dipertahankan, sumber
aslinya tetap terlihat, status menunggu BOS. Tidak ada fallback diam-diam ke Pivot.

Pasangan/event sama mempertahankan edit manual. Cari Swing menerapkan lagi hasil
metode terpilih. BOS baru memilih impuls baru; endpoint tidak mengikuti harga tiap
tick. Kunci anchor hanya berubah melalui checkbox, dan menghentikan analisis Auto
serta pembaruan label. Mengganti setting saat terkunci menyimpan pilihan; lepas
kunci untuk melanjutkan. Reset membatalkan pencarian mengantre dan label retry.

## Struktur dan kontinuitas

HH/LH membandingkan high dengan high sebelumnya; HL/LL membandingkan low dengan
low sebelumnya. H/L adalah seed; EH/EL adalah harga sama. Bullish awal membutuhkan
high dan low sama-sama meningkat; bearish membutuhkan keduanya menurun. Setelah
arah aktif, pola campuran tidak langsung menghapus arah.

BOS: close melewati swing searah struktur. CHoCH: close menembus protected swing
melawan arah. Wick dan close sama persis tidak cukup. Swing acuan harus sudah
confirmed sebelum candle break. BOS memperbarui protected opposing swing; CHoCH
mengembalikan arah ke Belum jelas sampai perbandingan swing baru menyepakati arah.
Belum jelas tidak sama dengan sideways. Ini aturan raw-pivot structure proyek.

Jendela data/display maksimal 500 candle tertutup. Setelah bootstrap, checkpoint
meneruskan arah, protected swing, pivot terakhir yang sudah aktif, dan event baru:
normalnya tidak menginisialisasi ulang arah setiap histori kiri keluar. Event BOS
menyimpan endpoint sehingga tetap bisa digunakan saat candlenya keluar jendela.
Checkpoint memori bounded: maksimal 100 event lama ditambah event batch berjalan;
handoff timeframe menyimpan 20 event terbaru (sama dengan batas label break).

Koreksi OHLC pada overlap yang masih tercache atau penambahan histori di kiri
memicu replay dan catatan Experts. Perubahan pada histori di luar cache tidak
bisa diperiksa secara retrospektif. Setelah handoff, close candle checkpoint
terakhir diverifikasi; cache overlap penuh dibangun lagi dari data baru.
Gap tanpa overlap cukup dilaporkan sebagai error, bukan direset diam-diam. Cari
Swing mengizinkan bootstrap ulang setelah gap tersebut; reset/revision dapat
menghasilkan arah berbeda. Checkpoint tidak dijanjikan bertahan setelah terminal
benar-benar ditutup atau EA dilepas.

## Arsitektur dan performa

| File | Tanggung jawab |
| --- | --- |
| myFibo.mq5 | Event, setting, selection state, jadwal analisis dan retry |
| MyFiboAuto.mqh | Hasil AnalysisError/Waiting/Ready, pemilihan anchor, kontinuitas |
| MyFiboChart.mqh | OBJ_FIBO, label cache, marker, konversi koordinat/candle |
| MyFiboState.mqh | Snapshot GUI/model dan checkpoint chart-local |
| MyFiboDialog.mqh | Kontrol Standard Library; tanpa deteksi swing/perhitungan fibo |
| Include/Fibo/Fibonacci.mqh | Perhitungan harga: akhir + (awal - akhir) * rasio |
| Include/Swing/SwingDetector.mqh | Pivot confirmed; satu pass per analisis |
| Include/Structure/MarketStructure.mqh | Klasifikasi, arah, BOS/CHoCH dan checkpoint |

Riwayat diambil di timer, bukan handler klik/mouse move. Timer dilewati selama
GUI digeser atau mouse ditekan. Tidak ada throttle pada driver mouse native.
Timer tetap memakai antrean EA; pemuatan riwayat server bisa memiliki latensi.

Maksimal 30 label pivot + 20 label break hitam. Objek yang tidak berubah tidak
ditulis ulang. Label error tidak memblokir Fibo: retry rendering terpisah, tanpa
CopyRates/perhitungan ulang anchor. Pesan transient hilang setelah recovery dan
pesan edit manual dipertahankan. Data invalid tidak dicache sebagai hasil no-pair;
retry data berjeda 5 detik. Hasil waiting pada histori pendek dicoba ulang maksimal
3 kali sebelum menunggu candle analisis baru atau Cari Swing.

## Pindah timeframe dan instalasi

Pada symbol sama, mode, metode, pivot, lock, harga, sumber/edit, preview, arah,
checkpoint dan gambar dipertahankan. Posisi/minimize memakai native IniFileSave /
IniFileLoad, nama per ChartID `GUI_v5`. Layout lama tidak dimuat pada upgrade yang
menambah kontrol; perpindahan timeframe selanjutnya memakai layout versi sama.
Snapshot schema 6 membaca juga schema 5 dari 2.00; schema 1..4 sudah dihentikan.
Asal anchor dari schema lama ditampilkan Unknown karena dulu belum dicatat.

1. Gunakan ZIP dan CMD rilis yang sama, atau ekstrak lengkap ZIP dan jalankan CMD.
2. CMD memprioritaskan ZIP yang berdampingan dibanding folder MQL5 lama. Semua
   file incoming diverifikasi dengan versi dan SHA-256 manifest sebelum disalin.
3. File paket langsung ditimpa, tanpa backup Windows; proyek lain tidak dihapus.
4. Buka Experts/myFibo/myFibo.mq5 di MetaEditor, F7; attach kembali versi 2.10.

Tujuan default:
`C:\Users\qwills\AppData\Roaming\MetaQuotes\Terminal\E3E3B02889D32F38295D39BF94B6AD4A`.
CMD juga menerima argumen path Data Folder/MQL5 lain. Jika penyalinan gagal di
Windows, instalasi bisa parsial; perbaiki penyebab lalu jalankan ulang CMD.

## Validasi

```
python3 tests/check_swing_detector.py
python3 tests/check_market_structure.py
python3 tests/check_myfibo_modes.py
python3 tests/check_myfibo_regressions.py
python3 tools/package_myfibo.py
python3 tools/package_myfibo.py --check
```

Runner memakai source MQL melalui adapter C++ dan fake MT5/GUI; 153 pemeriksaan
struktur, 46 detector, serta regression controller/geometry/streaming. Bukan
compiler MQL5. F7, native popup/minimize/drag, render chart, server CopyRates, dan
CMD/PowerShell masih perlu diuji Windows. Script native untuk 153 pemeriksaan ada
di Scripts/Structure/MarketStructureExample.mq5. Tidak ada EX5 dalam ZIP.

Referensi Standard Library lokal: docs/reference/standard-library-guide.md di
workspace, atau reference/standard-library-guide.md dalam ZIP. Riwayat versi ada
di CHANGELOG.md; perbaikan review dirinci di docs/myFibo-review-2.10.md.
