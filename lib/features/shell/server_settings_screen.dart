import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../providers.dart';

/// Ubah alamat server API tanpa membangun ulang aplikasi.
///
/// Selama pengembangan, alamat server berganti berkali-kali dalam sehari:
/// `localhost` saat debug web, `10.0.2.2` di emulator, IP laptop saat menguji
/// dari ponsel di jaringan sekolah. Membangun ulang APK setiap kali membuat
/// pengujian lapangan jauh lebih lambat daripada perlunya.
///
/// Alamat diuji lebih dulu ke `/health` sebelum disimpan. Menyimpan alamat
/// yang salah lalu menemukannya saat gagal login akan menyesatkan — pengguna
/// akan mengira kata sandinya yang keliru.
class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  late final TextEditingController _url =
      TextEditingController(text: ApiConfig.baseUrl);

  bool _busy = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final invalid = ApiConfig.validationError(_url.text);
    if (invalid != null) {
      setState(() {
        _error = invalid;
        _ok = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });

    final target = ApiConfig.normalize(_url.text);
    final failure = await ApiClient.ping(target);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
      _ok = failure == null ? 'Server merespons di $target.' : null;
    });
  }

  Future<void> _save() async {
    final invalid = ApiConfig.validationError(_url.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() => _busy = true);

    final target = ApiConfig.normalize(_url.text);
    final failure = await ApiClient.ping(target);

    if (!mounted) return;

    // Alamat yang tidak merespons TIDAK langsung ditolak: server bisa saja
    // sedang dimatikan sementara, dan memaksa operator menunggu server hidup
    // hanya untuk mengubah setelan adalah halangan yang tidak perlu. Yang
    // dilakukan adalah meminta konfirmasi sadar.
    if (failure != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ClayTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClayTheme.radius),
          ),
          title: const Text('Server Tidak Merespons'),
          content: Text(
            '$failure\n\nTetap simpan alamat ini?',
            style: const TextStyle(height: 1.5, fontSize: 13),
          ),
          actions: [
            ClayGhostButton(
              label: 'Batal',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ClayGhostButton(
              label: 'Simpan',
              color: ClayTheme.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (proceed != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
    }

    await ApiConfig.save(ref.read(storageProvider), target);
    ref.read(apiBaseUrlProvider.notifier).state = ApiConfig.baseUrl;

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = null;
      _ok = 'Alamat server disimpan.';
    });
    showClaySnack(context, 'Alamat server: $target');
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    await ApiConfig.reset(ref.read(storageProvider));
    ref.read(apiBaseUrlProvider.notifier).state = ApiConfig.baseUrl;

    if (!mounted) return;
    setState(() {
      _busy = false;
      _url.text = ApiConfig.baseUrl;
      _error = null;
      _ok = 'Dikembalikan ke alamat bawaan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Server')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ClayCard(
            title: 'Alamat API',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClayField(
                  controller: _url,
                  hint: 'http://192.168.1.10:8080',
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _test(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Isi alamat server saja, tanpa /v1. Skema http:// boleh '
                  'dikosongkan.',
                  style: const TextStyle(
                    color: ClayTheme.textMuted,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    icon: Icons.error_outline_rounded,
                    color: ClayTheme.danger,
                    background: ClayTheme.dangerSoft,
                    text: _error!,
                  ),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    icon: Icons.check_circle_outline_rounded,
                    color: ClayTheme.success,
                    background: ClayTheme.successSoft,
                    text: _ok!,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClayGhostButton(
                        label: 'Uji Koneksi',
                        icon: Icons.wifi_tethering_rounded,
                        compact: false,
                        onPressed: _busy ? null : _test,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: ClayButton(
                        label: 'Simpan',
                        icon: Icons.save_rounded,
                        compact: true,
                        busy: _busy,
                        onPressed: _busy ? null : _save,
                      ),
                    ),
                  ],
                ),
                if (ApiConfig.isOverridden) ...[
                  const SizedBox(height: 11),
                  ClayGhostButton(
                    label: 'Kembalikan ke Bawaan (${ApiConfig.defaultBaseUrl})',
                    icon: Icons.restart_alt_rounded,
                    compact: false,
                    onPressed: _busy ? null : _reset,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          ClayCard(
            title: 'Panduan Alamat',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Hint(
                  where: 'Debug di browser',
                  value: 'http://127.0.0.1:8080',
                  note: 'API berjalan di mesin yang sama. Samakan bentuknya '
                      'dengan yang ada di address bar — bagi CORS, '
                      '127.0.0.1 dan localhost adalah origin yang berbeda.',
                ),
                _Hint(
                  where: 'Emulator Android',
                  value: 'http://10.0.2.2:8080',
                  note: '10.0.2.2 adalah mesin pengembang dilihat dari '
                      'emulator; 127.0.0.1 di emulator menunjuk ke '
                      'emulatornya sendiri.',
                ),
                _Hint(
                  where: 'Ponsel/tablet fisik',
                  value: 'http://<IP laptop>:8080',
                  note: 'Jalankan ipconfig di laptop, pakai IPv4-nya. '
                      'Perangkat harus di Wi-Fi yang sama, dan port 8080 '
                      'perlu diizinkan Windows Firewall.',
                ),
                _Hint(
                  where: 'Produksi',
                  value: 'https://absensi.disdik.sumutprov.go.id',
                  note: 'Rilis release menolak HTTP tanpa TLS.',
                ),
              ],
            ),
          ),

          if (kIsWeb) ...[
            const SizedBox(height: 16),
            _Banner(
              icon: Icons.info_outline_rounded,
              color: ClayTheme.primary,
              background: ClayTheme.primarySoft,
              text: 'Di browser, alamat ini juga harus tercantum pada '
                  'CORS_ALLOWED_ORIGINS milik API — jika tidak, permintaan '
                  'diblokir browser sebelum sampai ke server.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) => ClaySurface(
        color: background,
        radius: ClayTheme.radiusSmall,
        depth: 0.6,
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.where,
    required this.value,
    required this.note,
  });

  final String where;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              where,
              style: const TextStyle(
                color: ClayTheme.textStrong,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(
              value,
              style: const TextStyle(
                color: ClayTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              note,
              style: const TextStyle(
                color: ClayTheme.textMuted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}
