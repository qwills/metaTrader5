# Referensi lokal MQL5 / Standard Library

Diperiksa: 2026-11-06. Panduan kerja proyek, bukan salinan lengkap manual.
Baca file ini dan source proyek sebelum mencari web lagi. Jika PDF tersedia,
cari definisi kelas di PDF; untuk kecocokan build terminal, header native adalah
acuan terakhir. Panduan tidak membuktikan suatu program sudah berhasil dikompilasi.

## Manual resmi dan cara mengaksesnya

MetaQuotes menyediakan MQL5 Reference sebagai satu PDF dan CHM, termasuk bagian
Standard Library. PDF bisa dibaca di macOS; CHM untuk bantuan offline di Windows.
Unduh dengan `download-reference.cmd` di folder ini. File disimpan di sebelah CMD.
Akses unduhan dari shell lingkungan pengembangan gagal DNS pada sesi ini:
`mql5.pdf` / `mql5.chm` belum tersimpan di workspace.

- [Indeks resmi dan tautan unduhan](https://www.mql5.com/en/docs)
- [PDF resmi](https://www.mql5.com/files/docs/mql5.pdf)
- [Standard Library](https://www.mql5.com/en/docs/standardlibrary)

Di Windows: buka MetaEditor > Help > MQL5 Reference, atau pilih nama kelas/fungsi
lalu F1. Source Standard Library ada di `MQL5\Include` terminal, bukan pada
folder Include proyek ini. Jangan mengirim pengganti header native di paket EA.
Jika suatu signature berbeda, periksa header terminal yang dipakai untuk F7.

## Peta include

| Kebutuhan | Include terminal |
| --- | --- |
| Dialog dan application dialog | `Controls\Dialog.mqh` |
| Bingkai group | `Controls\Panel.mqh` (`CPanel`) |
| Input harga/risiko | `Controls\Edit.mqh` (`CEdit`) |
| Tombol / label | `Controls\Button.mqh`, `Controls\Label.mqh` |
| Pilihan / checkbox / angka | `Controls\ComboBox.mqh`, `Controls\CheckBox.mqh`, `Controls\SpinEdit.mqh` |
| Informasi chart / objek chart | `Charts\`, `Objects\` |
| Trading / indikator / koleksi | `Trade\`, `Indicators\`, `Arrays\`, `Generic\` |

Header pada MQL5\Include dipanggil dengan `<...>`; file saudara pada folder
EA dengan `"..."`. Contoh proyek: `<Swing\SwingDetector.mqh>` dan
`"MyFiboDialog.mqh"`.

## Dialog yang dipakai myFibo

`CAppDialog` menurunkan `CDialog`, menyediakan siklus aplikasi, event chart dan
penyimpanan GUI. Pakai `Create`, tambahkan kontrol dengan `Add`, lalu `Run`.
Teruskan `OnChartEvent` EA ke `ChartEvent` native tanpa memotong aliran mouse.
Panggil `Destroy(reason)` pada deinitialisasi. Posisi GUI dapat dipulihkan melalui
`IniFileSave` / `IniFileLoad`; nama file dapat disesuaikan melalui `IniFileName`.
Sumber: [CAppDialog](https://www.mql5.com/en/docs/standardlibrary/controls/cappdialog).

`CDialog` menyediakan caption, client area, pengelompokan anak melalui `Add`,
serta handler drag. Dalam proyek, gunakan mekanisme native untuk drag; tambahan
intersepsi mouse harus terbatas pada pemilihan candle agar tidak menghambat GUI.
Sumber: [CDialog](https://www.mql5.com/en/docs/standardlibrary/controls/cdialog).

`CSpinEdit` menyimpan angka integer dengan batas minimal/maksimal dan tombol
increment/decrement. Buat kontrol dulu, tetapkan batas, lalu tetapkan nilai.
`Value()` membaca nilai, `Value(value)` menetapkannya. `OnChangeValue()` adalah
hook virtual untuk pembaruan internal nilai.
Sumber: [CSpinEdit](https://www.mql5.com/en/docs/standardlibrary/controls/cspinedit),
[OnChangeValue](https://www.mql5.com/en/docs/standardlibrary/controls/cspinedit/cspineditonchangevalue).

## Keputusan dan pelajaran dari source proyek

Berikut aturan proyek hasil implementasi/review, bukan jaminan perilaku semua
versi Standard Library:

- Getter wrapper GUI tidak const: versi library pengguna pernah memiliki
  `Value()` / `Checked()` non-const.
- Angka default Auto 2/2 disegarkan lewat `CMyFiboSpinEdit.SetDisplayedValue`.
  Nilai tersimpan dan teks edit harus diperiksa terpisah setelah recreate.
- Konfigurasi programatik bisa memicu event perubahan. Controller memeriksa
  apakah setting benar-benar berbeda sebelum menjadwalkan analisis ulang.
- Perhitungan harga tidak ditempatkan di kontrol GUI atau handler mouse move.
- `CopyRates` dilakukan melalui timer, maksimal sekali pada candle analisis baru
  kecuali pencarian eksplisit/retry. Timer masih memakai antrean event EA.
- Data pivot memakai candle tertutup (`CopyRates` start_pos=1). Waktu swing
  adalah waktu buka candle pivot; pivot baru diketahui setelah candle kanan selesai.
- `CFibonacci`, `CSwingDetector`, `CMarketStructure` milik proyek, bukan kelas
  Standard Library. `OBJ_FIBO` hanya untuk gambar; model harga tetap terpisah.
- Perubahan timeframe memicu deinit/init. Model harus dipulihkan tersendiri,
  bukan mengandalkan penyimpanan posisi dialog.

## Validasi rutin

Jalankan runner pada folder tests, lalu builder ZIP. Runner C++ hanya memeriksa
logika MQL melalui adapter; tidak memvalidasi renderer, ABI atau compiler MQL5.
Di Windows, F7 dan uji interaksi chart tetap diperlukan. Baca source header
terminal ketika ada error API; gunakan web jika manual lokal belum mencakup
API itu atau perilaku build terbaru perlu dikonfirmasi.

## Architecture after myFibo 2.10

Drawing and chart geometry live in MyFiboChart; chart-local state codecs in
MyFiboState. The main EA coordinates events and retries; model classes remain
independent of chart APIs. Use the typed analysis outcome instead of treating
false/no-pair as a data error. Label rendering failures must never block valid
anchor calculation or force a data fetch.

## Chart object layering (2.11)

`OBJPROP_BACK` mengatur background plane. `OBJPROP_ZORDER` adalah prioritas
penerimaan klik ketika objek bertumpuk, bukan urutan gambar. Anotasi myFibo
menggunakan BACK=true dan ZORDER=0 agar panel Standard Library tetap di depan;
Fibo tetap selectable jika anchor tidak dikunci. Tidak perlu recreate dialog
atau loop mengatur properti pada mouse move. Konfirmasi visual tetap di Windows.
Referensi: [Object Properties](https://www.mql5.com/en/docs/constants/objectconstants/enum_object_property),
[OBJ_TEXT](https://www.mql5.com/en/docs/constants/objectconstants/enum_object/obj_text).

## Timeframe chart (2.13)

Gunakan `_Period` sebagai timeframe analisis EA. TF pada GUI hanya label chart,
bukan parameter user terpisah. Pada handoff, bandingkan TF snapshot dan chart:
checkpoint TF berbeda tidak boleh dipakai ulang. Pertahankan anchor Manual atau
terkunci; jadwalkan analisis Auto TF baru pada timer. Konfigurasi kiri/kanan tetap
berlaku untuk Pivot dan Market Structure. Dukung semua interval native MT5, bukan
hanya daftar dropdown lama. Referensi: [Chart Timeframes](https://www.mql5.com/en/docs/constants/chartconstants/enum_timeframes).

Mulai 2.14, informasi TF di GUI dihapus seluruhnya. Timeframe tetap mengikuti
`_Period`; parameter timeframe tidak lagi diperlukan oleh SetSettings dialog.

## Bingkai group manualFibo (1.02)

`CPanel` adalah rectangle label untuk mengelompokkan kontrol. Gunakan
`BorderType(BORDER_FLAT)`, `ColorBorder(clrSilver)`, dan
`ColorBackground(CONTROLS_DIALOG_COLOR_BG)` untuk bingkai abu-abu tipis.
Buat/tambahkan bingkai sebelum kontrol di dalamnya agar kontrol tampil di depan.
Kontrol tetap anak dialog; bingkai adalah pengelompokan visual. Native dialog
mengurus perpindahan, minimize dan restore, tanpa handler mouse tambahan.
Signature diperiksa pada [CPanel resmi](https://www.mql5.com/en/docs/standardlibrary/controls/cpanel)
dan [ColorBorder](https://www.mql5.com/en/docs/standardlibrary/controls/cwndobj/cwndobjcolorborder).
Header terminal tetap menjadi acuan F7; rendering perlu diverifikasi Windows.

manualFibo 1.04 memakai lima segmen CPanel tipis per group, dengan fill/border
abu-abu yang sama. Bagian atas terputus di area judul; CLabel judul tetap
transparan tanpa panel latar. Semua segmen dan kontrol terdaftar satu kali pada
dialog sehingga native drag/minimize/restore tetap mengurus seluruh GUI.

## Input dan estimasi lot manualFibo 1.10

CEdit dibuat dengan Create, ReadOnly(false), Text dan Add. EA meneruskan semua
chart event ke CAppDialog satu kali. Setelah pemrosesan native, dialog menangkap
CHARTEVENT_OBJECT_ENDEDIT untuk mengkomit risk/SL. Timer hanya memperbarui hasil
lot/ekuitas, bukan teks edit yang mungkin sedang diketik. Parser menolak teks
numerik parsial seperti 2abc dan koma desimal; gunakan titik desimal.

[OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit) menerima
ORDER_TYPE_BUY/SELL, symbol, volume, entry, exit dan output profit; hasilnya dalam
mata uang akun. Kalkulator mengambil ACCOUNT_EQUITY dan SYMBOL_VOLUME_MIN/MAX/STEP
serta SYMBOL_TRADE_TICK_SIZE dari terminal. Referensi volume memakai minimum
broker, lalu hasil akhir diverifikasi lagi agar estimasi loss tidak di atas
budget. Ini bukan validasi margin/order, dan tidak menyertakan biaya/slippage.
Signature CEdit: [dokumentasi resmi](https://www.mql5.com/en/docs/standardlibrary/controls/cedit).

## Limit-only preview manualFibo 1.13

[SymbolInfoTick](https://www.mql5.com/en/docs/marketinformation/symbolinfotick)
mengambil Bid/Ask bersama dalam MqlTick. Preview menolak area Bid..Ask (termasuk
batas) terlebih dahulu, lalu memilih BUY LIMIT di bawahnya atau SELL LIMIT di
atasnya. Ini aturan retracement proyek; bukan batas seluruh kemampuan order MT5.
SYMBOL_TRADE_STOPS_LEVEL (dari SymbolInfoInteger, overload bool dengan output long)
dikalikan SYMBOL_POINT untuk minimum jarak. Pending BUY diukur dari Ask dan SELL
dari Bid; SL pending diukur terhadap entry. Freeze level bukan batas preview
penempatan awal karena belum ada order yang dimodifikasi.

Acuan jarak: [panduan resmi MetaQuotes](https://www.mql5.com/en/book/automation/symbols/symbols_spreads_levels).
OrderCalcProfit tetap menerima ORDER_TYPE_BUY/SELL untuk estimasi, bukan tipe
pending. EA hanya menampilkan preview limit; tidak ada OrderSend atau tipe stop.
