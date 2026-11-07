# myCalc

EA kalkulator risiko untuk pending limit order. Panel menggunakan entry, SL,
TP, risiko akun, dan lot hasil kalkulasi; pengiriman memakai `BuyLimit` atau
`SellLimit`. Varian eksekusi market terpisah di `../exeMyCalc`.

Build dari folder ini: `../../compile_mql5.sh myCalc.mq5 compile.log`.
Lihat `../../docs/BUILD.md` untuk persyaratan compiler. Header `MM*.mqh` adalah
milik varian ini dan berbeda dari beberapa header bernama sama di ExeMyCalc.
`myCalc.ex5` adalah hasil build lama yang belum diverifikasi ulang.
