import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/config.dart';
import '../../core/failure.dart';

/// Mesin pengenalan wajah di perangkat.
///
/// PEMBAGIAN KERJA DENGAN SERVER
///
/// Perangkat mendeteksi wajah, memeriksa kelayakannya, lalu menghitung
/// **embedding** (vektor 512 dimensi). Yang dikirim ke server hanyalah vektor
/// itu — sekitar 2 KB — bukan gambar yang berukuran ~200 KB. Untuk ribuan
/// sekolah yang banyak di antaranya berjaringan lambat, ini perbedaan antara
/// "instan" dan "tidak bisa dipakai".
///
/// Konsekuensinya: versi model di perangkat harus sama dengan versi yang
/// tercatat pada embedding tersimpan di server. Itu dijaga oleh
/// [AppConfig.faceModelVersion] yang divalidasi server pada setiap request.
///
/// CATATAN LIVENESS
///
/// [FaceEngine] menerapkan liveness *pasif* berbasis isyarat perilaku (kedip
/// dan gerak kepala kecil). Ini menghentikan penyalahgunaan paling umum di
/// lapangan — mengarahkan foto cetak atau layar ponsel ke kamera — tetapi
/// BUKAN anti-spoof kelas tinggi. Untuk itu diperlukan sensor kedalaman atau
/// model anti-spoof khusus; lihat docs/ARCHITECTURE.md.
class FaceEngine {
  FaceEngine._(this._detector, this._interpreter);

  final FaceDetector _detector;
  final Interpreter _interpreter;

  /// Riwayat singkat isyarat wajah untuk menilai liveness.
  final List<_FaceCue> _cues = <_FaceCue>[];
  static const int _cueWindow = 12;

  bool _closed = false;

  static Future<FaceEngine> load() async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        // `accurate` dipilih walau lebih lambat: salah mendeteksi wajah pada
        // antrean pagi lebih merugikan daripada selisih beberapa milidetik.
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true, // probabilitas mata terbuka (untuk kedip)
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.15,
      ),
    );

    late final Interpreter interpreter;
    try {
      interpreter = await Interpreter.fromAsset(
        AppConfig.modelAsset,
        options: InterpreterOptions()..threads = 2,
      );
    } catch (e) {
      await detector.close();
      throw FaceFailure(
        'Model pengenalan wajah tidak dapat dimuat. Pastikan berkas '
        '${AppConfig.modelAsset} sudah disertakan dalam aplikasi. Detail: $e',
        isFatal: true,
      );
    }

    return FaceEngine._(detector, interpreter);
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _detector.close();
    _interpreter.close();
  }

  /// Analisis satu frame kamera.
  ///
  /// Mengembalikan [FaceAnalysis] yang menjelaskan apakah frame ini layak
  /// dipakai, dan bila layak, embedding-nya. Frame yang tidak layak tidak
  /// dianggap galat — pada aliran video, sebagian besar frame memang tidak
  /// layak, dan pemanggil hanya menampilkan petunjuk kepada siswa.
  Future<FaceAnalysis> analyze(
    CameraImage frame,
    CameraDescription camera,
    int deviceRotationDegrees,
  ) async {
    final inputImage = _toInputImage(frame, camera, deviceRotationDegrees);
    if (inputImage == null) {
      return FaceAnalysis.notReady('Format kamera tidak didukung.');
    }

    final faces = await _detector.processImage(inputImage);

    if (faces.isEmpty) {
      _cues.clear();
      return FaceAnalysis.notReady('Posisikan wajah di dalam lingkaran.');
    }
    if (faces.length > 1) {
      _cues.clear();
      return FaceAnalysis.notReady(
        'Terdeteksi ${faces.length} wajah. Satu orang saja di depan kamera.',
      );
    }

    final face = faces.first;
    final frameWidth = frame.width.toDouble();
    final widthRatio = face.boundingBox.width / frameWidth;

    if (widthRatio < AppConfig.minFaceWidthRatio) {
      return FaceAnalysis.notReady('Mendekat sedikit ke kamera.');
    }
    if (widthRatio > 0.92) {
      return FaceAnalysis.notReady('Terlalu dekat, mundur sedikit.');
    }

    final yaw = face.headEulerAngleY?.abs() ?? 0;
    final roll = face.headEulerAngleZ?.abs() ?? 0;
    if (yaw > AppConfig.maxHeadAngle || roll > AppConfig.maxHeadAngle) {
      return FaceAnalysis.notReady('Hadapkan wajah lurus ke kamera.');
    }

    _pushCue(face);
    final liveness = _livenessScore();

    if (liveness < AppConfig.minLiveness) {
      return FaceAnalysis.notReady(
        'Kedipkan mata atau gerakkan kepala sedikit.',
        liveness: liveness,
      );
    }

    // Baru di titik ini konversi gambar dan inferensi dijalankan — keduanya
    // jauh lebih mahal daripada pemeriksaan di atas, jadi dikerjakan hanya
    // untuk frame yang sudah pasti layak.
    final rgb = _toRgbImage(frame, camera);
    if (rgb == null) {
      return FaceAnalysis.notReady('Gagal membaca frame kamera.');
    }

    final crop = _cropFace(rgb, face.boundingBox);
    final embedding = _embed(crop);

    return FaceAnalysis.ready(
      embedding: embedding,
      liveness: liveness,
      cropped: crop,
      faceWidthRatio: widthRatio,
    );
  }

  /// Hitung embedding dari satu gambar wajah yang sudah di-crop.
  /// Dipakai alur pendaftaran, yang bekerja dari foto still, bukan aliran video.
  Float32List embedCropped(img.Image cropped) => _embed(
        img.copyResize(
          cropped,
          width: AppConfig.modelInputSize,
          height: AppConfig.modelInputSize,
          interpolation: img.Interpolation.linear,
        ),
      );

  // =================================================================
  // Inferensi
  // =================================================================

  Float32List _embed(img.Image face112) {
    final size = AppConfig.modelInputSize;
    final input = List.generate(
      1,
      (_) => List.generate(
        size,
        (y) => List.generate(size, (x) {
          final p = face112.getPixel(x, y);
          // Normalisasi ke [-1, 1] — konvensi MobileFaceNet/ArcFace.
          return <double>[
            (p.r - 127.5) / 127.5,
            (p.g - 127.5) / 127.5,
            (p.b - 127.5) / 127.5,
          ];
        }),
      ),
    );

    final output = List.generate(
      1,
      (_) => List<double>.filled(AppConfig.embeddingDim, 0),
    );

    _interpreter.run(input, output);

    return l2Normalize(Float32List.fromList(
      output.first.map((e) => e.toDouble()).toList(),
    ));
  }

  /// Normalisasi L2. Server menyimpan dan membandingkan vektor ternormalisasi;
  /// mengirim yang sudah normal membuat nilai di kedua sisi identik.
  static Float32List l2Normalize(Float32List v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm < 1e-9 || !norm.isFinite) return v;
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / norm;
    }
    return out;
  }

  // =================================================================
  // Liveness pasif
  // =================================================================

  void _pushCue(Face face) {
    _cues.add(_FaceCue(
      leftEye: face.leftEyeOpenProbability,
      rightEye: face.rightEyeOpenProbability,
      yaw: face.headEulerAngleY ?? 0,
      pitch: face.headEulerAngleX ?? 0,
      width: face.boundingBox.width,
    ));
    if (_cues.length > _cueWindow) {
      _cues.removeAt(0);
    }
  }

  /// Skor 0..1 dari isyarat perilaku dalam jendela frame terakhir.
  ///
  /// Foto cetak dan tangkapan layar tidak berkedip dan tidak bergerak
  /// mikro — keduanya menghasilkan nilai di bawah ambang.
  double _livenessScore() {
    if (_cues.length < 4) return 0.0;

    // Dasar kecil: wajah terdeteksi stabil beberapa frame.
    var score = 0.30;

    // Kedip: probabilitas mata sempat turun lalu naik lagi.
    final eyeValues = _cues
        .map((c) => math.min(c.leftEye ?? 1.0, c.rightEye ?? 1.0))
        .toList();
    final minEye = eyeValues.reduce(math.min);
    final maxEye = eyeValues.reduce(math.max);
    if (minEye < 0.35 && maxEye > 0.70) {
      score += 0.40;
    } else if (maxEye - minEye > 0.25) {
      // Perubahan sebagian — kelopak bergerak walau tidak menutup penuh.
      score += 0.18;
    }

    // Gerak kepala mikro: manusia tidak pernah benar-benar diam.
    final yaws = _cues.map((c) => c.yaw).toList();
    final pitches = _cues.map((c) => c.pitch).toList();
    final motion = _spread(yaws) + _spread(pitches);
    if (motion > 3.0) {
      score += 0.25;
    } else if (motion > 1.0) {
      score += 0.12;
    }

    // Perubahan jarak wajah ke kamera. Foto yang dipegang biasanya sangat
    // stabil; wajah asli bernapas dan sedikit maju-mundur.
    final widths = _cues.map((c) => c.width).toList();
    if (_spread(widths) > 2.0) {
      score += 0.08;
    }

    return score.clamp(0.0, 1.0);
  }

  static double _spread(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return math.sqrt(variance);
  }

  /// Bersihkan riwayat isyarat, mis. setelah satu siswa selesai discan.
  void resetLiveness() => _cues.clear();

  // =================================================================
  // Konversi frame
  // =================================================================

  /// Bangun [InputImage] untuk ML Kit dari frame kamera.
  InputImage? _toInputImage(
    CameraImage frame,
    CameraDescription camera,
    int deviceRotationDegrees,
  ) {
    final rotation = _resolveRotation(camera, deviceRotationDegrees);
    final format = InputImageFormatValue.fromRawValue(frame.format.raw);
    if (rotation == null || format == null) return null;

    // Aplikasi meminta NV21 (Android) / BGRA8888 (iOS) sehingga selalu ada
    // satu plane utuh — jauh lebih sederhana dan lebih cepat daripada
    // menyusun ulang tiga plane YUV.
    if (frame.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: frame.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: frame.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _resolveRotation(
    CameraDescription camera,
    int deviceRotationDegrees,
  ) {
    // Untuk kamera depan (yang dipakai kios), orientasi sensor dan rotasi
    // perangkat saling menambah; untuk kamera belakang saling mengurangi.
    final sensor = camera.sensorOrientation;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (sensor + deviceRotationDegrees) % 360
        : (sensor - deviceRotationDegrees + 360) % 360;

    return InputImageRotationValue.fromRawValue(degrees);
  }

  /// Ubah frame kamera menjadi gambar RGB.
  img.Image? _toRgbImage(CameraImage frame, CameraDescription camera) {
    try {
      final out = switch (frame.format.group) {
        ImageFormatGroup.nv21 => _nv21ToRgb(frame),
        ImageFormatGroup.yuv420 => _nv21ToRgb(frame),
        ImageFormatGroup.bgra8888 => _bgraToRgb(frame),
        _ => null,
      };
      if (out == null) return null;

      // Kamera depan menghasilkan citra tercermin. Wajah manusia tidak
      // simetris sempurna, sehingga embedding dari citra tercermin berbeda
      // dari yang asli — harus dibalik agar konsisten dengan foto pendaftaran.
      return camera.lensDirection == CameraLensDirection.front
          ? img.flipHorizontal(out)
          : out;
    } catch (_) {
      return null;
    }
  }

  img.Image _nv21ToRgb(CameraImage frame) {
    final width = frame.width;
    final height = frame.height;
    final bytes = frame.planes.first.bytes;
    final out = img.Image(width: width, height: height);

    final frameSize = width * height;

    for (var y = 0; y < height; y++) {
      final uvRow = frameSize + (y >> 1) * width;
      for (var x = 0; x < width; x++) {
        final yValue = bytes[y * width + x] & 0xFF;

        // NV21: pasangan V,U bergantian, satu untuk setiap blok 2x2 piksel.
        final uvIndex = uvRow + (x & ~1);
        final v = (uvIndex < bytes.length ? bytes[uvIndex] : 128) - 128;
        final u = (uvIndex + 1 < bytes.length ? bytes[uvIndex + 1] : 128) - 128;

        final r = (yValue + 1.370705 * v).round().clamp(0, 255);
        final g = (yValue - 0.337633 * u - 0.698001 * v).round().clamp(0, 255);
        final b = (yValue + 1.732446 * u).round().clamp(0, 255);

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  img.Image _bgraToRgb(CameraImage frame) {
    final plane = frame.planes.first;
    return img.Image.fromBytes(
      width: frame.width,
      height: frame.height,
      bytes: plane.bytes.buffer,
      rowStride: plane.bytesPerRow,
      order: img.ChannelOrder.bgra,
    );
  }

  /// Crop wajah dengan margin, lalu skala ke ukuran input model.
  ///
  /// Margin 25% penting: model wajah dilatih pada crop yang menyertakan dahi
  /// dan dagu. Crop terlalu rapat pada kotak deteksi menurunkan akurasi.
  img.Image _cropFace(img.Image source, Rect box) {
    final marginX = box.width * 0.25;
    final marginY = box.height * 0.25;

    var left = (box.left - marginX).round();
    var top = (box.top - marginY).round();
    var right = (box.right + marginX).round();
    var bottom = (box.bottom + marginY).round();

    left = left.clamp(0, source.width - 1);
    top = top.clamp(0, source.height - 1);
    right = right.clamp(left + 1, source.width);
    bottom = bottom.clamp(top + 1, source.height);

    final cropped = img.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );

    return img.copyResize(
      cropped,
      width: AppConfig.modelInputSize,
      height: AppConfig.modelInputSize,
      interpolation: img.Interpolation.linear,
    );
  }
}

/// Isyarat satu frame untuk penilaian liveness.
class _FaceCue {
  const _FaceCue({
    this.leftEye,
    this.rightEye,
    required this.yaw,
    required this.pitch,
    required this.width,
  });

  final double? leftEye;
  final double? rightEye;
  final double yaw;
  final double pitch;
  final double width;
}

/// Hasil analisis satu frame.
class FaceAnalysis {
  const FaceAnalysis._({
    required this.isReady,
    required this.hint,
    this.embedding,
    this.liveness = 0,
    this.cropped,
    this.faceWidthRatio = 0,
  });

  /// `true` bila embedding siap dikirim ke server.
  final bool isReady;

  /// Petunjuk untuk ditampilkan ke siswa (mis. "Mendekat sedikit").
  final String hint;

  final Float32List? embedding;
  final double liveness;

  /// Gambar wajah ter-crop. Hanya dipakai alur PENDAFTARAN; pada absensi
  /// harian nilai ini dibuang tanpa pernah dikirim ke mana pun.
  final img.Image? cropped;

  final double faceWidthRatio;

  factory FaceAnalysis.notReady(String hint, {double liveness = 0}) =>
      FaceAnalysis._(isReady: false, hint: hint, liveness: liveness);

  factory FaceAnalysis.ready({
    required Float32List embedding,
    required double liveness,
    required img.Image cropped,
    required double faceWidthRatio,
  }) =>
      FaceAnalysis._(
        isReady: true,
        hint: 'Wajah terdeteksi',
        embedding: embedding,
        liveness: liveness,
        cropped: cropped,
        faceWidthRatio: faceWidthRatio,
      );
}
