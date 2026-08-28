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
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
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

/// Kunci navigator global, dipakai saat sesi berakhir.
///
/// MENGAPA PERLU, PADAHAL SUDAH ADA `currentUserProvider`
///
/// Sesi bisa berakhir di kedalaman mana pun — di dalam Absensi, Pemberkasan,
/// atau sebuah dialog — dan klien HTTP yang mendeteksinya tidak punya
/// BuildContext.
///
/// Menyetel `currentUserProvider` ke null saja TIDAK cukup: layar login
/// memakai `pushReplacement` (login_screen.dart), sehingga rute yang memegang
/// `home:` sudah tidak ada lagi di stack setelah login pertama. Mengubah nilai
/// yang dibaca `home:` tidak memindahkan siapa pun — layarnya diam, hanya
/// kartu galatnya yang tinggal. Tombol Keluar bekerja justru karena ia
/// memanggil `pushAndRemoveUntil` sendiri; di sini hal yang sama diperlukan.
final navigatorKey = GlobalKey<NavigatorState>();

class JargonApp extends ConsumerStatefulWidget {
  const JargonApp({super.key});

  @override
  ConsumerState<JargonApp> createState() => _JargonAppState();
}

class _JargonAppState extends ConsumerState<JargonApp> {
  @override
  void initState() {
    super.initState();

    // Ketika penyegaran token gagal — refresh token dicabut, kedaluwarsa,
    // atau akunnya dinonaktifkan — klien HTTP membersihkan sesi lokal lalu
    // memanggil ini. Profil disetel ke null DAN stack navigasi dikosongkan —
    // keduanya perlu, alasannya ada di doc `navigatorKey` di atas.
    //
    // Dipasang di initState, bukan di build: build berjalan setiap kali
    // sesuatu berubah, dan menyetel callback di sana menaruh efek samping di
    // tempat yang seharusnya murni.
    ref.read(apiClientProvider).onSessionExpired = () {
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = null;

      // Kosongkan seluruh stack, persis seperti tombol Keluar. Tanpa ini
      // pengguna tertinggal di layar yang baru saja gagal memuat, dengan
      // tombol "Coba Lagi" yang tidak mungkin berhasil lagi.
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    // Sesi sebelumnya dipulihkan dari secure storage, sehingga pengguna tidak
    // perlu login ulang setiap membuka aplikasi.
    final user = ref.watch(currentUserProvider);

    // Tema dipasang ke state statis SEBELUM `ClayTheme.build()` di bawah
    // membacanya.
    //
    // Ya, ini efek samping di dalam build — dan itu disengaja. Warna dibaca
    // lewat getter statis oleh 298 tempat di aplikasi, jadi nilai statis itu
    // harus sudah benar sebelum satu pun widget dibangun. Menaruhnya di
    // initState tidak cukup: build inilah yang berjalan ulang ketika
    // penggunanya mengganti tema.
    final gelap = ref.watch(temaGelapProvider);
    ClayTheme.pakai(gelap: gelap);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Ikon bilah status harus BERLAWANAN dengan latar: terang di tema
      // gelap, gelap di tema terang. Nilai yang dipasang sekali di `main()`
      // menjadi salah begitu tema bisa diganti saat berjalan.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: gelap ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: ClayTheme.background,
        systemNavigationBarIconBrightness:
            gelap ? Brightness.light : Brightness.dark,
      ),
      child: MaterialApp(
      title: 'Jargon GO',
      navigatorKey: navigatorKey,
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
      ),
    );
  }
}
