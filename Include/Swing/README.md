# CSwingDetector 1.00

Class MQL5 untuk pivot high/low terkonfirmasi dari candle tertutup. Terpisah dari
CFibonacci, GUI, objek chart, dan market structure. Tidak mengirim order.

```cpp
#include <Swing\SwingDetector.mqh>

CSwingDetector detector;
// Saat inisialisasi:
detector.Configure(2, 2, SWING_EQUAL_REJECT);

// Panggil hanya saat candle analisis baru selesai, dengan riwayat yang cukup:
MqlRates closed_bars[];
int copied = CopyRates(_Symbol, PERIOD_H1, 1, 500, closed_bars);
if(copied == 500 && detector.Update(closed_bars))
{
   SwingPoint high, low;
   if(detector.LastHigh(high) && detector.LastLow(low))
   {
      // high/low belum tentu merupakan satu pasangan impuls Fibonacci.
      // Pasangkan berdasarkan aturan struktur/arah yang dipilih EA.
   }
}
```

## Aturan dan kontrak

- Default: dua candle sebelum dan dua sesudah pivot, tie ditolak. Kedua sisi wajib
  minimal satu candle. Swing baru dikonfirmasi setelah seluruh candle kanan tutup.
- Caller harus mengecualikan candle berjalan: gunakan `CopyRates` dengan posisi
  awal **1**. Class tidak mengetahui waktu sekarang atau timeframe, sehingga
  tidak dapat memeriksa sendiri apakah candle yang diberikan masih berjalan.
- `Update` menerima **snapshot lengkap** dari jendela analisis. Hasil menggantikan
  hasil sebelumnya, bukan menambahkan riwayat. Jendela bergeser berarti pivot yang
  keluar dari jendela ikut hilang. Kiriman berulang tidak menimbulkan duplikasi.
- Mendukung array biasa dan `AS_SERIES`; tidak mengubah input atau arah indeksnya.
  Timestamp wajib positif, unik, dan urut kronologis sesuai flag array. High/low
  harus finite, bukan `EMPTY_VALUE`, dan high >= low. Harga nol/negatif diperbolehkan.
- Data atau konfigurasi invalid menghasilkan `false` dan mempertahankan hasil lama.
  Snapshot kosong/terlalu pendek valid, menghasilkan daftar kosong (`true`).
- Kebijakan equal high/low membandingkan nilai tepat: `SWING_EQUAL_REJECT` menolak
  tie, `SWING_EQUAL_FIRST` memilih yang paling awal, dan `SWING_EQUAL_LAST` memilih
  yang paling akhir di dalam jendela pembanding. Tidak ada toleransi tick otomatis.
- Hasil urut dari lama ke baru. Jika satu candle merupakan high dan low sekaligus,
  kedua titik disimpan, HIGH dahulu. Urutan itu bukan informasi intrabar.
- Pivot HIGH berturut-turut tetap disimpan; detector tidak mengarang LOW di antara
  keduanya. Normalisasi urutan dan swing utama adalah tugas CMarketStructure.
- Versi ini hanya mengeluarkan `confirmed=true`; kandidat sementara belum diekspos.
  Candle di batas kiri/kanan yang belum memiliki konteks cukup tidak dikeluarkan.
- `SwingPoint.time` adalah waktu buka candle pivot, bukan waktu deteksi/konfirmasi.
  Pivot stabil jika riwayat dan konfigurasi tetap; koreksi data historis dapat
  mengubah hasil saat snapshot dianalisis ulang.

## API

| Method | Perilaku |
|---|---|
| `Configure(left, right, equal_policy)` | Atur deteksi; perubahan konfigurasi valid mengosongkan hasil. Konfigurasi sama mempertahankannya. |
| `Update(closed_bars)` | Validasi dan hitung pivot dalam snapshot candle tertutup. |
| `Count()` | Jumlah pivot saat ini. |
| `GetSwing(index, point)` | Index 0 = pivot tertua. Gagal tidak mengubah output. |
| `LastHigh(point)` / `LastLow(point)` | Pivot terakhir menurut jenisnya. |
| `LeftBars()` / `RightBars()` / `EqualPolicy()` | Baca konfigurasi aktif. |
| `Reset()` | Kosongkan hasil; pertahankan konfigurasi. |

Kompleksitas deteksi O(jumlah candle x (left + right)); memori sementara O(jumlah
candle). Panggil saat candle analisis baru tutup, bukan setiap gerakan mouse/tick.
Tolak hasil CopyRates yang belum memenuhi jumlah riwayat yang diminta sebelum
memanggil Update jika EA ingin mempertahankan hasil sebelumnya.

## Instalasi dan pemeriksaan

Header `.mqh` dipakai oleh EA dan tidak menghasilkan EX5 sendiri. Library ini
sudah disertakan di `distribution/myFibo/myFibo.zip`, di bawah MQL5/Include/Swing.
Gunakan installer myFibo untuk menyalinnya bersama EA. Tidak ada paket atau
installer SwingDetector terpisah. Untuk penggunaan pada EA lain, salin folder
Include/Swing ke MQL5/Include/Swing lalu gunakan `<Swing\SwingDetector.mqh>`.

Jalankan `python3 tests/check_swing_detector.py` dari workspace untuk 46 pemeriksaan
di `tests/fixtures/swing_detector_checks.mqh`. Runner C++17 menggunakan adapter
array MQL serta AddressSanitizer/UndefinedBehaviorSanitizer. Ini bukan compiler
MQL5; F7 pada EA pengguna tetap perlu dilakukan di MetaEditor Windows.

Detector digunakan mode Auto myFibo. Pemilihan pasangan anchor berada di
MyFiboAuto, sedangkan BOS/CHoCH dihitung oleh CMarketStructure.

Referensi API: [CopyRates](https://www.mql5.com/en/docs/series/copyrates),
[ArrayGetAsSeries](https://www.mql5.com/en/docs/array/arraygetasseries),
[ArrayResize](https://www.mql5.com/en/docs/array/arrayresize).
