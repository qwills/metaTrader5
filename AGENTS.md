# Workspace MQL5

Untuk pekerjaan Standard Library, baca `docs/reference/standard-library-guide.md`
lebih dahulu. Gunakan manual PDF/CHM lokal jika tersedia dan header native terminal
sebagai acuan signature build pengguna. Jangan berulang kali browsing untuk API
yang sudah tercakup; cari dokumentasi resmi bila referensi lokal kurang atau perlu
memastikan perubahan/perilaku versi terbaru.

Source custom ada di Experts, Include, Scripts. Standard Library terminal tidak
dibundel. Include bersama memakai `<...>`; header saudara memakai `"..."`.

Validasi perubahan myFibo dengan runner yang relevan di tests dan
`python3 tools/package_myfibo.py`, kemudian `--check`. Sesuaikan versi EA, README,
dan INSTALL. Perbarui daftar payload builder bila menambah file; CMD menyalin
seluruh isi folder MQL5 dari ZIP.
Runner adapter C++ bukan compiler MQL5: laporkan bahwa F7 dan rendering GUI perlu
diuji pengguna di Windows. Pertahankan CRLF pada CMD Windows.

Preferensi pengguna: installer/build CMD Windows langsung menimpa file paket,
tanpa membuat backup. Jangan menambahkan kembali backup atau restore otomatis
file instalasi. Preferensi ini tidak menghapus arsip rilis lokal yang sudah ada.

Installer Windows cukup ekstrak ZIP dan copy/overwrite isi folder MQL5. Jangan
menambahkan manifest.json atau pemeriksaan hash/versi pada installer.
