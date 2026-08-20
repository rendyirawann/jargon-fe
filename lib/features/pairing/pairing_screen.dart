import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/failure.dart';
import '../../providers.dart';

/// Pemasangan (pairing) tablet ke satu sekolah.
///
/// Operator sekolah membuat perangkat di dashboard `/admin` dan menerima kode
/// 8 digit yang berlaku 30 menit. Kode itu dimasukkan di sini, lalu ditukar
/// dengan device token permanen.
///
/// Kode pendek dipilih karena harus bisa dibacakan lewat telepon ke sekolah
/// di daerah; keamanannya dijaga oleh masa berlaku singkat, sekali pakai, dan
/// rate limit di server — bukan oleh panjang kodenya.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'Kode pairing harus 8 digit.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await ref.read(repositoryProvider).pairDevice(code);
      if (!mounted) return;

      // Provider profil dibaca dari storage; segarkan agar layar lain
      // langsung melihat perangkat sudah terpasang.
      ref.read(deviceProfileProvider.notifier).state = result.toProfileJson();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Perangkat ${result.deviceCode} terpasang di ${result.schoolName}.',
          ),
          backgroundColor: const Color(0xFF1B7F4E),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memasangkan perangkat: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pasangkan Perangkat')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.tablet_android, size: 72),
                const SizedBox(height: 24),
                Text(
                  'Masukkan Kode Pairing',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kode 8 digit diperoleh dari dashboard /admin pada menu '
                  'Perangkat Tablet. Kode berlaku 30 menit dan hanya bisa '
                  'dipakai satu kali.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  enabled: !_busy,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10,
                  ),
                  decoration: const InputDecoration(
                    hintText: '00000000',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1416C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFF1416C), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFF1416C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Pasangkan Perangkat'),
                ),
                const SizedBox(height: 28),
                // Alamat server ditampilkan supaya kesalahan konfigurasi build
                // (mis. APK uji dipasang di sekolah) langsung terlihat.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konfigurasi aplikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Server: ${AppConfig.apiBaseUrl}',
                          style: const TextStyle(fontSize: 11)),
                      Text('Model: ${AppConfig.faceModelVersion}',
                          style: const TextStyle(fontSize: 11)),
                      Text('Dimensi embedding: ${AppConfig.embeddingDim}',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
