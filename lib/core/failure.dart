/// Galat yang berasal dari API atau jaringan.
///
/// Pesannya sengaja siap-tampil dalam bahasa Indonesia: layar kios berada di
/// depan siswa, dan menampilkan jargon teknis di sana tidak membantu siapa pun.
class ApiFailure implements Exception {
  ApiFailure(
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
    this.isNetwork = false,
  });

  final String message;
  final int? statusCode;

  /// Kode mesin dari server, mis. `validation_error`, `not_found`.
  final String? code;

  /// Galat per field untuk menandai input pada form.
  final Map<String, String> fieldErrors;

  /// `true` bila kegagalan terjadi sebelum server sempat menjawab —
  /// penanda bahwa data layak disimpan ke antrean offline.
  final bool isNetwork;

  /// Perangkat perlu dipasangkan ulang (token dicabut / tidak dikenal).
  bool get needsRepair => statusCode == 401;

  /// Layak dicoba lagi nanti. Galat validasi tidak akan berubah walau
  /// dikirim ulang, jadi tidak termasuk.
  bool get isRetryable =>
      isNetwork || statusCode == null || statusCode! >= 500 || statusCode == 429;

  /// Gagal karena KREDENSIAL, bukan karena isi payload.
  ///
  /// Dipisahkan dari [isRetryable] karena keduanya menuntut perlakuan yang
  /// berbeda terhadap antrean absensi: payload yang ditolak aturan memang
  /// tidak berguna disimpan, tetapi payload yang ditolak karena token
  /// perangkat mati **masih sah** dan akan diterima begitu perangkat
  /// dipasangkan ulang.
  ///
  /// Menyamakan keduanya berarti satu token perangkat yang kedaluwarsa
  /// menghapus seluruh absensi pagi yang belum terkirim — data milik sekolah,
  /// hilang tanpa jejak di layar mana pun.
  bool get isCredentialProblem => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Galat pada pemrosesan wajah di perangkat (kamera, model, kualitas citra).
class FaceFailure implements Exception {
  FaceFailure(this.message, {this.isFatal = false});

  final String message;

  /// `true` bila tidak akan pulih tanpa campur tangan (model hilang, kamera
  /// tidak ada izin) — layar harus menampilkan instruksi, bukan mencoba lagi.
  final bool isFatal;

  @override
  String toString() => message;
}
