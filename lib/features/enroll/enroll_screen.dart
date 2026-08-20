import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../core/failure.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../kiosk/face_engine.dart';

/// Pendaftaran wajah dari tablet bermode `enroll`.
///
/// Alur ini SATU-SATUNYA tempat aplikasi mengirim gambar wajah ke server.
/// Absensi harian hanya mengirim vektor.
///
/// Sampel diambil dari tiga pose (depan, miring kiri, miring kanan) karena
/// pengenalan yang hanya dilatih dari satu sudut akan gagal begitu siswa
/// datang dengan posisi kepala berbeda atau pencahayaan berubah.
class EnrollScreen extends ConsumerStatefulWidget {
  const EnrollScreen({super.key, required this.student});

  final RosterEntry student;

  @override
  ConsumerState<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends ConsumerState<EnrollScreen> {
  static const _poses = <String, String>{
    'frontal': 'Menghadap depan',
    'left': 'Miring ke kiri',
    'right': 'Miring ke kanan',
  };

  CameraController? _camera;
  FaceEngine? _engine;

  String _pose = 'frontal';
  String _hint = 'Menyiapkan kamera...';
  bool _busy = false;
  bool _blocked = false;
  final List<String> _saved = <String>[];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _shutdown() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      try {
        await camera.dispose();
      } catch (_) {
        // Perangkat sudah melepas kamera lebih dulu.
      }
    }
    await _engine?.dispose();
    _engine = null;
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Untuk pendaftaran dipakai resolusi tinggi: gambar ini diarsipkan dan
      // akan dipakai menghitung ulang embedding bila model di-upgrade, jadi
      // kualitasnya menentukan akurasi bertahun-tahun ke depan.
      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final engine = await FaceEngine.load();
      if (!mounted) {
        await controller.dispose();
        await engine.dispose();
        return;
      }

      setState(() {
        _camera = controller;
        _engine = engine;
        _hint = 'Posisikan wajah siswa, lalu tekan Ambil Foto.';
      });
    } on FaceFailure catch (e) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _hint = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _hint = 'Kamera tidak dapat diakses: $e';
        });
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    final engine = _engine;
    if (camera == null || engine == null || _busy) return;

    setState(() {
      _busy = true;
      _hint = 'Memproses foto...';
    });

    XFile? shot;
    try {
      shot = await camera.takePicture();
      final bytes = await shot.readAsBytes();

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw FaceFailure('Foto tidak dapat dibaca. Coba ambil ulang.');
      }

      // Kamera depan menghasilkan citra tercermin. Wajah manusia tidak
      // simetris, jadi embedding dari citra tercermin berbeda dari aslinya —
      // harus dibalik agar konsisten dengan frame absensi harian.
      final oriented = camera.description.lensDirection == CameraLensDirection.front
          ? img.flipHorizontal(decoded)
          : decoded;

      final square = _centerSquare(oriented);
      final embedding = engine.embedCropped(square);

      final jpeg = Uint8List.fromList(
        img.encodeJpg(
          img.copyResize(square, width: 320, height: 320),
          quality: 92,
        ),
      );

      final message = await ref.read(repositoryProvider).enrollFace(
            studentId: widget.student.studentId,
            jpegBytes: jpeg,
            embedding: embedding,
            pose: _pose,
          );

      if (!mounted) return;
      setState(() {
        _saved.add(_poses[_pose] ?? _pose);
        _hint = message;
        // Otomatis lanjut ke pose berikutnya yang belum diambil.
        final next = _poses.keys.firstWhere(
          (p) => !_saved.contains(_poses[p]),
          orElse: () => _pose,
        );
        _pose = next;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: const Color(0xFF1B7F4E)),
      );
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() => _hint = e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFF1416C),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } on FaceFailure catch (e) {
      if (mounted) setState(() => _hint = e.message);
    } catch (e) {
      if (mounted) setState(() => _hint = 'Gagal memproses foto: $e');
    } finally {
      // Berkas sementara dari kamera dihapus: gambar wajah tidak boleh
      // tertinggal di penyimpanan tablet yang dipasang di ruang publik.
      if (shot != null) {
        try {
          final file = File(shot.path);
          if (file.existsSync()) await file.delete();
        } catch (_) {
          // Berkas sudah hilang atau dikunci OS — bukan kegagalan yang
          // perlu ditampilkan ke operator.
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Crop persegi di tengah frame. Model mengharapkan input persegi, dan
  /// meregangkan gambar non-persegi akan mendistorsi proporsi wajah.
  img.Image _centerSquare(img.Image source) {
    final side = source.width < source.height ? source.width : source.height;
    return img.copyCrop(
      source,
      x: (source.width - side) ~/ 2,
      y: (source.height - side) ~/ 2,
      width: side,
      height: side,
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftarkan Wajah'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.student.fullName}'
                '${widget.student.classroomName != null ? ' · ${widget.student.classroomName}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: _blocked
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Color(0xFFF1416C)),
                    const SizedBox(height: 16),
                    Text(_hint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: camera == null || !camera.value.isInitialized
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: camera.value.previewSize?.height ?? 480,
                                  height: camera.value.previewSize?.width ?? 640,
                                  child: CameraPreview(camera),
                                ),
                              ),
                              // Panduan crop persegi, sesuai bagian gambar yang
                              // benar-benar dikirim ke server.
                              Center(
                                child: LayoutBuilder(
                                  builder: (context, c) => Container(
                                    width: c.maxWidth * 0.7,
                                    height: c.maxWidth * 0.7,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white70,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_hint, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: _poses.entries.map((e) {
                          final done = _saved.contains(e.value);
                          return ChoiceChip(
                            label: Text(
                              done ? '${e.value} ✓' : e.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _pose == e.key,
                            onSelected: (_) => setState(() => _pose = e.key),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tersimpan: ${_saved.length} sampel. Dianjurkan 3 pose '
                        'berbeda agar pengenalan tetap akurat saat pencahayaan '
                        'dan posisi kepala berubah.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _capture,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(_busy ? 'Memproses...' : 'Ambil Foto'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
