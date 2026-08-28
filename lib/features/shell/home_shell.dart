import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';

import '../../core/failure.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../data/jargon_models.dart';
import '../../providers.dart';
import '../absensi/absensi_screen.dart';
import '../berkas/berkas_screen.dart';
import '../panic/panic_feed_screen.dart';
import 'beranda_tab.dart';
import 'profile_screen.dart';
import 'sidebar_menu.dart';
import 'server_settings_screen.dart';

/// Kerangka utama Jargon GO: beranda + tiga menu.
///
/// Menu yang muncul ditentukan `available_menus` dari server, bukan disimpulkan
/// dari peran di sisi aplikasi. Dengan begitu, menambah peran baru atau
/// mengubah izin di dashboard langsung berlaku tanpa merilis aplikasi baru —
/// penting untuk sistem yang dipakai ribuan sekolah dengan siklus pembaruan
/// aplikasi yang lambat.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// Kendali drawer dipegang di sini, BUKAN diambil lewat
  /// `ZoomDrawer.of(context)` dari dalam bilah navigasi.
  ///
  /// Bilah itu dibangun pada build method yang sama dengan `ZoomDrawer`,
  /// sehingga context yang dipakainya berada DI ATAS drawer dalam pohon
  /// widget — `ZoomDrawer.of` di sana mengembalikan null, dan tombolnya
  /// tidak melakukan apa pun tanpa satu pun pesan galat.
  final ZoomDrawerController _drawer = ZoomDrawerController();

  int _index = 0;
  HomeSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await ref.read(repositoryProvider).home();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat beranda: $e';
          _loading = false;
        });
      }
    }
  }

  /// Tab yang tersedia beserta layarnya, disusun dari izin akun.
  ({List<ClayNavItem> items, List<Widget> pages}) _buildTabs() {
    final summary = _summary;
    final items = <ClayNavItem>[
      const ClayNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Beranda',
      ),
    ];
    final pages = <Widget>[
      BerandaTab(summary: summary, onRefresh: _load),
    ];

    if (summary?.hasMenu('absensi') ?? false) {
      items.add(const ClayNavItem(
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        label: 'Absensi',
      ));
      pages.add(const AbsensiScreen());
    }

    if (summary?.hasMenu('panic_button') ?? false) {
      items.add(ClayNavItem(
        icon: Icons.campaign_outlined,
        activeIcon: Icons.campaign_rounded,
        label: 'Lapor',
        badge: summary?.panicUpdates ?? 0,
      ));
      pages.add(const PanicFeedScreen());
    }

    if (summary?.hasMenu('pemberkasan') ?? false) {
      items.add(ClayNavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder_rounded,
        label: 'Berkas',
        badge: summary?.documentActions ?? 0,
      ));
      pages.add(const BerkasScreen());
    }

    return (items: items, pages: pages);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final tabs = _buildTabs();

    // Bila jumlah tab menyusut (mis. izin dicabut lalu beranda dimuat ulang),
    // indeks lama bisa menunjuk tab yang sudah tidak ada.
    final index = _index.clamp(0, tabs.pages.length - 1);

    return ZoomDrawer(
      controller: _drawer,
      // Layar utama dimiringkan dan dikecilkan; sudut kecil (-5) dipilih
      // karena sudut besar membuat teks di tepi kanan terlihat terdistorsi
      // pada layar ponsel kecil.
      angle: -5,
      mainScreenScale: 0.14,
      slideWidth: MediaQuery.of(context).size.width * 0.74,
      borderRadius: 30,
      showShadow: true,
      menuBackgroundColor: ClayTheme.sidebarBg,
      drawerShadowsBackgroundColor: ClayTheme.surface,
      // Gestur geser dimatikan: layar Absensi dan Lapor punya daftar yang
      // digulir, dan gestur drawer akan merebut sentuhan itu.
      disableDragGesture: true,

      // Ketuk di mana pun untuk menutup — di layar utama maupun di area
      // kosong sidebar. Tanpa dua opsi ini, drawer hanya bisa ditutup dengan
      // memilih salah satu menu, dan pengguna yang cuma ingin melihat
      // daftarnya lalu kembali menjadi terjebak.
      //
      // Aman terhadap salah sentuh: `mainScreenAbsorbPointer` bawaan paket
      // bernilai true, dan GestureDetector penutupnya dipasang DI LUAR
      // AbsorbPointer itu — jadi ketukan menutup drawer tanpa menembus ke
      // tombol yang ada di bawahnya.
      //
      // Ketukan pada baris menu dan pemilih tema tetap bekerja seperti
      // biasa: GestureDetector di dalamnya memenangkan gesture arena lebih
      // dulu. Pemilih tema sengaja TIDAK menutup drawer, supaya perubahan
      // temanya langsung terlihat dan bisa dikembalikan.
      mainScreenTapClose: true,
      menuScreenTapClose: true,

      // Tombol kembali Android menutup drawer, bukan keluar dari aplikasi.
      androidCloseOnBackTap: true,
      menuScreen: SidebarMenu(
        nama: user?.name ?? 'Pengguna',
        // Label peran diambil dari server (`role_label`), bukan dipetakan
        // di klien. Pemetaan di klien akan tertinggal setiap kali peran baru
        // ditambahkan di dashboard — dan sekarang perannya jadi delapan.
        peran: _summary?.roleLabel ?? user?.roleLabel ?? 'Jargon GO',
        aktif: index,
        onTutup: () => _drawer.close?.call(),
        gelap: ref.watch(temaGelapProvider),
        onGantiTema: (gelap) {
          // Disimpan DAN dipasang ke state provider. Menyimpan saja tidak
          // mengubah tampilan sampai aplikasi dibuka lagi; menyetel provider
          // saja membuat pilihannya hilang setelah aplikasi ditutup.
          ref.read(storageProvider).simpanTemaGelap(gelap);
          ref.read(temaGelapProvider.notifier).state = gelap;
        },
        onPilihTab: (i) => setState(() => _index = i),
        tab: [
          for (final it in tabs.items)
            SidebarItem(
              icon: it.activeIcon,
              label: it.label,
              badge: it.badge,
            ),
        ],
        lainnya: [
          SidebarItem(
            icon: Icons.person_outline_rounded,
            label: 'Profil Saya',
            keterangan: 'Lengkapi data diri',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          SidebarItem(
            icon: Icons.dns_outlined,
            label: 'Alamat Server',
            keterangan: 'Untuk pengujian jaringan',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
            ),
          ),
        ],
      ),
      mainScreen: Scaffold(
      appBar: AppBar(
        // Tombol sidebar di ATAS, pada posisi leading — tempat yang memang
        // dicari orang untuk menu. Sebelumnya ditaruh di bilah bawah agar
        // tetap terlihat saat digulir, tetapi itu menempatkannya di tempat
        // yang tidak lazim: bilah bawah dibaca sebagai perpindahan tab,
        // bukan sebagai pembuka menu.
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 18),
          child: ClaySurface(
            radius: ClayTheme.radiusPill,
            padding: const EdgeInsets.all(10),
            depth: 0.7,
            onTap: () => _drawer.toggle?.call(),
            child: Icon(
              Icons.menu_rounded,
              size: ClayTheme.icon,
              color: ClayTheme.primary,
            ),
          ),
        ),
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _summary?.greeting ?? 'Jargon GO',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ClayTheme.textStrong,
              ),
            ),
            Text(
              _summary?.roleLabel ?? user?.roleLabel ?? '',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ClayTheme.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: ClaySurface(
              radius: ClayTheme.radiusPill,
              padding: const EdgeInsets.all(10),
              depth: 0.7,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: ClayTheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ClayEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: 'Tidak dapat memuat data',
                  message: _error,
                  action: ClayButton(
                    label: 'Coba Lagi',
                    icon: Icons.refresh_rounded,
                    expanded: false,
                    onPressed: _load,
                  ),
                )
              : IndexedStack(index: index, children: tabs.pages),
      bottomNavigationBar: _loading || _error != null || tabs.items.length < 2
          ? null
          : ClayNavBar(
              items: tabs.items,
              currentIndex: index,
              onSelected: (i) => setState(() => _index = i),
            ),
      ),
    );
  }
}

