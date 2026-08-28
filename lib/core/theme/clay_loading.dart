import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'clay_theme.dart';

/// Balok kosong berkilau, seukuran isi yang sedang dimuat.
///
/// MENGAPA KERANGKA, BUKAN SPINNER
///
/// Spinner memberi tahu bahwa sesuatu sedang berlangsung, tetapi tidak
/// memberi tahu APA. Kerangka yang berbentuk seperti kartu aslinya membuat
/// halaman tidak "melompat" begitu data tiba — tata letaknya sudah benar
/// sejak detik pertama, hanya isinya yang menyusul.
class ClaySkeleton extends StatelessWidget {
  const ClaySkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Warna solid, bukan transparan: `Shimmer` mewarnai ulang seluruh
        // anaknya lewat gradient mask, dan bentuk yang tembus pandang tidak
        // akan ikut terwarnai sehingga tidak terlihat berkilau sama sekali.
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Pembungkus kilau dengan warna tema gelap.
///
/// `baseColor` diambil dari `surface`, bukan warna abu-abu bawaan paket:
/// kerangka abu-abu di atas latar biru malam terlihat seperti elemen dari
/// aplikasi lain.
class ClayShimmer extends StatelessWidget {
  const ClayShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ClayTheme.surface,
      highlightColor: const Color(0xFF2A3A63),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Kerangka beranda: satu kartu waktu + dua kartu isi.
class ClayBerandaSkeleton extends StatelessWidget {
  const ClayBerandaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ClayShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _kartu(tinggi: 118),
          const SizedBox(height: 20),
          const ClaySkeleton(width: 120, height: 11),
          const SizedBox(height: 14),
          _kartu(tinggi: 96),
          const SizedBox(height: 14),
          _kartu(tinggi: 96),
        ],
      ),
    );
  }

  Widget _kartu({required double tinggi}) => Container(
        height: tinggi,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ClayTheme.radius),
        ),
      );
}

/// Tarik-ke-bawah bergaya claymorphism.
///
/// `RefreshIndicator` bawaan menggambar lingkaran Material yang bentuknya
/// tidak dapat diubah; di tengah tema ini ia terlihat seperti tempelan dari
/// aplikasi lain. Paket `custom_refresh_indicator` memberi kendali penuh
/// atas apa yang digambar, dengan imbalan indikatornya harus disusun sendiri.
class ClayRefresh extends StatelessWidget {
  const ClayRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      // Jarak tarik sebelum penyegaran terpicu. Nilai bawaan paket terasa
      // terlalu pendek pada daftar panjang: pengguna yang menggulir cepat ke
      // atas akan memicu penyegaran tanpa sengaja.
      offsetToArmed: 96,
      builder: (context, anak, kendali) {
        return AnimatedBuilder(
          animation: kendali,
          builder: (context, _) {
            final v = kendali.value.clamp(0.0, 1.4);

            return Stack(
              children: [
                // Indikator digambar DI BELAKANG isi, lalu isinya digeser
                // turun. Dengan begitu indikator terlihat "keluar dari balik"
                // halaman, bukan menimpanya.
                Positioned(
                  top: 10 + 14 * v,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: _Indikator(
                        maju: v,
                        memuat: kendali.isLoading,
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, 72 * v),
                  child: anak,
                ),
              ],
            );
          },
        );
      },
      child: child,
    );
  }
}

class _Indikator extends StatelessWidget {
  const _Indikator({required this.maju, required this.memuat});

  final double maju;
  final bool memuat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ClayTheme.surface,
        shape: BoxShape.circle,
        boxShadow: ClayTheme.raised(depth: 0.6),
      ),
      child: memuat
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Transform.rotate(
              // Panah ikut berputar mengikuti tarikan, jadi gerakannya
              // memberi tahu seberapa jauh lagi sebelum terpicu.
              angle: maju * 3.14159,
              child: Icon(
                Icons.arrow_downward_rounded,
                size: ClayTheme.iconSmall,
                color: maju >= 1 ? ClayTheme.primary : ClayTheme.textMuted,
              ),
            ),
    );
  }
}
