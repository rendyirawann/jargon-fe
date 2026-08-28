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
    this.gelap = true,
    this.onGantiTema,
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

  /// Tema yang sedang aktif, untuk menandai pilihan mana yang terpilih.
  final bool gelap;

  /// Bila null, pemilih tema tidak digambar sama sekali.
  final ValueChanged<bool>? onGantiTema;

  @override
  Widget build(BuildContext context) {
    // MATERIAL WAJIB DI SINI, BUKAN HIASAN.
    //
    // `flutter_zoom_drawer` menempatkan `menuScreen` langsung di dalam Stack
    // tanpa membungkusnya Material — sudah diperiksa di sumber paketnya
    // (versi 3.2.0): tidak ada satu pun pemanggilan `Material(` di seluruh
    // pustakanya.
    //
    // Akibatnya setiap `Text` di sini kehilangan gaya teks bawaan dan
    // dirender dengan penanda debug Flutter: garis bawah ganda berwarna
    // KUNING. Itu bukan salah warna tema — itu Flutter memberi tahu bahwa
    // teksnya berada di luar Material.
    return Material(
      color: ClayTheme.sidebarBg,
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
              if (onGantiTema != null)
                _PilihTema(gelap: gelap, onGanti: onGantiTema!),
              const SizedBox(height: 12),
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
                style: TextStyle(
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
                style: TextStyle(
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
          style: TextStyle(
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
        color: terpilih ? ClayTheme.surface : ClayTheme.sidebarRow,
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
                      style: TextStyle(
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


/// Pemilih tema: dua tombol, bukan satu switch.
///
/// Switch hanya menyatakan "menyala / mati" — dan pengguna harus menebak mana
/// yang menyala. Dua tombol berlabel menampilkan KEDUA pilihan sekaligus,
/// dengan yang aktif digambar tenggelam.
class _PilihTema extends StatelessWidget {
  const _PilihTema({required this.gelap, required this.onGanti});

  final bool gelap;
  final ValueChanged<bool> onGanti;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tombol(
            ikon: Icons.light_mode_rounded,
            label: 'Terang',
            aktif: !gelap,
            onTap: () => onGanti(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tombol(
            ikon: Icons.dark_mode_rounded,
            label: 'Gelap',
            aktif: gelap,
            onTap: () => onGanti(true),
          ),
        ),
      ],
    );
  }
}

class _Tombol extends StatelessWidget {
  const _Tombol({
    required this.ikon,
    required this.label,
    required this.aktif,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      sunken: aktif,
      depth: 0.5,
      radius: ClayTheme.radiusSmall,
      color: aktif ? ClayTheme.primarySoft : ClayTheme.sidebarRow,
      padding: const EdgeInsets.symmetric(vertical: 10),
      onTap: aktif ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikon,
            size: ClayTheme.icon,
            color: aktif ? ClayTheme.primary : ClayTheme.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
              color: aktif ? ClayTheme.primary : ClayTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
