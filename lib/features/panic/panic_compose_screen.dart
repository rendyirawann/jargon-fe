import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/failure.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../data/jargon_models.dart';
import '../../providers.dart';

/// Formulir laporan Panic Button.
///
/// Dua hal yang sengaja ditonjolkan di layar ini, karena keraguan pelapor
/// adalah hambatan terbesar kanal seperti ini:
///
/// 1. **Jaminan anonimitas dinyatakan berulang**, bukan sekali di bawah.
/// 2. **Pilihan "Hanya untuk Dinas"** tersedia untuk kasus yang terlalu
///    sensitif untuk tampil di beranda — tanpa pilihan itu, pelapor kasus
///    berat akan memilih tidak melapor sama sekali.
class PanicComposeScreen extends ConsumerStatefulWidget {
  const PanicComposeScreen({super.key});

  @override
  ConsumerState<PanicComposeScreen> createState() => _PanicComposeScreenState();
}

class _PanicComposeScreenState extends ConsumerState<PanicComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();

  List<PanicCategory> _categories = const [];
  PanicCategory? _selected;
  final List<XFile> _photos = [];
  String _visibility = 'publik';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref.read(repositoryProvider).panicCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loading = false;
      });
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 4) {
      showClaySnack(context, 'Maksimum 4 foto bukti.');
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      // Dikecilkan di perangkat lebih dulu: mengunggah foto 12 MP lewat
      // jaringan sekolah akan gagal berkali-kali sebelum berhasil.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() => _photos.add(file));
    }
  }

  Future<void> _submit() async {
    if (_selected == null) {
      setState(() => _error = 'Pilih kategori laporan terlebih dahulu.');
      return;
    }
    if (_title.text.trim().length < 10) {
      setState(() => _error = 'Judul minimal 10 karakter agar mudah ditindak.');
      return;
    }
    if (_body.text.trim().length < 20) {
      setState(() => _error = 'Ceritakan kejadiannya minimal 20 karakter.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final media = <String>[];
      for (final photo in _photos) {
        media.add(base64Encode(await photo.readAsBytes()));
      }

      final result = await ref.read(repositoryProvider).createPanicReport(
            categoryId: _selected!.id,
            title: _title.text.trim(),
            body: _body.text.trim(),
            visibility: _visibility,
            mediaBase64: media,
          );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _SentDialog(
          handle: result['anonymous_handle'] as String? ?? 'Anonim',
          message: result['message'] as String? ?? 'Laporan terkirim.',
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal mengirim laporan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // --- Jaminan anonimitas ---
                ClaySurface(
                  color: ClayTheme.primarySoft,
                  depth: 0.7,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_rounded,
                          color: ClayTheme.primary, size: 22),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          'Nama Anda tidak ditampilkan. Laporan muncul dengan '
                          'nama samaran acak, dan pihak sekolah tidak dapat '
                          'melihat siapa pelapornya.',
                          style: TextStyle(
                            color: ClayTheme.primary,
                            fontSize: 12.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // --- Kategori ---
                const _Label('Kategori Laporan'),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: _categories.map((c) {
                    final selected = _selected?.id == c.id;
                    return ClaySurface(
                      radius: ClayTheme.radiusPill,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      color: selected ? ClayTheme.primary : ClayTheme.surface,
                      depth: 0.6,
                      onTap: () => setState(() => _selected = c),
                      child: Text(
                        c.name,
                        style: TextStyle(
                          color: selected ? Colors.white : ClayTheme.textBody,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_selected?.description != null) ...[
                  const SizedBox(height: 11),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      _selected!.description!,
                      style: TextStyle(
                        color: ClayTheme.textMuted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                ClayField(
                  controller: _title,
                  label: 'Judul Laporan',
                  hint: 'Ringkas dalam satu kalimat',
                  maxLength: 150,
                  enabled: !_busy,
                ),

                const SizedBox(height: 18),
                ClayField(
                  controller: _body,
                  label: 'Ceritakan Kejadiannya',
                  hint: 'Kapan, di mana, dan apa yang terjadi. '
                      'Semakin jelas, semakin cepat ditindaklanjuti.',
                  maxLines: 7,
                  maxLength: 5000,
                  enabled: !_busy,
                ),

                const SizedBox(height: 22),

                // --- Foto bukti ---
                const _Label('Foto Bukti (opsional)'),
                Row(
                  children: [
                    ..._photos.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    ClayTheme.radiusSmall),
                                // Berkas lokal, bukan URL — Image.network akan
                                // gagal senyap pada path filesystem.
                                child: Image.file(
                                  File(e.value.path),
                                  width: 74,
                                  height: 74,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 74,
                                    height: 74,
                                    color: ClayTheme.primarySoft,
                                    child: Icon(Icons.image_rounded,
                                        color: ClayTheme.primary),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _photos.removeAt(e.key)),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: ClayTheme.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        size: 13, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (_photos.length < 4)
                      ClaySurface(
                        radius: ClayTheme.radiusSmall,
                        padding: const EdgeInsets.all(24),
                        depth: 0.6,
                        onTap: _busy ? null : _addPhoto,
                        child: Icon(Icons.add_a_photo_outlined,
                            size: 24, color: ClayTheme.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    'Data lokasi pada foto dihapus otomatis sebelum disimpan.',
                    style: TextStyle(
                      color: ClayTheme.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // --- Visibilitas ---
                const _Label('Siapa yang boleh melihat'),
                _VisibilityOption(
                  value: 'publik',
                  group: _visibility,
                  icon: Icons.public_rounded,
                  title: 'Tampil di beranda',
                  subtitle: 'Setelah diperiksa petugas, laporan tampil anonim '
                      'agar orang lain tahu mereka tidak sendirian.',
                  onSelected: (v) => setState(() => _visibility = v),
                ),
                const SizedBox(height: 11),
                _VisibilityOption(
                  value: 'terbatas',
                  group: _visibility,
                  icon: Icons.lock_rounded,
                  title: 'Hanya untuk Dinas Pendidikan',
                  subtitle: 'Tidak pernah tampil di beranda. Pilih ini untuk '
                      'kasus yang sangat sensitif.',
                  onSelected: (v) => setState(() => _visibility = v),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  ClaySurface(
                    color: ClayTheme.dangerSoft,
                    radius: ClayTheme.radiusSmall,
                    depth: 0.5,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: ClayTheme.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 26),
                ClayButton(
                  label: 'Kirim Laporan',
                  icon: Icons.send_rounded,
                  color: ClayTheme.danger,
                  busy: _busy,
                  onPressed: _busy ? null : _submit,
                ),
                const SizedBox(height: 14),
                Text(
                  'Laporan palsu dapat dikenai sanksi. Sampaikan hal yang '
                  'benar-benar Anda alami atau saksikan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ClayTheme.textMuted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 11),
        child: Text(
          text,
          style: TextStyle(
            color: ClayTheme.textBody,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.value,
    required this.group,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelected,
  });

  final String value;
  final String group;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == group;

    return ClaySurface(
      padding: const EdgeInsets.all(15),
      depth: selected ? 1 : 0.55,
      color: selected ? ClayTheme.primarySoft : ClayTheme.surface,
      onTap: () => onSelected(value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: selected ? ClayTheme.primary : ClayTheme.textMuted,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? ClayTheme.primary : ClayTheme.textStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ClayTheme.textMuted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 19,
            color: selected ? ClayTheme.primary : ClayTheme.textMuted,
          ),
        ],
      ),
    );
  }
}

class _SentDialog extends StatelessWidget {
  const _SentDialog({required this.handle, required this.message});

  final String handle;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClaySurface(
        depth: 1.3,
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClaySurface(
              radius: ClayTheme.radiusPill,
              color: ClayTheme.successSoft,
              padding: const EdgeInsets.all(20),
              depth: 0.7,
              child: Icon(Icons.check_rounded,
                  size: 34, color: ClayTheme.success),
            ),
            const SizedBox(height: 20),
            Text(
              'Laporan Terkirim',
              style: TextStyle(
                color: ClayTheme.textStrong,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ClayTheme.textBody,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),

            // Handle diperlihatkan agar pelapor bisa mengenali laporannya
            // sendiri di beranda tanpa harus membuka "Laporan Saya".
            ClaySurface(
              sunken: true,
              radius: ClayTheme.radiusSmall,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Column(
                children: [
                  Text(
                    'Nama samaran Anda pada laporan ini',
                    style: TextStyle(
                      color: ClayTheme.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    handle,
                    style: TextStyle(
                      color: ClayTheme.primary,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ClayButton(
              label: 'Selesai',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
