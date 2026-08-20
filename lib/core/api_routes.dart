/// Daftar terpusat seluruh alamat API yang dipanggil aplikasi.
///
/// MENGAPA SEMUA DI SATU BERKAS
///
/// Sebelumnya path ditulis langsung di tempat pemanggilan
/// (`_api.post('/v1/panic/reports')`). Selama endpoint tidak pernah berubah
/// itu terasa lebih ringkas — tetapi begitu server mengubah satu path atau
/// menaikkan versi, perubahannya tersebar di puluhan baris di beberapa berkas,
/// dan yang terlewat baru ketahuan sebagai galat 404 di tangan pengguna.
///
/// Di sini, satu perubahan cukup diedit di satu tempat. [prefix] bahkan
/// membuat kenaikan versi API (`/v1` → `/v2`) menjadi satu baris.
///
/// Alamat SERVER-nya (protokol + host + port) tidak ada di sini — itu
/// [ApiConfig.baseUrl], yang bisa diubah saat aplikasi berjalan lewat
/// Profil → Alamat Server.
library;

class ApiRoutes {
  const ApiRoutes._();

  /// Awalan versi API. Ubah di sini bila server naik versi.
  static const String prefix = '/v1';

  // =================================================================
  // Kesehatan server (tanpa autentikasi)
  // =================================================================

  /// Dipakai layar Alamat Server untuk menguji koneksi sebelum disimpan.
  static const String health = '/health';

  // =================================================================
  // Autentikasi
  // =================================================================

  static const String login = '$prefix/auth/login';
  static const String logout = '$prefix/auth/logout';
  static const String refresh = '$prefix/auth/refresh';

  // =================================================================
  // Jargon GO — data milik pengguna
  // =================================================================

  static const String home = '$prefix/me/home';
  static const String myAttendance = '$prefix/me/attendance';

  static String myRecap(String studentId) =>
      '$prefix/me/attendance/$studentId/recap';

  // =================================================================
  // Absensi (pemantauan guru & kepala sekolah)
  // =================================================================

  static const String attendances = '$prefix/attendances';
  static const String attendanceSummary = '$prefix/attendances/summary';
  static const String attendanceByClassroom = '$prefix/attendances/by-classroom';
  static const String attendanceManual = '$prefix/attendances/manual';

  // =================================================================
  // Panic Button
  // =================================================================

  static const String panicCategories = '$prefix/panic/categories';
  static const String panicReports = '$prefix/panic/reports';

  static String panicReport(String id) => '$panicReports/$id';

  static String panicSupport(String id) => '$panicReports/$id/support';

  static String panicComments(String id) => '$panicReports/$id/comments';

  // =================================================================
  // Pemberkasan
  // =================================================================

  static const String documentTypes = '$prefix/documents/types';
  static const String submissions = '$prefix/documents/submissions';

  static String submission(String id) => '$submissions/$id';

  static String submissionFiles(String id) => '$submissions/$id/files';

  static String submitSubmission(String id) => '$submissions/$id/submit';

  static String documentFile(String fileId) => '$prefix/documents/files/$fileId';

  // =================================================================
  // Perangkat kios (tablet sekolah)
  // =================================================================

  static const String devicePair = '$prefix/devices/pair';
  static const String kioskRecognize = '$prefix/kiosk/recognize';
  static const String kioskHeartbeat = '$prefix/kiosk/heartbeat';
  static const String kioskRoster = '$prefix/kiosk/roster';

  static String kioskEnrollFace(String studentId) =>
      '$prefix/kiosk/students/$studentId/face';

  // =================================================================
  // Aturan kredensial per endpoint
  //
  // Ditaruh di sini, bukan di ApiClient, supaya menambah endpoint baru
  // berarti melihat aturan kredensialnya pada saat yang sama. Salah
  // kredensial menghasilkan 401 yang membingungkan: token ADA, hanya
  // jenisnya yang keliru.
  // =================================================================

  /// Endpoint yang memakai `Authorization: Device <token>` (tablet kios).
  static bool needsDeviceToken(String path) => path.startsWith('$prefix/kiosk');

  /// Endpoint yang tidak boleh membawa kredensial sama sekali.
  ///
  /// `devices/pair` dan `auth/login` justru sedang MEMINTA kredensial, dan
  /// `/health` dipanggil layar Alamat Server sebelum ada sesi.
  static bool needsNoCredential(String path) =>
      path.startsWith(devicePair) ||
      path.startsWith(login) ||
      path.startsWith(health);
}
