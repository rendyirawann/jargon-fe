import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_config.dart';
import 'core/storage.dart';
import 'core/theme/clay_theme.dart';
import 'data/offline_queue.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/home_shell.dart';
import 'providers.dart';

/// **Jargon GO** — Super Apps Dinas Pendidikan Provinsi Sumatera Utara.
///
/// Satu aplikasi untuk beberapa peran yang sangat berbeda:
///   * siswa & orang tua : memantau absensi, mengirim pengaduan
///   * guru & staff      : memantau kelas, mengurus pemberkasan
///   * tablet sekolah    : mode kios absensi wajah (lewat menu Profil)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  // Bilah status menyatu dengan latar clay; ikonnya digelapkan karena
  // latarnya terang.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: ClayTheme.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Storage dan antrean offline dibuka SEBELUM aplikasi berjalan, lalu
  // di-override ke dalam graf provider — tidak ada layar yang perlu
  // menangani keadaan "belum siap".
  final storage = await Storage.open();
  final queue = await OfflineQueue.open();

  // Alamat server pilihan pengguna dipulihkan SEBELUM aplikasi berjalan,
  // supaya request pertama pun sudah menuju server yang benar. Tanpa ini,
  // pemulihan sesi di layar pertama akan menembak alamat bawaan build.
  ApiConfig.load(storage);

  runApp(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        offlineQueueProvider.overrideWithValue(queue),
      ],
      child: const JargonApp(),
    ),
  );
}

class JargonApp extends ConsumerWidget {
  const JargonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sesi sebelumnya dipulihkan dari secure storage, sehingga pengguna tidak
    // perlu login ulang setiap membuka aplikasi.
    final user = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'Jargon GO',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ClayTheme.build(),
      home: user == null ? const LoginScreen() : const HomeShell(),
    );
  }
}
