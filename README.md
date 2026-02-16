<p align="center">
  <img src="assets/icon.png" width="120" alt="Sakinime Logo">
</p>

# Sakinime 

> [!WARNING]
> **Status: Still in Development (Alpha)**
> Proyek ini masih dalam tahap pengembangan awal. Gunakan dengan bijak karena **masih banyak perbaikan** dan perubahan besar yang akan datang.

**Sakinime** adalah aplikasi streaming anime lintas platform kelas dunia yang dibangun menggunakan **Flutter**. Dirancang khusus untuk memberikan pengalaman menonton yang *immersive*, elegan, dan bertenaga AI dengan integrasi sistem yang mendalam, terutama pada platform Windows.

---

## ✨ Mengapa Sakinime?

Berbeda dengan aplikasi streaming anime biasa, Sakinime menggabungkan performa *native* dengan antarmuka yang sangat dipoles (*highly polished UI*), menjadikannya pilihan utama bagi penggemar anime yang menginginkan kualitas tinggi tanpa kompromi.

### 📺 Pengalaman Menonton Tingkat Lanjut
- **Native Video Engine**: Menggunakan **Media Kit**, engine berbasis C++ yang memberikan pemutaran video 4K yang sangat lancar dengan penggunaan CPU yang minimal.
- **Dynamic Resolution Switching**: Pilih resolusi terbaik (360p ke 1080p/4K) secara instan.
- **Synchronized Metadata (SyncData)**: Sinkronisasi progres menonton dan status episode secara lokal dan akurat.
- **Multi-Server Bridge**: Koneksi cerdas ke berbagai server streaming untuk menghindari video yang macet atau *down*.

### 🤖 Kecerdasan Buatan (AI) & Subtitle
- **Multiple Translation Engines**: Dukungan untuk Google Translate, LibreTranslate, dan MyMemory sebagai *fallback*.
- **Sub-Style Control**: Kustomisasi penuh tampilan subtitle mulai dari font, bayangan, hingga posisi offset.

### 🪟 Eksklusivitas Windows (Optimized)
- **Native SMTC**: Kontrol media penuh (Play, Pause, Seek, Next) yang terintegrasi dengan Windows Media Overlay dan tombol fungsi keyboard (Coming soon).
- **Glassmorphism & Frameless UI**: Antarmuka modern yang borderless dengan efek transparansi yang elegan.
- **Taskbar Media Controller**: Monitor progres video dan ganti episode langsung dari icon taskbar Windows (Development).

### 🍱 Konten & Manajemen
- **Smart Bookmark**: Simpan anime favoritmu secara lokal dengan akses instan (Development).
- **Advanced Metadata Detail**: Informasi mendalam mulai dari daftar seiyuu (pengisi suara), studio produksi, hingga status rilis.
- **Batch Viewing**: Dukungan untuk melihat daftar episode dalam format *batch* untuk mempermudah pengalaman menonton maraton/binge-watching.
- **News & Schedule**: Berita anime terbaru dan jadwal rilis yang diperbarui setiap saat (Development).

---

## 🎨 Design System

Sakinime menggunakan palet warna yang dikurasi untuk kenyamanan mata dan estetika premium:
- **Primary Accent**: `#F59E0B` (Amber) - Menandakan energi dan kefokusan.
- **Deep Background**: `#0A0A0F` - Memberikan kontras hitam yang sempurna untuk layar OLED.
- **Premium Cards**: Efek gradien dan blur transparan untuk kedalaman visual.
- **Motion Design**: Didukung oleh mesin **Lottie** untuk animasi pemuatan (*loading*) dan percikan (*splash*) yang halus.

---

## 🛠️ Technical Insights

- **State Management**: Implementasi kustom menggunakan **Provider** untuk reaktivitas data yang efisien.
- **Networking Layer**: Menggunakan **Dio** dengan interceptor kustom untuk penanganan error dan mekanisme *safe-retry*.
- **API Architecture**: Komunikasi *real-time* dengan scraper kustom `hianime-api` v2.0.0.
- **Scraping logic**: Penanganan cerdas untuk ekstraksi URL video dan enkripsi data server.

---

## 📁 Strukturfolder & Arsitektur

```text
lib/
├── config/       # AI Config & Konstanta Sistem
├── models/       # POJO/Data Models dengan perampingan JSON
├── providers/    # Logika state Global Player & Anime Data
├── screens/      # Implementasi UI (WatchScreen, Detail, Home, dll)
├── services/     # Engine Utama (TranslateService, AnimeService, Bookmark)
├── utils/        # Alat bantu format teks & penangan waktu
└── widgets/      # Koleksi komponen UI atomik & reusable
```

---

## 🏗️ Persiapan & Instalasi

### Prasyarat
- Flutter SDK v3.x atau lebih baru.
- Windows 10/11 (Direkomendasikan) atau Android 8.0+.

### Langkah-langkah
1. Clone repository ini.
2. Jalankan `flutter pub get`.
3. Gunakan `flutter run` untuk meluncurkan di emulator atau perangkat fisik.

---

## 🛤️ Roadmap Masa Depan
- [ ] **High-Speed Offline Downloader**: Unduh episode favorit dengan dukungan *multi-threaded*.
- [ ] **Manga Reader Integrated**: Baca manga langsung dari tab yang berbeda.
- [ ] **Cloud Sync**: Sinkronisasi data antar perangkat menggunakan Firebase Cloud.

---

## 📜 Lisensi & Etika
Proyek ini dibuat untuk tujuan pembelajaran dan portofolio.
- Kode berlisensi di bawah **MIT License**.
- Konten disediakan oleh pihak ketiga; pengguna diharapkan bijak dalam mengonsumsi konten.

---

## ❤️ Apresiasi
- Seluruh komunitas Flutter yang menyediakan package berkualitas tinggi.
