# SwingDetectorExample

Script pemeriksaan deterministik untuk `CSwingDetector`. Tidak memerlukan data
harga aktual, tidak membuat objek chart, dan tidak mengirim order.

Install `Include/Swing/SwingDetector.mqh` dan `SwingTypes.mqh` ke folder terminal
`MQL5/Include/Swing`. Compile script ini di MetaEditor (F7), kemudian jalankan
melalui Navigator > Scripts > Swing > SwingDetectorExample pada sebuah chart.

Hasil yang diharapkan di log:
`SwingDetector checks: 46 checks, 0 failure(s)`.

Mencakup pivot high/low, konfirmasi kanan, array biasa/timeseries, tie policy,
konfigurasi asimetris, output/hasil yang tetap setelah error, outside candle,
HIGH berturut-turut, data invalid, indeks, dan reset.

Native build dan eksekusi MT5 belum dijalankan di mesin macOS pengembangan.
Algoritma dan pemeriksaan yang sama telah dijalankan melalui adapter C++17.
