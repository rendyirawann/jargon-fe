import 'package:flutter/material.dart';

import 'kiosk_screen.dart';

/// Buka mode kios pada Android/iOS. Lihat `kiosk_entry.dart` untuk alasan
/// pemisahan ini.
Future<void> openKiosk(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const KioskScreen()),
  );
}

/// Mode kios tersedia di platform ini.
const bool kioskSupported = true;
