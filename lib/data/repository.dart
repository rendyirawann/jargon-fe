import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';

import '../core/api_client.dart';
import '../core/api_routes.dart';
import '../core/config.dart';
import '../core/failure.dart';
import '../core/storage.dart';
import 'jargon_models.dart';
import 'models.dart';
import 'offline_queue.dart';

/// Satu-satunya pintu ke API. Layar tidak pernah memanggil [ApiClient]
/// langsung, sehingga aturan seperti "pemindaian yang gagal masuk antrean"
/// tidak bisa terlewat di salah satu layar.
class AbsensiRepository {
  /// Dependensi bersifat posisional: parameter bernama di Dart tidak boleh
  /// berawalan garis bawah, sehingga field privat hanya bisa diisi langsung
  /// lewat parameter posisional.
  AbsensiRepository(this._api, this._storage, this._queue);

  final ApiClient _api;
  final Storage _storage;
  final OfflineQueue _queue;

  final Random _random = Random.secure();

  // =================================================================
  // Pairing perangkat
  // =================================================================

  /// Tukar kode pairing 8 digit dengan device token permanen.
  Future<PairResult> pairDevice(String pairingCode) async {
    final info = await _deviceDescription();

    final data = await _api.post(ApiRoutes.devicePair, body: {
      'pairing_code': pairingCode.trim(),
      'app_version': '1.0.0',
      'os_version': info.$1,
      'hardware_id': info.$2,
    });

    final result = PairResult.fromJson(data);

    // Versi model di perangkat harus sama dengan yang dipakai server;
    // kalau tidak, embedding tidak sebanding dan pengenalan menjadi acak.
    if (result.config.modelVersion != AppConfig.faceModelVersion) {
      throw ApiFailure(
        'Versi model di aplikasi (${AppConfig.faceModelVersion}) berbeda '
        'dengan server (${result.config.modelVersion}). Perbarui aplikasi '
        'sebelum memasangkan perangkat.',
      );
    }
    if (result.config.embeddingDim != AppConfig.embeddingDim) {
      throw ApiFailure(
        'Dimensi model tidak cocok: aplikasi ${AppConfig.embeddingDim}, '
        'server ${result.config.embeddingDim}.',
      );
    }

    await _storage.saveDeviceCredentials(
      token: result.deviceToken,
      hmacSecret: result.hmacSecret,
    );
    await _storage.saveDeviceProfile(result.toProfileJson());

    return result;
  }

  Future<(String, String)> _deviceDescription() async {
    try {
      final plugin = DeviceInfoPlugin();
      final android = await plugin.androidInfo;
      return (
        'Android ${android.version.release} (SDK ${android.version.sdkInt})',
        '${android.manufacturer} ${android.model} / ${android.id}',
      );
    } catch (_) {
      // iOS atau platform lain; identitas perangkat bersifat opsional.
      return ('tidak diketahui', 'tidak diketahui');
    }
  }

  // =================================================================
  // Absensi
  // =================================================================

  /// Kirim satu pemindaian wajah.
  ///
  /// Bila jaringan gagal, pemindaian TIDAK dianggap gagal: ia masuk antrean
  /// lokal dan siswa diberi tahu bahwa absennya tersimpan. Kegagalan yang
  /// bersifat penolakan aturan (di luar jam, wajah tak dikenal) tetap
  /// dikembalikan apa adanya karena mengirim ulangnya tidak akan mengubah apa
  /// pun.
  Future<RecognizeResult> recognize({
    required Float32List embedding,
    required double liveness,
    String? classroomId,
    String? direction,
  }) async {
    final payload = <String, dynamic>{
      'embedding': embedding.toList(),
      'model_version': AppConfig.faceModelVersion,
      'liveness_score': liveness,
      'client_time': DateTime.now().toUtc().toIso8601String(),
      'nonce': _nonce(),
      'classroom_id': ?classroomId,
      'direction': ?direction,
    };

    try {
      final data = await _api.post(ApiRoutes.kioskRecognize, body: payload);
      return RecognizeResult.fromJson(data);
    } on ApiFailure catch (e) {
      if (e.isRetryable) {
        await _queue.enqueue(payload);
        return RecognizeResult.queued();
      }
      return RecognizeResult.error(e.message);
    }
  }

  /// Coba kirim ulang antrean offline.
  ///
  /// Mengembalikan jumlah yang berhasil terkirim, agar UI bisa memberi tahu
  /// operator bahwa data sudah aman di server.
  Future<SyncOutcome> syncQueue() async {
    final purged = await _queue.purgeStale();
    final batch = await _queue.take(limit: 25);

    var sent = 0;
    var failed = 0;

    for (final item in batch) {
      // Payload yang berulang kali ditolak kemungkinan bermasalah pada
      // dirinya sendiri (mis. versi model lama). Menahannya selamanya hanya
      // menyumbat antrean absensi berikutnya.
      if (item.isExhausted) {
        await _queue.remove(item.id);
        failed++;
        continue;
      }

      try {
        await _api.post(ApiRoutes.kioskRecognize, body: item.payload);
        await _queue.remove(item.id);
        sent++;
      } on ApiFailure catch (e) {
        if (e.isRetryable) {
          await _queue.markFailed(item.id, e.message);
          // Jaringan masih bermasalah; hentikan batch agar tidak membanjiri.
          break;
        }
        // Ditolak permanen oleh aturan — tidak ada gunanya menyimpan.
        await _queue.remove(item.id);
        failed++;
      }
    }

    return SyncOutcome(
      sent: sent,
      dropped: failed + purged,
      remaining: await _queue.count(),
    );
  }

  Future<int> pendingCount() => _queue.count();

  /// Kirim heartbeat dan ambil konfigurasi terkini.
  Future<HeartbeatResult?> heartbeat({
    int? batteryPct,
    String? network,
  }) async {
    final pending = await _queue.count();

    final data = await _api.tryPost(ApiRoutes.kioskHeartbeat, body: {
      'battery_pct': ?batteryPct,
      'queued_events': pending,
      'app_version': '1.0.0',
      'network': ?network,
      'embedding_model_version': AppConfig.faceModelVersion,
    });

    if (data == null) return null;
    final result = HeartbeatResult.fromJson(data);
    await _storage.saveRosterVersion(result.rosterVersion);
    return result;
  }

  Future<List<RosterEntry>> roster() async {
    final list = await _api.getList(ApiRoutes.kioskRoster);
    return list
        .whereType<Map<String, dynamic>>()
        .map(RosterEntry.fromJson)
        .toList();
  }

  // =================================================================
  // Pendaftaran wajah (mode enroll)
  // =================================================================

  /// Daftarkan satu sampel wajah siswa dari tablet bermode `enroll`.
  Future<String> enrollFace({
    required String studentId,
    required Uint8List jpegBytes,
    required Float32List embedding,
    required String pose,
  }) async {
    final data = await _api.post(ApiRoutes.kioskEnrollFace(studentId), body: {
      'image_base64': base64Encode(jpegBytes),
      'embedding': embedding.toList(),
      'model_version': AppConfig.faceModelVersion,
      'pose': pose,
    });

    return data['message'] as String? ??
        'Sampel wajah tersimpan (${data['sample_count'] ?? '?'} total).';
  }

  // =================================================================
  // Login pengguna & monitoring
  // =================================================================

  Future<UserProfile> login(String identifier, String password) async {
    final data = await _api.post(ApiRoutes.login, body: {
      'identifier': identifier.trim(),
      'password': password,
      'device_name': 'Aplikasi Absensi Mobile',
    });

    await _storage.saveUserTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );

    final profile =
        UserProfile.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUserProfile(profile.toJson());
    return profile;
  }

  Future<void> logout() async {
    final refresh = await _storage.refreshToken();
    if (refresh != null) {
      // Kegagalan revoke di server tidak boleh menghalangi logout lokal —
      // pengguna sudah menekan keluar dan berhak tokennya hilang dari tablet.
      await _api.tryPost(ApiRoutes.logout, body: {'refresh_token': refresh});
    }
    await _storage.clearUserTokens();
    await _storage.clearUserProfile();
  }

  UserProfile? cachedUser() {
    final raw = _storage.userProfile();
    return raw == null ? null : UserProfile.fromJson(raw);
  }

  Future<AttendanceSummary> summary({String? schoolId, DateTime? date}) async {
    final data = await _api.getObject(ApiRoutes.attendanceSummary, query: {
      'school_id': ?schoolId,
      if (date != null) 'date': _ymd(date),
    });
    return AttendanceSummary.fromJson(data);
  }

  Future<List<AttendanceRow>> attendances({
    String? schoolId,
    String? classroomId,
    DateTime? date,
    String? status,
  }) async {
    final day = _ymd(date ?? DateTime.now());
    final list = await _api.getList(ApiRoutes.attendances, query: {
      'school_id': ?schoolId,
      'classroom_id': ?classroomId,
      'status': ?status,
      'from': day,
      'to': day,
      'per_page': 200,
    });

    return list
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRow.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> classroomSummaries({
    String? schoolId,
    DateTime? date,
  }) async {
    final list = await _api.getList(ApiRoutes.attendanceByClassroom, query: {
      'school_id': ?schoolId,
      'date': _ymd(date ?? DateTime.now()),
    });
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Koreksi absensi (izin/sakit/lupa absen) dari aplikasi guru.
  Future<String> correctAttendance({
    required String studentId,
    required String status,
    required String notes,
    String? checkInTime,
    DateTime? date,
    bool notifyGuardian = false,
  }) async {
    final data = await _api.post(ApiRoutes.attendanceManual, body: {
      'student_id': studentId,
      'status': status,
      'notes': notes,
      'check_in_time': ?checkInTime,
      if (date != null) 'attendance_date': _ymd(date),
      'notify_guardian': notifyGuardian,
    });
    return data['status'] as String? ?? 'Absensi diperbarui.';
  }

  // =================================================================
  // Jargon GO — beranda & data milik pengguna
  // =================================================================

  Future<HomeSummary> home() async {
    final data = await _api.getObject(ApiRoutes.home);
    return HomeSummary.fromJson(data);
  }

  /// Riwayat absensi siswa yang tertaut ke akun.
  ///
  /// [studentId] hanya mempersempit; server tetap memeriksa bahwa siswa itu
  /// memang tertaut ke akun, sehingga menebak UUID tidak berguna.
  Future<List<AttendanceRow>> myAttendance({
    String? studentId,
    DateTime? from,
    DateTime? to,
  }) async {
    final list = await _api.getList(ApiRoutes.myAttendance, query: {
      'student_id': ?studentId,
      'from': _ymd(from ?? DateTime.now().subtract(const Duration(days: 29))),
      'to': _ymd(to ?? DateTime.now()),
    });

    return list
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRow.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> myRecap({
    required String studentId,
    DateTime? from,
    DateTime? to,
  }) async {
    return _api.getObject(ApiRoutes.myRecap(studentId), query: {
      'from': _ymd(from ?? DateTime.now().subtract(const Duration(days: 29))),
      'to': _ymd(to ?? DateTime.now()),
    });
  }

  // =================================================================
  // Panic Button
  // =================================================================

  Future<List<PanicCategory>> panicCategories() async {
    final list = await _api.getList(ApiRoutes.panicCategories);
    return list
        .whereType<Map<String, dynamic>>()
        .map(PanicCategory.fromJson)
        .toList();
  }

  Future<List<PanicReport>> panicFeed({
    bool mineOnly = false,
    String? categoryCode,
    String? severity,
    int page = 1,
  }) async {
    final list = await _api.getList(ApiRoutes.panicReports, query: {
      if (mineOnly) 'mine': true,
      'category_code': ?categoryCode,
      'severity': ?severity,
      'page': page,
      'per_page': 20,
    });

    return list
        .whereType<Map<String, dynamic>>()
        .map(PanicReport.fromJson)
        .toList();
  }

  Future<PanicReportDetail> panicDetail(String id) async {
    final data = await _api.getObject(ApiRoutes.panicReport(id));
    return PanicReportDetail.fromJson(data);
  }

  /// Kirim laporan baru.
  ///
  /// [mediaBase64] adalah foto bukti. Server membuang metadata EXIF sebelum
  /// menyimpannya — koordinat GPS pada foto akan membocorkan lokasi pelapor.
  Future<Map<String, dynamic>> createPanicReport({
    required String categoryId,
    required String title,
    required String body,
    String? severity,
    String visibility = 'publik',
    List<String> mediaBase64 = const [],
  }) async {
    return _api.post(ApiRoutes.panicReports, body: {
      'category_id': categoryId,
      'title': title,
      'body': body,
      'severity': ?severity,
      'visibility': visibility,
      'media_base64': mediaBase64,
    });
  }

  Future<bool> togglePanicSupport(String reportId) async {
    final data = await _api.post(ApiRoutes.panicSupport(reportId));
    return data['supported'] as bool? ?? false;
  }

  Future<PanicComment> addPanicComment({
    required String reportId,
    required String body,
    bool asOfficial = false,
  }) async {
    final data = await _api.post(ApiRoutes.panicComments(reportId), body: {
      'body': body,
      'as_official': asOfficial,
    });
    return PanicComment.fromJson(data);
  }

  // =================================================================
  // Pemberkasan
  // =================================================================

  Future<List<DocumentType>> documentTypes(String purpose) async {
    final list = await _api.getList(ApiRoutes.documentTypes, query: {
      'purpose': purpose,
    });
    return list
        .whereType<Map<String, dynamic>>()
        .map(DocumentType.fromJson)
        .toList();
  }

  Future<List<Submission>> submissions({bool mineOnly = true, String? status}) async {
    final list = await _api.getList(ApiRoutes.submissions, query: {
      'mine': mineOnly,
      'status': ?status,
      'per_page': 50,
    });
    return list
        .whereType<Map<String, dynamic>>()
        .map(Submission.fromJson)
        .toList();
  }

  Future<SubmissionDetail> submissionDetail(String id) async {
    final data = await _api.getObject(ApiRoutes.submission(id));
    return SubmissionDetail.fromJson(data);
  }

  Future<Submission> createSubmission({
    required String purpose,
    required String title,
    String? period,
    String? note,
  }) async {
    final data = await _api.post(ApiRoutes.submissions, body: {
      'purpose': purpose,
      'title': title,
      'period': ?period,
      'note': ?note,
    });
    return Submission.fromJson(data);
  }

  /// Unggah satu berkas ke pengajuan.
  ///
  /// Mengembalikan pesan server, yang sudah memuat sisa dokumen wajib —
  /// lebih berguna bagi guru daripada sekadar "berhasil".
  Future<String> uploadDocument({
    required String submissionId,
    required String originalName,
    required Uint8List content,
    String? documentTypeId,
  }) async {
    final data = await _api.post(
      ApiRoutes.submissionFiles(submissionId),
      body: {
        'document_type_id': ?documentTypeId,
        'original_name': originalName,
        'content_base64': base64Encode(content),
      },
    );
    return data['message'] as String? ?? 'Berkas terunggah';
  }

  Future<void> deleteDocument(String fileId) async {
    await _api.delete(ApiRoutes.documentFile(fileId));
  }

  Future<String> submitDocuments(String submissionId) async {
    final data = await _api.post(ApiRoutes.submitSubmission(submissionId));
    return data['status'] as String? ?? 'diajukan';
  }

  // =================================================================

  /// Nonce sekali pakai. Server menolak nonce yang terulang, sehingga payload
  /// absensi yang disadap tidak bisa diputar ulang.
  String _nonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class SyncOutcome {
  const SyncOutcome({
    required this.sent,
    required this.dropped,
    required this.remaining,
  });

  final int sent;

  /// Dibuang karena kedaluwarsa atau ditolak permanen. Dilaporkan agar
  /// operator tahu ada absensi yang perlu dikoreksi manual.
  final int dropped;

  final int remaining;

  bool get hasActivity => sent > 0 || dropped > 0;
}
