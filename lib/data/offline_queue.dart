import 'offline_queue_memory.dart'
    if (dart.library.io) 'offline_queue_sqflite.dart';

/// Antrean absensi lokal untuk saat jaringan sekolah terputus.
///
/// MENGAPA INI ADA
///
/// Banyak sekolah di Sumatera Utara berada di daerah dengan jaringan yang
/// tidak stabil. Kalau tablet menolak absen ketika jaringan mati, siswa yang
/// sudah datang akan tercatat alfa dan orang tuanya menerima notifikasi yang
/// salah. Karena itu pemindaian yang gagal terkirim disimpan di sini dan
/// dikirim ulang otomatis.
///
/// APA YANG DISIMPAN
///
/// Hanya embedding (vektor), waktu tangkap, dan skor liveness — tidak ada
/// gambar. Baris dihapus segera setelah server menerimanya, sehingga vektor
/// biometrik tidak menumpuk di perangkat yang dipasang di ruang publik.
///
/// DUA IMPLEMENTASI
///
/// Di Android/iOS antreannya SQLite lewat `sqflite`, sehingga bertahan meski
/// tablet dimatikan semalaman. `sqflite` tidak berjalan di web, sedangkan
/// debug di browser tetap perlu bisa dijalankan — jadi versi web memakai
/// penyimpanan dalam memori yang hilang saat halaman dimuat ulang.
///
/// Kehilangan itu tidak menjadi masalah, karena absensi wajah memang tidak
/// dijalankan dari browser: mode kios butuh kamera, TFLite, dan ML Kit yang
/// semuanya hanya ada di perangkat. Debug web dipakai untuk menu Jargon GO
/// (absensi pantau, Panic Button, pemberkasan), yang tidak menyentuh antrean
/// ini sama sekali.
abstract class OfflineQueue {
  /// Batas umur antrean. Absensi yang tertahan lebih lama dari ini tidak lagi
  /// bisa dipertanggungjawabkan sebagai jam kedatangan, jadi lebih baik
  /// dibuang dan dikoreksi manual oleh guru.
  static const Duration maxAge = Duration(hours: 18);

  /// Batas jumlah baris agar penyimpanan tablet tidak habis bila jaringan
  /// mati berhari-hari.
  static const int maxRows = 5000;

  static Future<OfflineQueue> open() => openOfflineQueue();

  Future<void> close();

  /// Simpan satu pemindaian yang gagal terkirim.
  Future<void> enqueue(Map<String, dynamic> payload);

  /// Ambil batch tertua untuk dicoba kirim.
  ///
  /// Urutan tertua-dulu penting: jam masuk siswa harus tercatat sesuai
  /// urutan kedatangan sebenarnya.
  Future<List<PendingScan>> take({int limit});

  Future<void> remove(int id);

  Future<void> markFailed(int id, String error);

  Future<int> count();

  /// Buang baris kedaluwarsa dan yang melebihi kapasitas.
  ///
  /// Mengembalikan jumlah baris yang dibuang, supaya bisa dilaporkan ke
  /// operator alih-alih hilang tanpa jejak.
  Future<int> purgeStale();
}

class PendingScan {
  const PendingScan({
    required this.id,
    required this.payload,
    required this.capturedAt,
    required this.attempts,
  });

  final int id;
  final Map<String, dynamic> payload;
  final DateTime capturedAt;
  final int attempts;

  /// Sudah terlalu sering gagal — kemungkinan payload-nya sendiri bermasalah
  /// (mis. versi model tidak cocok), bukan jaringannya.
  bool get isExhausted => attempts >= 8;
}
