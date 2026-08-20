import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/failure.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import 'face_engine.dart';

/// Keadaan layar kios.
enum KioskPhase {
  /// Menyiapkan kamera & model.
  starting,

  /// Siap memindai, menunggu wajah.
  scanning,

  /// Sedang mengirim ke server.
  submitting,

  /// Menampilkan hasil (sukses / gagal) sebelum kembali memindai.
  showingResult,

  /// Tidak bisa berjalan (izin kamera ditolak, model hilang, belum dipasangkan).
  blocked,
}

@immutable
class KioskState {
  const KioskState({
    this.phase = KioskPhase.starting,
    this.hint = 'Menyiapkan kamera...',
    this.result,
    this.blockReason,
    this.liveness = 0,
    this.todayWindows,
    this.pendingCount = 0,
    this.lastSync,
  });

  final KioskPhase phase;

  /// Petunjuk untuk siswa di depan kamera.
  final String hint;

  final RecognizeResult? result;

  /// Alasan layar tidak bisa dipakai; ditampilkan lengkap dengan langkah
  /// perbaikan agar operator sekolah bisa menanganinya sendiri.
  final String? blockReason;

  final double liveness;
  final TodayWindows? todayWindows;
  final int pendingCount;
  final DateTime? lastSync;

  bool get isScanning => phase == KioskPhase.scanning;

  KioskState copyWith({
    KioskPhase? phase,
    String? hint,
    RecognizeResult? result,
    bool clearResult = false,
    String? blockReason,
    double? liveness,
    TodayWindows? todayWindows,
    int? pendingCount,
    DateTime? lastSync,
  }) {
    return KioskState(
      phase: phase ?? this.phase,
      hint: hint ?? this.hint,
      result: clearResult ? null : (result ?? this.result),
      blockReason: blockReason ?? this.blockReason,
      liveness: liveness ?? this.liveness,
      todayWindows: todayWindows ?? this.todayWindows,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

/// Otak layar kios.
///
/// Menjalankan tiga hal bersamaan tanpa saling mengganggu:
///
/// 1. Aliran frame kamera -> deteksi wajah -> embedding -> kirim.
/// 2. Heartbeat berkala ke server (status perangkat, jendela jam hari ini).
/// 3. Sinkronisasi antrean offline.
///
/// Frame diproses satu per satu (`_busy`): mengizinkan pemrosesan paralel pada
/// tablet kelas menengah hanya membuat semuanya melambat dan antrean frame
/// menumpuk.
class KioskController extends StateNotifier<KioskState> {
  KioskController(this._repo) : super(const KioskState());

  final AbsensiRepository _repo;

  CameraController? _camera;
  FaceEngine? _engine;
  Timer? _heartbeatTimer;
  Timer? _syncTimer;
  Timer? _resultTimer;

  bool _busy = false;
  bool _disposed = false;

  /// Waktu scan terakhir per siswa, untuk menahan pemindaian berulang.
  final Map<String, DateTime> _lastScan = <String, DateTime>{};

  CameraController? get camera => _camera;

  Future<void> start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _block('Perangkat ini tidak memiliki kamera yang dapat digunakan.');
        return;
      }

      // Kamera depan: tablet dipasang menghadap siswa.
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        // Resolusi sedang cukup untuk crop 112px dan jauh lebih ringan
        // daripada high/max pada tablet murah.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      _camera = controller;

      _engine = await FaceEngine.load();
      if (_disposed) return;

      await controller.startImageStream(_onFrame);

      state = state.copyWith(
        phase: KioskPhase.scanning,
        hint: 'Posisikan wajah di dalam lingkaran.',
      );

      _startTimers();
      // Heartbeat pertama segera, agar jendela jam hari ini langsung tampil.
      unawaited(_beat());
      unawaited(_sync());
    } on CameraException catch (e) {
      _block(
        'Kamera tidak dapat diakses (${e.code}). Buka Pengaturan > Aplikasi > '
        'Absensi > Izin, lalu aktifkan izin Kamera.',
      );
    } on FaceFailure catch (e) {
      _block(e.message);
    } catch (e) {
      _block('Gagal menyiapkan perangkat: $e');
    }
  }

  void _startTimers() {
    _heartbeatTimer = Timer.periodic(
      AppConfig.heartbeatInterval,
      (_) => _beat(),
    );
    _syncTimer = Timer.periodic(AppConfig.syncInterval, (_) => _sync());
  }

  Future<void> _beat() async {
    if (_disposed) return;
    final result = await _repo.heartbeat();
    if (_disposed || result == null) return;

    state = state.copyWith(todayWindows: result.todayWindows);

    // Server memberi tahu bahwa versi model aplikasi sudah tertinggal.
    if (result.commands.contains('update_app')) {
      state = state.copyWith(
        hint: 'Versi aplikasi tertinggal. Hubungi operator untuk memperbarui.',
      );
    }
  }

  Future<void> _sync() async {
    if (_disposed) return;
    try {
      final outcome = await _repo.syncQueue();
      if (_disposed) return;
      state = state.copyWith(
        pendingCount: outcome.remaining,
        lastSync: outcome.hasActivity ? DateTime.now() : state.lastSync,
      );
    } catch (_) {
      // Sinkronisasi adalah proses latar; kegagalannya tidak boleh
      // memunculkan apa pun di layar yang sedang dipakai siswa.
    }
  }

  Future<void> _onFrame(CameraImage frame) async {
    if (_busy || _disposed) return;
    if (state.phase != KioskPhase.scanning) return;

    final engine = _engine;
    final camera = _camera;
    if (engine == null || camera == null) return;

    // Hari libur: jangan bebani server dengan pemindaian yang pasti ditolak.
    final windows = state.todayWindows;
    if (windows != null && (!windows.isActiveDay || windows.isHoliday)) {
      state = state.copyWith(
        hint: windows.isHoliday
            ? 'Hari ini libur${windows.holidayName != null ? ': ${windows.holidayName}' : ''}.'
            : 'Hari ini bukan hari sekolah.',
      );
      return;
    }

    _busy = true;
    try {
      final analysis = await engine.analyze(
        frame,
        camera.description,
        _rotationDegrees(),
      );

      if (_disposed) return;

      if (!analysis.isReady) {
        state = state.copyWith(
          hint: analysis.hint,
          liveness: analysis.liveness,
        );
        return;
      }

      await _submit(analysis);
    } catch (e) {
      if (!_disposed) {
        state = state.copyWith(hint: 'Gangguan pemrosesan: $e');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _submit(FaceAnalysis analysis) async {
    state = state.copyWith(
      phase: KioskPhase.submitting,
      hint: 'Memproses...',
    );

    final profile = _profileOrNull();
    final result = await _repo.recognize(
      embedding: analysis.embedding!,
      liveness: analysis.liveness,
      classroomId: profile?['classroom_id'] as String?,
    );

    if (_disposed) return;

    // Cooldown per siswa: mencegah satu siswa yang berdiri di depan kamera
    // memicu puluhan request dalam beberapa detik.
    final studentId = result.student?.id;
    if (studentId != null) {
      final last = _lastScan[studentId];
      if (last != null &&
          DateTime.now().difference(last) < AppConfig.scanCooldown &&
          result.action == RecognizeAction.alreadyRecorded) {
        _resumeScanning();
        return;
      }
      _lastScan[studentId] = DateTime.now();
    }

    _engine?.resetLiveness();

    state = state.copyWith(
      phase: KioskPhase.showingResult,
      result: result,
      hint: result.message,
    );

    // Hasil ditampilkan cukup lama untuk dibaca siswa berikutnya di antrean,
    // tetapi tidak sampai memperlambat jam sibuk pagi.
    _resultTimer?.cancel();
    _resultTimer = Timer(
      Duration(seconds: result.action.isSuccess ? 3 : 4),
      _resumeScanning,
    );
  }

  void _resumeScanning() {
    if (_disposed) return;
    state = state.copyWith(
      phase: KioskPhase.scanning,
      hint: 'Posisikan wajah di dalam lingkaran.',
      clearResult: true,
      liveness: 0,
    );
  }

  /// Lewati tampilan hasil dan langsung memindai lagi (tombol "Berikutnya").
  void skipResult() {
    _resultTimer?.cancel();
    _resumeScanning();
  }

  Future<void> syncNow() => _sync();

  int _rotationDegrees() {
    // Tablet kios dipasang tetap; orientasi perangkat mengikuti orientasi
    // native-nya sehingga 0 adalah nilai yang benar untuk pemasangan normal.
    // Bila terpasang miring, atur lewat `KIOSK_ROTATION` saat build.
    return const int.fromEnvironment('KIOSK_ROTATION', defaultValue: 0);
  }

  Map<String, dynamic>? _profileOrNull() => _profile;
  Map<String, dynamic>? _profile;

  // ignore: use_setters_to_change_properties
  void attachProfile(Map<String, dynamic>? profile) => _profile = profile;

  void _block(String reason) {
    if (_disposed) return;
    state = state.copyWith(
      phase: KioskPhase.blocked,
      blockReason: reason,
      hint: reason,
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _syncTimer?.cancel();
    _resultTimer?.cancel();

    final camera = _camera;
    _camera = null;
    if (camera != null) {
      // Hentikan stream sebelum dispose; melewatkan ini menyebabkan crash
      // native pada beberapa perangkat Android.
      try {
        if (camera.value.isStreamingImages) {
          await camera.stopImageStream();
        }
      } catch (_) {
        // Perangkat sudah melepas kamera lebih dulu.
      }
      await camera.dispose();
    }

    await _engine?.dispose();
    _engine = null;

    super.dispose();
  }
}

final kioskControllerProvider =
    StateNotifierProvider<KioskController, KioskState>((ref) {
  final controller = KioskController(ref.watch(repositoryProvider));
  controller.attachProfile(ref.watch(deviceProfileProvider));
  return controller;
});
