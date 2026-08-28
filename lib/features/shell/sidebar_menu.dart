import 'package:flutter/material.dart';

import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';

/// Satu entri di sidebar.
class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.label,
    this.keterangan,
    this.badge = 0,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? keterangan;
  final int badge;

  /// Diisi hanya untuk entri yang BUKAN tab (Profil, Alamat Server, Keluar).
  /// Entri tab tidak memakainya — indeksnya dikembalikan lewat `onPilihTab`.
  final VoidCallback? onTap;
}

/// Layar menu di balik layar utama, ditampilkan `ZoomDrawer`.
///
/// MENGAPA LATARNYA LEBIH GELAP DARI HALAMAN
///
/// `ZoomDrawer` memiringkan dan mengecilkan layar utama, lalu meletakkannya
/// DI ATAS layar ini. Bila keduanya sewarna, tidak ada yang menandai mana
/// yang di depan — dan pada claymorphism gelap, bayangan saja tidak cukup
/// karena seluruh paletnya sudah gelap. Latar sidebar dibuat satu tingkat
/// lebih gelap dari `background` supaya kedalamannya terbaca.
class SidebarMenu extends StatelessWidget {
  const SidebarMenu({
    super.key,
    required this.nama,
    required this.peran,
    required this.tab,
    required this.aktif,
    required this.onPilihTab,
    required this.onTutup,
    this.lainnya = const [],
  });

  final String nama;
  final String peran;
  final List<SidebarItem> tab;
  final int aktif;
  final ValueChanged<int> onPilihTab;

  /// Menutup drawer. Diberikan pemanggil alih-alih memanggil
  /// `ZoomDrawer.of(context)` dari sini.
  ///
  /// Alasannya bukan kerapian: `ZoomDrawer.of` mengembalikan null bila
  /// context-nya bukan turunan ZoomDrawer, dan kegagalannya SUNYI — menu
  /// tetap berpindah tab sementara drawer-nya menggantung terbuka. Callback
  /// dari pemanggil tidak punya mode gagal itu.
  final VoidCallback onTutup;

  final List<SidebarItem> lainnya;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1424),
      child: SafeArea(
        child: Padding(
          // Padding kanan lebih besar: sisi itu tertutup layar utama yang
          // dimiringkan, jadi isi yang terlalu ke kanan akan tersembunyi.
          padding: const EdgeInsets.fromLTRB(20, 24, 44, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Identitas(nama: nama, peran: peran),
              const SizedBox(height: 22),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const _Label('MENU'),
                    for (var i = 0; i < tab.length; i++)
                      _Baris(
                        item: tab[i],
                        terpilih: i == aktif,
                        onTap: () {
                          // Drawer ditutup LEBIH DULU. Bila urutannya
                          // dibalik, perpindahan tab terjadi di belakang
                          // drawer yang masih terbuka dan pengguna tidak
                          // melihat apa pun berubah.
                          onTutup();
                          onPilihTab(i);
                        },
                      ),
                    if (lainnya.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const _Label('LAINNYA'),
                      for (final item in lainnya)
                        _Baris(
                          item: item,
                          terpilih: false,
                          onTap: () {
                            onTutup();
                            item.onTap?.call();
                          },
                        ),
                    ],
                  ],
                ),
              ),
              Text(
                'Jargon GO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: ClayTheme.textMuted.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Identitas extends StatelessWidget {
  const _Identitas({required this.nama, required this.peran});

  final String nama;
  final String peran;

  @override
  Widget build(BuildContext context) {
    // Inisial, bukan foto. Foto profil belum ada di data akun, dan
    // placeholder orang abu-abu terlihat seperti data yang gagal dimuat.
    final inisial = nama.trim().isEmpty
        ? '?'
        : nama
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ClayTheme.primary,
            borderRadius: BorderRadius.circular(ClayTheme.radiusSmall),
          ),
          child: Text(
            inisial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ClayTheme.textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                peran,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ClayTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          teks,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: ClayTheme.textMuted,
          ),
        ),
      );
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.item,
    required this.terpilih,
    required this.onTap,
  });

  final SidebarItem item;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClaySurface(
        // Menu aktif digambar TENGGELAM — pada claymorphism itu satu-satunya
        // cara menyatakan "kamu sudah di sini" tanpa garis tepi atau blok
        // warna yang merusak kesan permukaan lunak.
        sunken: terpilih,
        depth: terpilih ? 0.7 : 0.5,
        radius: ClayTheme.radiusSmall,
        color: terpilih ? ClayTheme.surface : const Color(0xFF16203A),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              item.icon,
              size: ClayTheme.icon,
              color: terpilih ? ClayTheme.primary : ClayTheme.textBody,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                      color: terpilih
                          ? ClayTheme.primary
                          : ClayTheme.textStrong,
                    ),
                  ),
                  if (item.keterangan != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.keterangan!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ClayTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ClayTheme.danger,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  item.badge > 9 ? '9+' : '${item.badge}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
