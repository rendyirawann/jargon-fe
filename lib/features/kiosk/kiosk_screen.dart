import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/models.dart';
import '../../providers.dart';
import 'kiosk_controller.dart';

/// Layar kios — yang dilihat siswa di gerbang atau di depan kelas.
///
/// Prinsip desainnya: satu siswa berdiri, melihat wajahnya di layar, dan
/// pergi. Tidak ada tombol yang perlu ditekan, tidak ada teks kecil yang perlu
/// dibaca. Umpan balik harus terbaca dari jarak satu meter dalam kurang dari
/// satu detik, karena akan ada barisan siswa di belakangnya.
class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  @override
  void initState() {
    super.initState();
    // Layar kios tidak boleh mati sendiri — kalau padam, siswa berikutnya
    // akan menyangka perangkatnya rusak.
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kioskControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kioskControllerProvider);
    final controller = ref.read(kioskControllerProvider.notifier);
    final profile = ref.watch(deviceProfileProvider);
    final pending = ref.watch(pendingCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: state.phase == KioskPhase.blocked
            ? _BlockedView(reason: state.blockReason ?? 'Perangkat tidak siap')
            : Column(
                children: [
                  _TopBar(profile: profile, pending: pending, state: state),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CameraLayer(controller: controller.camera),
                        _GuideOverlay(state: state),
                        if (state.result != null)
                          _ResultOverlay(
                            result: state.result!,
                            onNext: controller.skipResult,
                          ),
                      ],
                    ),
                  ),
                  _BottomHint(state: state),
                ],
              ),
      ),
    );
  }
}

class _CameraLayer extends StatelessWidget {
  const _CameraLayer({this.controller});

  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 20),
            Text(
              'Menyiapkan kamera...',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Pratinjau ditutup penuh (cover) agar tidak ada bilah hitam di tablet
    // dengan rasio berbeda dari sensor.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.previewSize?.height ?? 480,
        height: c.value.previewSize?.width ?? 640,
        child: CameraPreview(c),
      ),
    );
  }
}

class _GuideOverlay extends StatelessWidget {
  const _GuideOverlay({required this.state});

  final KioskState state;

  @override
  Widget build(BuildContext context) {
    final ready = state.liveness >= 0.5;

    return IgnorePointer(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth * 0.62;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ready
                      ? const Color(0xFF50CD89)
                      : Colors.white.withValues(alpha: 0.55),
                  width: 4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    required this.pending,
    required this.state,
  });

  final Map<String, dynamic>? profile;
  final int pending;
  final KioskState state;

  @override
  Widget build(BuildContext context) {
    final windows = state.todayWindows;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF111C33),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (profile?['school_name'] as String?) ?? 'Absensi Sekolah',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    (profile?['device_code'] as String?) ?? '-',
                    if (profile?['classroom_name'] != null)
                      profile!['classroom_name'] as String,
                    if (windows?.checkInDueAt != null)
                      'batas masuk ${windows!.checkInDueAt}',
                  ].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Lencana antrean offline: operator sekolah harus bisa melihat
          // bahwa ada absensi yang belum sampai ke server.
          if (pending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC700).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Color(0xFFFFC700), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$pending menunggu kirim',
                    style: const TextStyle(
                      color: Color(0xFFFFC700),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomHint extends StatelessWidget {
  const _BottomHint({required this.state});

  final KioskState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      color: const Color(0xFF111C33),
      child: Column(
        children: [
          Text(
            state.hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (state.phase == KioskPhase.scanning) ...[
            const SizedBox(height: 12),
            // Bilah liveness memberi siswa umpan balik bahwa sistem
            // memerhatikan — tanpa itu, orang cenderung diam menatap kamera,
            // yang justru menurunkan skor liveness.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.liveness.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(
                  state.liveness >= 0.5
                      ? const Color(0xFF50CD89)
                      : const Color(0xFFFFC700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.result, required this.onNext});

  final RecognizeResult result;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = _appearance(result);

    return Container(
      color: color.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 96, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (result.student != null) ...[
                const SizedBox(height: 18),
                Text(
                  result.student!.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    result.student!.classroomName ?? '-',
                    if (result.student!.nis != null) result.student!.nis!,
                  ].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 17,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 17,
                  height: 1.4,
                ),
              ),
              if (result.checkInTime != null || result.checkOutTime != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    result.checkOutTime != null
                        ? 'Jam pulang ${result.checkOutTime}'
                        : 'Jam masuk ${result.checkInTime}'
                            '${result.lateMinutes > 0 ? ' · terlambat ${result.lateMinutes} menit' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TextButton(
                onPressed: onNext,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'Siswa Berikutnya',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, IconData, String) _appearance(RecognizeResult r) =>
      switch (r.action) {
        RecognizeAction.checkedIn => (
            r.status == 'terlambat'
                ? const Color(0xFFE08700)
                : const Color(0xFF1B7F4E),
            r.status == 'terlambat' ? Icons.schedule : Icons.check_circle,
            r.status == 'terlambat' ? 'Terlambat' : 'Absen Masuk Berhasil',
          ),
        RecognizeAction.checkedOut => (
            const Color(0xFF15607A),
            Icons.logout,
            'Absen Pulang Berhasil',
          ),
        RecognizeAction.alreadyRecorded => (
            const Color(0xFF3F4A63),
            Icons.info,
            'Sudah Tercatat',
          ),
        RecognizeAction.queuedOffline => (
            const Color(0xFF7A5B15),
            Icons.cloud_upload,
            'Tersimpan di Perangkat',
          ),
        RecognizeAction.noMatch => (
            const Color(0xFF8A2233),
            Icons.person_search,
            'Wajah Tidak Dikenali',
          ),
        RecognizeAction.lowConfidence => (
            const Color(0xFF8A5A22),
            Icons.help_outline,
            'Perlu Verifikasi Petugas',
          ),
        RecognizeAction.rejected => (
            const Color(0xFF8A2233),
            Icons.block,
            'Tidak Dapat Diproses',
          ),
      };
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 84, color: Color(0xFFF1416C)),
            const SizedBox(height: 24),
            const Text(
              'Perangkat Belum Siap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali ke Menu'),
            ),
          ],
        ),
      ),
    );
  }
}
