import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _summary?.greeting ?? 'Jargon GO',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ClayTheme.textStrong,
              ),
            ),
            Text(
              _summary?.roleLabel ?? user?.roleLabel ?? '',
              style: const TextStyle(
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
              child: const Icon(
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
    );
  }
}
