/// Konfigurasi aplikasi.
///
/// Nilai diambil dari `--dart-define` saat build sehingga satu kode sumber
/// bisa dipakai untuk lingkungan uji dan produksi tanpa mengubah file:
///
/// ```
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://absensi.disdik.sumutprov.go.id \
///   --dart-define=FACE_MODEL_VERSION=mobilefacenet-v1
/// ```
library;

class AppConfig {
  const AppConfig._();

  /// Alamat dasar API dari `--dart-define`.
  ///
  /// Sengaja KOSONG bila tidak diisi saat build, bukan diberi nilai bawaan di
  /// sini. Bawaan yang benar berbeda per platform — `127.0.0.1` di browser,
  /// `10.0.2.2` di emulator Android — dan itu diputuskan
  /// [ApiConfig.defaultBaseUrl]. Menaruh nilai bawaan di sini membuat cabang
  /// per-platform di sana tidak pernah tercapai.
  ///
  /// Gunakan [ApiConfig.baseUrl], bukan nilai ini: pengguna dapat menimpanya
  /// saat aplikasi berjalan lewat layar Alamat Server.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Alamat server produksi.
  ///
  /// Dipakai sebagai bawaan pada build **release** bila `API_BASE_URL`
  /// tidak diisi — sehingga `flutter build apk --release` menghasilkan APK
  /// yang langsung menunjuk ke server sebenarnya, tanpa perlu mengingat
  /// satu baris `--dart-define` setiap kali.
  ///
  /// Memuat AWALAN PATH `/jargon-be` karena backend dipasang di subpath
  /// domain itu, bukan di akarnya. Path endpoint disambung sesudahnya, jadi
  /// hasil akhirnya `https://beoulve-dev.biz.id/jargon-be/v1/...`.
  ///
  /// Tanpa garis miring di ujung: penggabungan dengan path endpoint akan
  /// menghasilkan `//v1/...`, yang pada sebagian reverse proxy menjadi 404.
  static const String productionApiBaseUrl =
      'https://beoulve-dev.biz.id/jargon-be';

  /// Versi model embedding pada perangkat.
  ///
  /// WAJIB sama dengan `FACE_MODEL_VERSION` di server. Embedding dari versi
  /// model berbeda tidak sebanding — mencocokkannya menghasilkan identifikasi
  /// acak, dan karena itu server menolak request yang versinya tidak cocok.
  static const String faceModelVersion = String.fromEnvironment(
    'FACE_MODEL_VERSION',
    defaultValue: 'mobilefacenet-v1',
  );

  /// Dimensi vektor embedding (MobileFaceNet = 512).
  static const int embeddingDim = int.fromEnvironment(
    'FACE_EMBEDDING_DIM',
    defaultValue: 512,
  );

  /// Ukuran input model, sisi persegi dalam piksel.
  static const int modelInputSize = int.fromEnvironment(
    'FACE_MODEL_INPUT',
    defaultValue: 112,
  );

  /// Berkas model TFLite di dalam assets.
  static const String modelAsset = 'assets/models/mobilefacenet.tflite';

  /// Jeda minimum antara dua scan siswa yang sama pada perangkat ini.
  ///
  /// Ini penjaga sisi klien agar antrean pagi tidak membanjiri server dengan
  /// pemindaian berulang atas orang yang sama; server punya penjaganya sendiri.
  static const Duration scanCooldown = Duration(seconds: 8);

  /// Interval heartbeat ke server.
  static const Duration heartbeatInterval = Duration(minutes: 2);

  /// Seberapa sering antrean offline dicoba dikirim ulang.
  static const Duration syncInterval = Duration(seconds: 30);

  /// Batas waktu request. Dibuat pendek untuk jalur absensi: tablet lebih
  /// baik menyimpan ke antrean lokal daripada menahan siswa di depan kamera.
  static const Duration requestTimeout = Duration(seconds: 12);

  /// Skor liveness minimum sebelum embedding dikirim.
  static const double minLiveness = 0.5;

  /// Lebar minimum wajah (relatif terhadap lebar frame) agar dianggap cukup
  /// dekat ke kamera. Wajah terlalu kecil menghasilkan embedding buruk.
  static const double minFaceWidthRatio = 0.22;

  /// Sudut kepala maksimum (derajat) yang masih diterima untuk absensi.
  static const double maxHeadAngle = 22.0;

  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
