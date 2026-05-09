# Pubel (Pusat Berbagi Lokal) 🚀

**Pubel** adalah aplikasi berbagi file lintas platform yang memungkinkan Anda mengirim file dari smartphone ke PC (dan sebaliknya) melalui jaringan lokal menggunakan browser. Terinspirasi oleh aplikasi seperti Xender, Pubel fokus pada kemudahan akses tanpa perlu menginstal software tambahan di PC.

![Pubel Design Mockup](https://raw.githubusercontent.com/mrscriptword/Pubel/main/design_preview.png)

## ✨ Fitur Utama

- **Berbagi via Browser**: Cukup buka alamat IP yang tertera di aplikasi pada browser PC Anda untuk mulai mengunduh/mengunggah file.
- **Kecepatan Tinggi**: Menggunakan protokol jaringan lokal untuk transfer data maksimal.
- **Manajer File Terintegrasi**: Kategorisasi otomatis untuk Foto, Video, Musik, dan Dokumen.
- **Antarmuka Modern**: Desain yang elegan, responsif, dan mudah digunakan.

## 🛠️ Teknologi yang Digunakan

- **Flutter**: Untuk pengembangan aplikasi mobile lintas platform.
- **Shelf & Shelf Router**: Untuk menjalankan HTTP server lokal di perangkat mobile.
- **Network Info Plus**: Untuk mendeteksi alamat IP jaringan WiFi.
- **GitHub Actions**: Untuk build APK otomatis secara cloud.

## 🚀 Cara Menjalankan

### Menggunakan Project IDX / Firebase Studio (Tanpa Install SDK)
1. Import repositori ini ke [Project IDX](https://idx.dev/).
2. Project akan otomatis terkonfigurasi menggunakan Nix.
3. Jalankan preview Android atau Web langsung di browser.

### Menjalankan Lokal (Memerlukan Flutter SDK)
1. Clone repositori ini: `git clone https://github.com/mrscriptword/Pubel.git`
2. Masuk ke direktori: `cd pubel` (atau `share_drop`)
3. Install dependensi: `flutter pub get`
4. Jalankan aplikasi: `flutter run`

## 📦 Build APK
Anda dapat mengunduh APK terbaru dari tab **Actions** di repositori GitHub ini setelah proses build selesai.

## 📄 Lisensi
Proyek ini dilisensikan di bawah MIT License.
