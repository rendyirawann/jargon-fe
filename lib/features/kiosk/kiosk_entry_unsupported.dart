import 'package:flutter/material.dart';

import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';

/// Mode kios tidak tersedia di platform ini (web).
const bool kioskSupported = false;

/// Jelaskan mengapa kios tidak bisa dibuka, alih-alih membuka layar yang pasti
/// gagal.
///
/// Pengenalan wajah membutuhkan kamera perangkat, ML Kit, dan model TFLite.
/// Ketiganya tidak ada di browser. Menampilkan layar kios yang kameranya hitam
/// akan terlihat seperti kerusakan; halaman ini menyatakan batasnya terang
/// benderang.
Future<void> openKiosk(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: ClayTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ClayTheme.radius),
      ),
      title: const Text('Mode Kios Butuh Perangkat'),
      content: const Text(
        'Absensi wajah memerlukan kamera, ML Kit, dan model TFLite yang hanya '
        'tersedia di aplikasi Android/iOS.\n\n'
        'Debug di browser dipakai untuk menguji menu Absensi, Panic Button, '
        'dan Pemberkasan. Untuk menguji kios, jalankan aplikasi di tablet '
        'atau emulator Android.',
        style: TextStyle(height: 1.5, fontSize: 13),
      ),
      actions: [
        ClayGhostButton(
          label: 'Mengerti',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
