import 'package:flutter/material.dart';

import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';

/// Satu baris di panel menu.
class MenuPanelItem {
  const MenuPanelItem({
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

  /// Bila null, baris ditutup lalu indeksnya dikembalikan ke pemanggil.
  /// Dipakai untuk menu yang berupa tab; menu lain memakai [onTap].
  final VoidCallback? onTap;
}

/// Panel menu yang muncul dari bawah.
///
/// MENGAPA PANEL BAWAH, BUKAN DRAWER
///
/// Drawer Material menggeser seluruh layar dari samping dan menuntut tangan
/// menjangkau tepi kiri atas — pada ponsel besar itu di luar jangkauan jempol.
/// Panel bawah muncul tepat di dekat tombol yang membukanya.
///
/// Nilai kembaliannya adalah indeks tab yang dipilih, atau null bila panel
/// ditutup tanpa memilih apa pun. Menu yang bukan tab menjalankan [onTap]
/// miliknya sendiri dan mengembalikan null.
Future<int?> showMenuPanel({
  required BuildContext context,
  required List<MenuPanelItem> menu,
  required int aktif,
  List<MenuPanelItem> lainnya = const [],
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    // Panel bisa lebih tinggi dari setengah layar bila menunya banyak;
    // tanpa ini isinya terpotong tanpa bisa digulir.
    isScrollControlled: true,
    builder: (_) => _PanelMenu(menu: menu, aktif: aktif, lainnya: lainnya),
  );
}

class _PanelMenu extends StatelessWidget {
  const _PanelMenu({
    required this.menu,
    required this.aktif,
    required this.lainnya,
  });

  final List<MenuPanelItem> menu;
  final int aktif;
  final List<MenuPanelItem> lainnya;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: ClayTheme.surface,
          borderRadius: BorderRadius.circular(ClayTheme.radius),
          boxShadow: ClayTheme.raised(depth: 1.4),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pegangan geser. Satu-satunya petunjuk bahwa panel ini bisa
              // ditarik turun untuk ditutup.
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ClayTheme.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: ClayTheme.textMuted,
                  ),
                ),
              ),
              for (var i = 0; i < menu.length; i++)
                _Baris(
                  item: menu[i],
                  terpilih: i == aktif,
                  onTap: () => Navigator.of(context).pop(i),
                ),
              if (lainnya.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'LAINNYA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: ClayTheme.textMuted,
                    ),
                  ),
                ),
                for (final item in lainnya)
                  _Baris(
                    item: item,
                    terpilih: false,
                    onTap: () {
                      // Panel ditutup LEBIH DULU, baru aksinya dijalankan.
                      // Bila urutannya dibalik, aksi yang membuka halaman
                      // baru akan langsung tertutup oleh pop panel ini.
                      Navigator.of(context).pop();
                      item.onTap?.call();
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.item,
    required this.terpilih,
    required this.onTap,
  });

  final MenuPanelItem item;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClaySurface(
        // Menu yang sedang aktif digambar TENGGELAM. Pada claymorphism itu
        // satu-satunya cara menyatakan "kamu sudah di sini" tanpa menambah
        // garis tepi atau warna latar yang mencolok.
        sunken: terpilih,
        depth: terpilih ? 0.7 : 0.55,
        radius: ClayTheme.radiusSmall,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: terpilih ? ClayTheme.primary : ClayTheme.primarySoft,
                borderRadius: BorderRadius.circular(ClayTheme.radiusSmall - 6),
              ),
              child: Icon(
                item.icon,
                size: ClayTheme.icon,
                color: terpilih ? Colors.white : ClayTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: terpilih ? FontWeight.w800 : FontWeight.w700,
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
                        fontSize: 11.5,
                        color: ClayTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.badge > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ClayTheme.danger,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  item.badge > 9 ? '9+' : '${item.badge}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: ClayTheme.iconSmall,
                color: ClayTheme.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
