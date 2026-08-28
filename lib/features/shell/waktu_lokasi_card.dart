import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';

/// Kartu tanggal, jam, dan lokasi saat ini untuk beranda mobile.
///
/// MENGAPA NAMA HARI DAN BULAN DITULIS SENDIRI
///
/// `intl` ada di pubspec, tetapi `DateFormat('EEEE', 'id')` bergantung pada
/// data simbol tanggal per-locale yang harus tersedia saat berjalan. Bila
/// tidak, ia melempar `LocaleDataException` — dan kegagalan itu muncul di
/// perangkat pengguna, bukan saat build. Untuk sembilan belas kata yang tidak
/// akan pernah berubah, ketergantungan itu tidak sepadan.
///
/// LOKASI DIAMBIL SEKALI, BUKAN DIPANTAU TERUS
///
/// `getCurrentPosition` sekali saat kartu dibuka, tanpa `getPositionStream`.
/// Beranda tidak membutuhkan pergerakan pengguna, dan aliran lokasi yang
/// terus hidup adalah salah satu penguras baterai terbesar di Android.
class WaktuLokasiCard extends StatefulWidget {
  const WaktuLokasiCard({super.key});

  @override
  State<WaktuLokasiCard> createState() => _WaktuLokasiCardState();
}

enum _Lokasi { memuat, siap, layananMati, ditolak, ditolakPermanen, gagal }

class _WaktuLokasiCardState extends State<WaktuLokasiCard> {
  static const _hari = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  static const _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  Timer? _jam;
  DateTime _sekarang = DateTime.now();

  _Lokasi _status = _Lokasi.memuat;
  String? _tempat;
  String? _pesan;

  @override
  void initState() {
    super.initState();

    // Satu detik, bukan lebih jarang: jam yang menampilkan detik tetapi
    // hanya diperbarui tiap menit terlihat seperti aplikasi yang macet.
    _jam = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sekarang = DateTime.now());
    });

    _muatLokasi();
  }

  @override
  void dispose() {
    _jam?.cancel();
    super.dispose();
  }

  Future<void> _muatLokasi() async {
    setState(() {
      _status = _Lokasi.memuat;
      _pesan = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setStatus(_Lokasi.layananMati, 'Layanan lokasi di perangkat mati.');
        return;
      }

      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }

      if (izin == LocationPermission.deniedForever) {
        _setStatus(
          _Lokasi.ditolakPermanen,
          'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan aplikasi.',
        );
        return;
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.unableToDetermine) {
        _setStatus(_Lokasi.ditolak, 'Izin lokasi belum diberikan.');
        return;
      }

      // Akurasi `medium`, bukan `best`: yang ditampilkan hanya nama
      // kelurahan atau kota, dan menuntut akurasi GPS penuh membuat
      // pengambilan berlangsung jauh lebih lama sekaligus menguras baterai
      // demi ketepatan yang tidak dipakai.
      final posisi = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      // Koordinat dipasang lebih dulu sebagai cadangan. Bila penerjemahan
      // ke nama tempat gagal — biasanya karena jaringan — kartunya tetap
      // menampilkan sesuatu yang benar alih-alih pesan galat.
      var nama = '${posisi.latitude.toStringAsFixed(4)}, '
          '${posisi.longitude.toStringAsFixed(4)}';

      try {
        final tempat = await placemarkFromCoordinates(
          posisi.latitude,
          posisi.longitude,
        );
        if (tempat.isNotEmpty) {
          final p = tempat.first;
          final bagian = [
            p.subLocality,
            p.locality,
            p.subAdministrativeArea,
          ].where((s) => s != null && s.trim().isNotEmpty).cast<String>();

          // Duplikat dibuang: pada banyak wilayah `locality` dan
          // `subAdministrativeArea` mengembalikan teks yang sama, dan
          // hasilnya "Medan, Medan".
          final unik = <String>[];
          for (final b in bagian) {
            if (!unik.contains(b)) unik.add(b);
          }
          if (unik.isNotEmpty) nama = unik.take(2).join(', ');
        }
      } catch (_) {
        // Sengaja dibiarkan: koordinat sudah cukup.
      }

      if (!mounted) return;
      setState(() {
        _status = _Lokasi.siap;
        _tempat = nama;
      });
    } on TimeoutException {
      _setStatus(_Lokasi.gagal, 'Lokasi tidak terbaca. Coba di area terbuka.');
    } catch (_) {
      _setStatus(_Lokasi.gagal, 'Lokasi tidak terbaca.');
    }
  }

  void _setStatus(_Lokasi s, String pesan) {
    if (!mounted) return;
    setState(() {
      _status = s;
      _pesan = pesan;
    });
  }

  String get _tanggal {
    final d = _sekarang;
    return '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';
  }

  String get _waktu {
    final d = _sekarang;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Jam dibuat elemen terbesar. Pada aplikasi absensi, angka
              // inilah yang dicari mata lebih dulu.
              Text(
                _waktu,
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: ClayTheme.textStrong,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  Icons.schedule_rounded,
                  size: ClayTheme.icon,
                  color: ClayTheme.primary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _tanggal,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ClayTheme.textBody,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _barisLokasi(),
        ],
      ),
    );
  }

  Widget _barisLokasi() {
    final (ikon, warna, teks) = switch (_status) {
      _Lokasi.memuat => (
          Icons.my_location_rounded,
          ClayTheme.textMuted,
          'Mencari lokasi…',
        ),
      _Lokasi.siap => (
          Icons.location_on_rounded,
          ClayTheme.primary,
          _tempat ?? '-',
        ),
      _Lokasi.layananMati => (
          Icons.location_disabled_rounded,
          ClayTheme.warning,
          _pesan ?? 'Layanan lokasi mati.',
        ),
      _Lokasi.ditolak || _Lokasi.ditolakPermanen => (
          Icons.location_off_rounded,
          ClayTheme.warning,
          _pesan ?? 'Izin lokasi belum diberikan.',
        ),
      _Lokasi.gagal => (
          Icons.location_off_rounded,
          ClayTheme.textMuted,
          _pesan ?? 'Lokasi tidak terbaca.',
        ),
    };

    // Tindakan pemulihan berbeda menurut sebabnya. Menawarkan "Coba lagi"
    // pada izin yang ditolak permanen akan gagal berulang tanpa penjelasan:
    // satu-satunya jalan keluarnya ada di Pengaturan sistem.
    final Widget? aksi = switch (_status) {
      _Lokasi.memuat => const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      _Lokasi.ditolakPermanen => _AksiKecil(
          label: 'Pengaturan',
          onTap: () => Geolocator.openAppSettings(),
        ),
      _Lokasi.layananMati => _AksiKecil(
          label: 'Aktifkan',
          onTap: () => Geolocator.openLocationSettings(),
        ),
      _Lokasi.ditolak || _Lokasi.gagal => _AksiKecil(
          label: 'Coba lagi',
          onTap: _muatLokasi,
        ),
      _Lokasi.siap => null,
    };

    return Row(
      children: [
        Icon(ikon, size: ClayTheme.iconSmall, color: warna),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _status == _Lokasi.siap
                  ? ClayTheme.textBody
                  : ClayTheme.textMuted,
            ),
          ),
        ),
        if (aksi != null) ...[const SizedBox(width: 8), aksi],
      ],
    );
  }
}

class _AksiKecil extends StatelessWidget {
  const _AksiKecil({required this.label, required this.onTap});

  final String label;

  /// `VoidCallback`, bukan `Future<...> Function()`: pemanggilnya bercampur —
  /// `Geolocator.openAppSettings` mengembalikan `Future<bool>` sementara
  /// pemuatan ulang lokasi mengembalikan `Future<void>`. Satu tipe kembalian
  /// tidak akan cocok untuk keduanya, dan tak satu pun nilainya dipakai.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ClayTheme.primarySoft,
          borderRadius: BorderRadius.circular(ClayTheme.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ClayTheme.primary,
          ),
        ),
      ),
    );
  }
}
