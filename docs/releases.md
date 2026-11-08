# Commit dan tag rilis

Satu repositori menyimpan beberapa EA. Gunakan annotated tag dengan pola
`<NamaEA>-v<Versi>` untuk menandai commit rilis setiap EA. Versi mengikuti
`#property version`, README dan INSTALL. Beberapa tag boleh menunjuk commit yang
sama jika perubahan bersama dirilis untuk beberapa EA.

Untuk perubahan library bersama di Include/_common, periksa EA yang terdampak,
sesuaikan versi dan jalankan runner serta check_inputs() builder sebelum commit.
ZIP hanya dibuat jika diminta. F7 dan rendering tetap perlu diperiksa di Windows.

Contoh untuk rilis pemindahan library bersama:

```bash
git add AGENTS.md README.md Experts/AutoFibo Experts/manualFibo Include docs tests tools/package_autofibo.py tools/package_manualfibo.py distribution/AutoFibo/INSTALL.txt distribution/manualFibo/INSTALL.txt
git commit -m "Move shared MQL5 libraries into Include/_common"
git tag -a AutoFibo-v3.02 -m "AutoFibo 3.02: shared library folder"
git tag -a manualFibo-v1.15 -m "manualFibo 1.15: shared library folder"
git push origin main
git push origin AutoFibo-v3.02 manualFibo-v1.15
```

Ganti nama/versi sesuai rilis berikutnya. Commit biasa tetap memiliki hash unik;
buat tag rilis baru ketika versi berubah. Periksa tag yang ada dengan `git tag
--list` dan jangan menimpa tag rilis lama. Saat diminta commit/push rilis,
sertakan pembuatan dan push tag untuk EA yang versinya berubah.
