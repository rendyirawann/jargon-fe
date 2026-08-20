import 'package:flutter/foundation.dart';

import 'config.dart';
import 'storage.dart';

/// Alamat server API yang sedang dipakai.
///
/// MENGAPA BISA DIUBAH SAAT BERJALAN
///
/// `--dart-define=API_BASE_URL=...` hanya berlaku saat build. Selama
/// pengembangan, alamat server berubah berkali-kali dalam sehari: hari ini
/// `localhost`, besok IP laptop di jaringan sekolah, lusa domain staging.
/// Membangun ulang APK setiap kali alamatnya berganti membuat pengujian
/// lapangan jauh lebih lambat daripada perlunya.
///
/// Karena itu nilai dari `--dart-define` diperlakukan sebagai **nilai awal**,
/// dan pengguna dapat menimpanya lewat Profil → Alamat Server. Pilihan itu
/// tersimpan di perangkat dan dipakai sampai diubah lagi atau dikembalikan ke
/// bawaan.
///
/// Di rilis produksi, biarkan pengguna tidak pernah membuka layar itu:
/// nilai `--dart-define` saat build sudah menunjuk ke server yang benar.
class ApiConfig {
  const ApiConfig._();

  static String _baseUrl = defaultBaseUrl;

  /// Alamat yang sedang aktif. Dibaca ulang pada SETIAP request, sehingga
  /// perubahan langsung berlaku tanpa perlu membangun ulang klien HTTP.
  static String get baseUrl => _baseUrl;

  /// True bila alamat aktif berbeda dari bawaan build.
  static bool get isOverridden => _baseUrl != defaultBaseUrl;

  /// Alamat bawaan, bergantung tempat aplikasi berjalan.
  ///
  /// Nilai `--dart-define=API_BASE_URL` selalu menang bila diisi. Bila tidak,
  /// bawaannya dipilih per platform karena "localhost" berarti mesin yang
  /// berbeda di masing-masing tempat:
  ///
  /// * **Web (debug di browser)** — mesin yang sama dengan yang menjalankan
  ///   API, jadi `127.0.0.1` bisa dipakai apa adanya.
  /// * **Emulator Android** — `127.0.0.1` adalah emulatornya sendiri; mesin
  ///   pengembang dijangkau lewat alamat khusus `10.0.2.2`.
  /// * **Perangkat fisik** — tidak ada bawaan yang bisa benar; isi lewat
  ///   Profil → Alamat Server dengan IP laptop di jaringan yang sama
  ///   (mis. `http://192.168.1.10:8080`).
  ///
  /// `127.0.0.1` dipilih, bukan `localhost`, agar cocok dengan alamat yang
  /// dibuka di browser. Keduanya menunjuk mesin yang sama, tetapi bagi CORS
  /// **keduanya origin yang berbeda** — halaman di `127.0.0.1:5000` yang
  /// memanggil `localhost:8080` adalah permintaan lintas origin.
  static String get defaultBaseUrl {
    // Build container: aplikasi dan API dilayani nginx yang sama, jadi
    // alamat API adalah origin halaman itu sendiri. Ini yang membuat image
    // bisa dijalankan di mesin mana pun — dibuka lewat localhost, IP LAN,
    // atau nama domain, semuanya bekerja tanpa membangun ulang. Alamat yang
    // dipaku saat build hanya benar di satu mesin.
    if (kIsWeb && sameOrigin) return Uri.base.origin;

    const fromBuild = AppConfig.apiBaseUrl;
    if (fromBuild.isNotEmpty) return fromBuild;

    // Build release tanpa --dart-define menunjuk ke server produksi.
    //
    // Alasannya praktis: APK release yang bawaannya `10.0.2.2` sama sekali
    // tidak berguna di tangan pengguna — alamat itu hanya berarti sesuatu
    // di dalam emulator Android. Satu `--dart-define` yang terlupa cukup
    // untuk menghasilkan APK yang tidak bisa login sama sekali, dan
    // gejalanya ("tidak dapat menghubungi server") tidak menunjuk ke
    // penyebabnya.
    if (kReleaseMode) return AppConfig.productionApiBaseUrl;

    return kIsWeb ? 'http://127.0.0.1:8080' : 'http://10.0.2.2:8080';
  }

  /// Diaktifkan build container lewat `--dart-define=API_SAME_ORIGIN=true`.
  ///
  /// Dipisahkan dari `API_BASE_URL` kosong karena keduanya tidak dapat
  /// dibedakan: define yang tidak diisi dan define yang diisi string kosong
  /// sama-sama menghasilkan `''`. Bendera tersendiri membuat maksudnya
  /// terbaca di `docker-compose.yml` maupun di sini.
  static const bool sameOrigin = bool.fromEnvironment('API_SAME_ORIGIN');

  /// Muat pilihan yang tersimpan. Dipanggil sekali di `main()` sebelum
  /// aplikasi berjalan, agar request pertama pun sudah memakai alamat benar.
  static void load(Storage storage) {
    final saved = storage.apiBaseUrl();
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
    }
  }

  /// Simpan alamat baru dan pakai mulai request berikutnya.
  static Future<void> save(Storage storage, String url) async {
    final normalized = normalize(url);
    _baseUrl = normalized;
    await storage.saveApiBaseUrl(normalized);
  }

  /// Kembali ke bawaan build.
  static Future<void> reset(Storage storage) async {
    _baseUrl = defaultBaseUrl;
    await storage.clearApiBaseUrl();
  }

  /// Rapikan masukan pengguna menjadi alamat yang bisa dipakai.
  ///
  /// Menerima `192.168.1.10:8080` (tanpa skema) karena itu yang biasa dibaca
  /// orang dari `ipconfig`, dan membuang garis miring di ujung supaya
  /// penggabungan dengan path tidak menghasilkan `//v1/...`.
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return defaultBaseUrl;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  /// Alasan alamat ditolak, atau `null` bila sudah benar.
  static String? validationError(String input) {
    final url = normalize(input);
    final uri = Uri.tryParse(url);

    if (uri == null || uri.host.isEmpty) {
      return 'Alamat tidak dikenali. Contoh: http://192.168.1.10:8080';
    }
    if (uri.hasQuery || uri.hasFragment) {
      return 'Alamat tidak boleh memuat tanda tanya atau pagar.';
    }

    // AWALAN PATH DIIZINKAN.
    //
    // Sebelumnya path apa pun ditolak, dengan alasan akan bertabrakan
    // dengan path endpoint. Itu terlalu keras: backend yang dipasang di
    // subpath sebuah domain — mis. https://contoh.id/jargon-be — adalah
    // pemasangan yang wajar, dan alamatnya memang harus memuat awalan itu.
    //
    // Dio menggabungkan baseUrl dengan path endpoint sebagai teks, jadi
    // `https://contoh.id/jargon-be` + `/v1/auth/login` menghasilkan
    // `https://contoh.id/jargon-be/v1/auth/login` — benar.
    //
    // Yang tetap ditolak hanya awalan yang SUDAH memuat versi API, karena
    // itu kekeliruan yang sesungguhnya: hasilnya `/v1/v1/...`, dan 404
    // yang muncul sangat sulit ditelusuri dari sisi pengguna.
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'v1') {
      return 'Jangan sertakan /v1 — itu ditambahkan aplikasi.';
    }

    return null;
  }
}
