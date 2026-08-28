import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../providers.dart';
import '../auth/login_screen.dart';
import '../kiosk/kiosk_entry.dart';
import '../pairing/pairing_screen.dart';
import 'server_settings_screen.dart';

/// Profil pengguna + akses mode kios.
///
/// Mode kios (tablet absensi wajah) sengaja ditaruh di sini, bukan di menu
/// utama: hanya segelintir perangkat yang dipasang sebagai kios, sementara
/// ribuan pengguna lain memakai aplikasi yang sama sebagai aplikasi biasa.
/// Menaruhnya di menu utama akan membuat siswa mengira mereka bisa absen dari
/// ponsel sendiri.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final deviceProfile = ref.watch(deviceProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ClaySurface(
            child: Column(
              children: [
                ClaySurface(
                  radius: ClayTheme.radiusPill,
                  color: ClayTheme.primarySoft,
                  padding: const EdgeInsets.all(22),
                  depth: 0.8,
                  child: Icon(Icons.person_rounded,
                      size: 38, color: ClayTheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ClayTheme.textStrong,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ClayBadge(
                  label: user?.roleLabel ?? 'Pengguna',
                  color: ClayTheme.primary,
                ),
                if (user?.schoolName != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    user!.schoolName!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ClayTheme.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          ClayCard(
            title: 'Identitas',
            child: Column(
              children: [
                _Row(
                  label: user?.identityLabel ?? 'NIK',
                  value: user?.identityNumber ?? '-',
                ),
                _Row(label: 'Nama Pengguna', value: user?.username ?? '-'),
              ],
            ),
          ),

          // --- Siswa yang tertaut ---
          if ((user?.students.length ?? 0) > 0) ...[
            const SizedBox(height: 16),
            ClayCard(
              title: user!.isStudent ? 'Data Siswa' : 'Anak yang Tertaut',
              child: Column(
                children: user.students
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const ClayIcon(
                                icon: Icons.school_rounded,
                                size: 17,
                                padding: 10,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.fullName,
                                      style: TextStyle(
                                        color: ClayTheme.textStrong,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        s.classroomName ?? 'Tanpa kelas',
                                        s.schoolName,
                                        if (s.nisn != null) 'NISN ${s.nisn}',
                                      ].join(' · '),
                                      style: TextStyle(
                                        color: ClayTheme.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (s.relation != 'diri_sendiri')
                                ClayBadge(
                                  label: s.relation,
                                  color: ClayTheme.secondary,
                                ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          // --- Mode kios ---
          const SizedBox(height: 16),
          ClayCard(
            title: 'Mode Kios (Tablet Sekolah)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  deviceProfile == null
                      ? 'Perangkat ini belum dipasangkan sebagai tablet absensi. '
                          'Absensi wajah hanya dilakukan pada tablet yang '
                          'terpasang di sekolah.'
                      : 'Terpasang di ${deviceProfile['school_name']} '
                          '(${deviceProfile['device_code']}).',
                  style: TextStyle(
                    color: ClayTheme.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                if (deviceProfile == null)
                  ClayGhostButton(
                    label: 'Pasangkan Perangkat',
                    icon: Icons.link_rounded,
                    compact: false,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PairingScreen()),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: ClayButton(
                          label: 'Buka Kios',
                          icon: Icons.center_focus_strong_rounded,
                          compact: true,
                          onPressed: () => openKiosk(context),
                        ),
                      ),
                      const SizedBox(width: 11),
                      ClayGhostButton(
                        label: 'Lepas',
                        icon: Icons.link_off_rounded,
                        color: ClayTheme.danger,
                        onPressed: () async {
                          await ref.read(storageProvider).clearDevice();
                          ref.read(deviceProfileProvider.notifier).state = null;
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          ClayCard(
            title: 'Aplikasi',
            child: Column(
              children: [
                const _Row(label: 'Nama', value: 'Jargon GO'),
                const _Row(label: 'Versi', value: '1.0.0'),
                _Row(label: 'Server', value: ref.watch(apiBaseUrlProvider)),
                const SizedBox(height: 4),
                // Alamat server bisa diubah tanpa membangun ulang aplikasi;
                // selama pengembangan ia berganti berkali-kali dalam sehari.
                ClayGhostButton(
                  label: 'Ubah Alamat Server',
                  icon: Icons.dns_rounded,
                  compact: false,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ServerSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          ClayButton(
            label: 'Keluar',
            icon: Icons.logout_rounded,
            color: ClayTheme.dangerSoft,
            textColor: ClayTheme.danger,
            onPressed: () async {
              await ref.read(repositoryProvider).logout();
              ref.read(currentUserProvider.notifier).state = null;
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: TextStyle(
                  color: ClayTheme.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: ClayTheme.textStrong,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
