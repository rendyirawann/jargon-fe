import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/failure.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../providers.dart';
import '../shell/home_shell.dart';
import '../shell/server_settings_screen.dart';

/// Masuk ke Jargon GO.
///
/// Tidak ada pendaftaran mandiri: seluruh akun dibuat operator sekolah atau
/// Dinas. Karena itu layar ini tidak punya tautan "daftar" — yang ada justru
/// penjelasan ke mana harus menghubungi bila akun belum ada.
///
/// Satu kotak isian untuk dua jenis identitas (NISN 10 digit untuk siswa,
/// NIK 16 digit untuk selainnya). Memaksa pengguna memilih jenis identitas
/// lebih dulu hanya menambah langkah: panjang angkanya sudah cukup untuk
/// membedakan, dan server yang memutuskan.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identity = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Petunjuk yang berubah mengikuti panjang angka yang diketik — membantu
  /// pengguna menyadari salah kotak sebelum menekan Masuk.
  String get _identityHint {
    final v = _identity.text.trim();
    if (v.isEmpty) return 'NIK (16 digit) atau NISN siswa (10 digit)';
    if (v.length == 10) return 'Terdeteksi NISN — akun siswa';
    if (v.length == 16) return 'Terdeteksi NIK';
    if (v.length < 10) return 'Kurang ${10 - v.length} digit lagi untuk NISN';
    if (v.length < 16) return 'Kurang ${16 - v.length} digit lagi untuk NIK';
    return 'Terlalu panjang — NIK maksimal 16 digit';
  }

  Future<void> _submit() async {
    if (_identity.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Isi NIK/NISN dan kata sandi terlebih dahulu.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final profile =
          await ref.read(repositoryProvider).login(_identity.text, _password.text);

      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = profile;

      if (profile.mustChangePassword) {
        showClaySnack(
          context,
          'Kata sandi Anda masih bawaan. Segera ganti melalui menu Profil.',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal masuk: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // --- Identitas aplikasi ---
                  Center(
                    child: ClaySurface(
                      radius: 34,
                      padding: const EdgeInsets.all(24),
                      depth: 1.25,
                      child: Icon(
                        Icons.school_rounded,
                        size: 48,
                        color: ClayTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Jargon GO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ClayTheme.textStrong,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Super Apps Dinas Pendidikan\nProvinsi Sumatera Utara',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ClayTheme.textMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 34),

                  // --- Formulir ---
                  ClayField(
                    controller: _identity,
                    label: 'NIK / NISN',
                    hint: 'Masukkan nomor identitas',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    enabled: !_busy,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: ClayTheme.textStrong,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 7),
                    child: Text(
                      _identityHint,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _identity.text.trim().length == 10 ||
                                _identity.text.trim().length == 16
                            ? ClayTheme.success
                            : ClayTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  ClayField(
                    controller: _password,
                    label: 'Kata Sandi',
                    hint: 'Kata sandi akun',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    enabled: !_busy,
                    onSubmitted: (_) => _busy ? null : _submit(),
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                        color: ClayTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    ClaySurface(
                      color: ClayTheme.dangerSoft,
                      radius: ClayTheme.radiusSmall,
                      depth: 0.6,
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: ClayTheme.danger, size: 19),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: ClayTheme.danger,
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 26),
                  ClayButton(
                    label: 'Masuk',
                    icon: Icons.arrow_forward_rounded,
                    busy: _busy,
                    onPressed: _busy ? null : _submit,
                  ),

                  const SizedBox(height: 30),

                  // --- Penjelasan tidak ada pendaftaran mandiri ---
                  ClaySurface(
                    sunken: true,
                    radius: ClayTheme.radiusSmall,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: ClayTheme.textMuted),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Akun didaftarkan oleh operator sekolah, bukan mandiri. '
                            'Bila belum memiliki akun atau lupa kata sandi, hubungi '
                            'operator/Tata Usaha sekolah Anda.',
                            style: TextStyle(
                              color: ClayTheme.textMuted,
                              fontSize: 11.5,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Alamat server ---
                  //
                  // Ditaruh di layar login, bukan hanya di Profil: kalau
                  // alamatnya salah, pengguna TIDAK BISA masuk — jadi layar
                  // Profil (yang ada di balik login) tidak akan pernah
                  // terjangkau untuk memperbaikinya.
                  const SizedBox(height: 14),
                  Center(
                    child: ClayGhostButton(
                      label: ref.watch(apiBaseUrlProvider),
                      icon: Icons.dns_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const ServerSettingsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
