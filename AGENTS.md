# Workspace MQL5

Untuk pekerjaan Standard Library, baca `docs/reference/standard-library-guide.md`
lebih dahulu. Gunakan manual PDF/CHM lokal jika tersedia dan header native terminal
sebagai acuan signature build pengguna. Jangan berulang kali browsing untuk API
yang sudah tercakup; cari dokumentasi resmi bila referensi lokal kurang atau perlu
memastikan perubahan/perilaku versi terbaru.

Source custom ada di Experts, Indicators, Include; pemeriksaan di tests. Standard Library terminal tidak
dibundel. Include bersama memakai `<...>`; header saudara memakai `"..."`.

Validasi AutoFibo/manualFibo dengan runner relevan di tests serta check_inputs()
pada tools/package_autofibo.py dan tools/package_manualfibo.py. ZIP hanya dibuat
jika diminta; sesudah membangun ZIP, jalankan builder dengan --check. Sesuaikan versi EA, README,
dan INSTALL. Perbarui daftar payload builder bila menambah file; CMD menyalin
seluruh isi folder MQL5 dari ZIP.
Runner adapter C++ bukan compiler MQL5: laporkan bahwa F7 dan rendering GUI perlu
diuji pengguna di Windows. Pertahankan CRLF pada CMD Windows.

Preferensi pengguna: installer/build CMD Windows langsung menimpa file paket,
tanpa membuat backup. Jangan menambahkan kembali backup atau restore otomatis
file instalasi. Preferensi ini tidak menghapus arsip rilis lokal yang sudah ada.

Installer Windows cukup ekstrak ZIP dan copy/overwrite isi folder MQL5. Jangan
menambahkan manifest.json atau pemeriksaan hash/versi pada installer.

Paket distribusi tidak boleh berisi program contoh, Scripts, atau fixture tests.

Panduan folder ada di README.md dan docs/README.md. Review lama/inventaris awal
ada di docs/history; helper compiler ada di tools/compile_mql5.sh. Arsip rilis
berada di archive/packages/<project>, paket aktif tetap distribution/<project>.
Pertahankan layout native Experts/Indicators/Include dan relative include.

AutoFibo menggantikan myFibo dan khusus otomatis; tidak ada pilihan Manual/Auto.
Kelas model/risiko/GUI/chart/state bersama ada di Include/_common/Fibo. Pastikan perubahan
kelas bersama lolos tests/check_manualfibo.py dan tests/check_autofibo.py, serta
regresi analisis otomatis tests/check_autofibo_analysis.py.

Library custom bersama ditempatkan di Include/_common, dengan subfolder Fibo,
Swing dan Structure. Header native terminal tetap memakai path aslinya.
Saat diminta commit/push rilis, sertakan annotated tag `<NamaEA>-v<Versi>`
untuk setiap EA yang versinya berubah; beberapa tag boleh menunjuk commit sama.
Jangan memindahkan/menimpa tag yang sudah ada. Panduan: docs/releases.md.
