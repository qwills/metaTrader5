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

## Build dan pemeriksaan

Header `.mqh` dipakai oleh program MQL5 dan tidak menghasilkan EX5 sendiri.
Compile `MQL5/Scripts/Swing/SwingDetectorExample.mq5` untuk memeriksa seluruh class.
Jalankan script di chart; Experts log harus menampilkan:

```text
SwingDetector checks: 46 checks, 0 failure(s)
```

Paket Windows workspace berada di `distribution/swingDetector/`. Jalankan
`build-swingDetector.cmd` di samping ZIP atau dari hasil ekstraknya. Tujuan default
adalah terminal qwills yang telah ditentukan. CMD menyalin file, menemukan
MetaEditor dari `origin.txt` terminal (atau lokasi standar), lalu mengompilasi
script pemeriksaan. Untuk tujuan/compiler lain:

```bat
build-swingDetector.cmd "C:\path\data-folder" "C:\path\metaeditor64.exe"
```

Dari workspace macOS dengan compiler tersedia:

```bash
./compile_mql5.sh Scripts/Swing/SwingDetectorExample.mq5
```

Pemeriksaan lokal tambahan: `python3 tests/check_swing_detector.py`.
Runner C++17 menjalankan algoritma dan 46 pemeriksaan yang sama melalui adapter
array MQL, dengan AddressSanitizer/UndefinedBehaviorSanitizer. Ini **bukan**
kompilasi MQL5 dan tidak menghasilkan EX5. Native build belum dijalankan pada Mac
karena Wine/MetaEditor tidak tersedia. Paket tidak berisi binary EX5.

Class ini belum dihubungkan ke mode Auto myFibo; pemilihan pasangan anchor dan
BOS/CHoCH tetap berada di luar detector.

Referensi API: [CopyRates](https://www.mql5.com/en/docs/series/copyrates),
[ArrayGetAsSeries](https://www.mql5.com/en/docs/array/arraygetasseries),
[ArrayResize](https://www.mql5.com/en/docs/array/arrayresize).
