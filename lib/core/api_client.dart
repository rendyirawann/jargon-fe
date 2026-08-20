import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_routes.dart';
import 'config.dart';
import 'failure.dart';
import 'storage.dart';

/// Klien HTTP tunggal untuk seluruh aplikasi.
///
/// Menangani tiga hal yang kalau diserahkan ke pemanggil pasti tidak konsisten:
///
/// 1. **Kredensial.** Perangkat kios memakai `Authorization: Device <token>`,
///    sedangkan guru/kepala sekolah memakai `Bearer <jwt>`. Interceptor di
///    sini memilih yang tepat berdasarkan jenis endpoint, sehingga tidak ada
///    layar yang bisa lupa memasangnya.
/// 2. **Envelope respons.** Semua respons API berbentuk
///    `{ success, data, message }`. Klien membongkarnya sekali di sini.
/// 3. **Pesan galat.** Galat jaringan diterjemahkan ke pesan berbahasa
///    Indonesia yang layak ditampilkan di layar tablet di depan siswa.
class ApiClient {
  /// [storage] positional (bukan bernama) karena parameter bernama di Dart
  /// tidak boleh berawalan garis bawah, sehingga field privat hanya bisa
  /// diisi langsung lewat parameter posisional.
  ApiClient(this._storage, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      // Nilai awal saja. Alamat sebenarnya dipasang ulang pada tiap request
      // oleh interceptor di bawah, sehingga perubahan lewat Profil → Alamat
      // Server langsung berlaku tanpa membangun ulang klien ini.
      ..baseUrl = ApiConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 5)
      ..receiveTimeout = AppConfig.requestTimeout
      ..sendTimeout = AppConfig.requestTimeout
      ..responseType = ResponseType.json
      // Status non-2xx ditangani sebagai data, bukan exception, agar pesan
      // dari server (yang sudah berbahasa Indonesia) bisa dipakai apa adanya.
      // Tanda kurung pada lambda wajib: tanpanya, cascade berikutnya akan
      // terbaca sebagai bagian dari badan lambda.
      ..validateStatus = ((_) => true)
      ..headers['Accept'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) async {
        options.baseUrl = ApiConfig.baseUrl;

        final needsDevice = ApiRoutes.needsDeviceToken(options.path);
        final needsNone = ApiRoutes.needsNoCredential(options.path);

        if (!needsNone) {
          if (needsDevice) {
            final token = await _storage.deviceToken();
            if (token != null) {
              options.headers['Authorization'] = 'Device $token';
            }
          } else {
            final token = await _storage.accessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
        }
        handler.next(options);
      }),
    );
  }

  final Dio _dio;
  final Storage _storage;

  /// GET yang mengembalikan objek `data`.
  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _send(() => _dio.get(path, queryParameters: query));
    return _asObject(res);
  }

  /// GET yang mengembalikan senarai `data`.
  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _send(() => _dio.get(path, queryParameters: query));
    final data = _unwrap(res);
    if (data is List) return data;
    throw ApiFailure('Format respons tidak sesuai untuk $path');
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
  }) async {
    final res = await _send(() => _dio.post(path, data: body));
    return _asObject(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await _send(() => _dio.delete(path));
    return _asObject(res);
  }

  /// Kirim tanpa melempar galat — dipakai jalur yang punya fallback offline.
  ///
  /// Mengembalikan `null` bila gagal, sehingga pemanggil bisa memutuskan
  /// menyimpan ke antrean lokal alih-alih menampilkan error ke siswa.
  Future<Map<String, dynamic>?> tryPost(String path, {Object? body}) async {
    try {
      return await post(path, body: body);
    } on ApiFailure {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Pesan `message` dari server bila ada, untuk ditampilkan ke pengguna.
  static String messageOf(Map<String, dynamic> envelope) =>
      (envelope['message'] as String?) ?? '';

  /// Uji apakah sebuah alamat benar-benar melayani API ini.
  ///
  /// Dipakai layar Alamat Server SEBELUM alamat disimpan. Menyimpan alamat
  /// yang salah lalu menemukannya saat gagal login membuat pengguna mengira
  /// kata sandinya yang keliru — pesan galatnya akan menyesatkan.
  ///
  /// Sengaja memakai klien terpisah dengan batas waktu pendek: yang diuji
  /// justru alamat yang mungkin tidak ada, dan menunggu 12 detik untuk itu
  /// membuat layar terasa menggantung.
  ///
  /// Mengembalikan `null` bila alamat baik, atau alasan kegagalannya.
  static Future<String?> ping(String baseUrl) async {
    final probe = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      validateStatus: (_) => true,
    ));

    try {
      final res = await probe.get<dynamic>(ApiRoutes.health);
      final status = res.statusCode ?? 0;

      if (status >= 200 && status < 300) return null;
      if (status == 404) {
        // Ada server di alamat itu, tapi bukan API ini — biasanya karena
        // alamatnya menunjuk ke dashboard atau reverse proxy yang salah.
        return 'Alamat merespons, tetapi bukan API Jargon GO '
            '(endpoint ${ApiRoutes.health} tidak ada).';
      }
      return 'Server menjawab dengan kode $status.';
    } on DioException catch (e) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          'Server tidak merespons. Pastikan API berjalan dan perangkat berada '
              'di jaringan yang sama.',
        DioExceptionType.connectionError =>
          'Tidak dapat menghubungi $baseUrl.',
        DioExceptionType.badCertificate =>
          'Sertifikat HTTPS server tidak valid.',
        _ => 'Gagal menghubungi server: ${e.message ?? 'tidak diketahui'}',
      };
    } catch (e) {
      return 'Gagal menghubungi server: $e';
    } finally {
      probe.close(force: true);
    }
  }

  // ---------------------------------------------------------------

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiFailure(_describe(e), isNetwork: true);
    }
  }

  Map<String, dynamic> _asObject(Response<dynamic> res) {
    final data = _unwrap(res);
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw ApiFailure('Format respons tidak sesuai');
  }

  /// Bongkar envelope dan ubah status galat menjadi [ApiFailure].
  dynamic _unwrap(Response<dynamic> res) {
    final status = res.statusCode ?? 0;
    final body = res.data;

    Map<String, dynamic>? map;
    if (body is Map<String, dynamic>) {
      map = body;
    } else if (body is String && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) map = decoded;
      } catch (_) {
        // Bukan JSON — kemungkinan halaman galat dari reverse proxy.
      }
    }

    if (status >= 200 && status < 300) {
      if (map == null) return body;
      return map.containsKey('data') ? map['data'] : map;
    }

    final message = map?['message'] as String? ?? _statusMessage(status);
    final fields = <String, String>{};
    for (final err in (map?['errors'] as List<dynamic>? ?? const [])) {
      if (err is Map && err['field'] != null && err['message'] != null) {
        fields[err['field'].toString()] = err['message'].toString();
      }
    }

    throw ApiFailure(
      message,
      statusCode: status,
      code: map?['code'] as String?,
      fieldErrors: fields,
    );
  }

  String _statusMessage(int status) => switch (status) {
        401 => 'Sesi tidak berlaku. Perangkat perlu dipasangkan ulang.',
        403 => 'Akses ditolak untuk perangkat/akun ini.',
        404 => 'Data tidak ditemukan di server.',
        409 => 'Data bertentangan dengan yang sudah ada.',
        422 => 'Data yang dikirim tidak valid.',
        429 => 'Terlalu banyak permintaan. Tunggu sebentar.',
        >= 500 => 'Server sedang bermasalah. Coba beberapa saat lagi.',
        _ => 'Permintaan gagal (kode $status).',
      };

  String _describe(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout =>
          'Server tidak merespons. Periksa koneksi jaringan sekolah.',
        DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout =>
          'Koneksi terlalu lambat. Data disimpan sementara di perangkat.',
        DioExceptionType.connectionError =>
          'Tidak dapat menghubungi server. Absensi akan disinkronkan otomatis '
              'setelah jaringan kembali.',
        DioExceptionType.badCertificate =>
          'Sertifikat server tidak valid. Hubungi administrator.',
        DioExceptionType.cancel => 'Permintaan dibatalkan.',
        _ => 'Gangguan jaringan: ${e.message ?? 'tidak diketahui'}',
      };
}
