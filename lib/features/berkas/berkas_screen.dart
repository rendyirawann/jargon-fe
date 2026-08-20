import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/failure.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../data/jargon_models.dart';
import '../../providers.dart';
import 'berkas_detail_screen.dart';

/// Pemberkasan — daftar pengajuan berkas kepegawaian.
///
/// Tahap ini fokus pada unggah dan verifikasi berkas. Alur usulan kepegawaian
/// yang lebih lengkap menyusul; struktur status dan lini masa sudah disiapkan
/// untuk itu sehingga penambahan tahap tidak menghapus riwayat yang ada.
class BerkasScreen extends ConsumerStatefulWidget {
  const BerkasScreen({super.key});

  @override
  ConsumerState<BerkasScreen> createState() => _BerkasScreenState();
}

class _BerkasScreenState extends ConsumerState<BerkasScreen> {
  List<Submission> _items = const [];
  bool _loading = true;
  String? _error;

  static const _purposes = {
    'kenaikan_pangkat': 'Kenaikan Pangkat',
    'sertifikasi': 'Sertifikasi',
    'tunjangan': 'Tunjangan',
    'mutasi': 'Mutasi',
    'pensiun': 'Pensiun',
    'umum': 'Umum',
  };

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
      final items = await ref.read(repositoryProvider).submissions();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _createSubmission() async {
    final result = await showModalBottomSheet<({String purpose, String title, String? period})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewSubmissionSheet(),
    );
    if (result == null) return;

    try {
      final created = await ref.read(repositoryProvider).createSubmission(
            purpose: result.purpose,
            title: result.title,
            period: result.period,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BerkasDetailScreen(submissionId: created.id),
        ),
      );
      if (mounted) await _load();
    } on ApiFailure catch (e) {
      if (mounted) showClaySnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: ClaySurface(
          radius: ClayTheme.radiusPill,
          color: ClayTheme.primary,
          depth: 1.1,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          onTap: _createSubmission,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Pengajuan Baru',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ClayEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: 'Gagal memuat pengajuan',
                  message: _error,
                  action: ClayButton(
                    label: 'Coba Lagi',
                    icon: Icons.refresh_rounded,
                    expanded: false,
                    onPressed: _load,
                  ),
                )
              : _items.isEmpty
                  ? const ClayEmpty(
                      icon: Icons.folder_open_rounded,
                      title: 'Belum ada pengajuan',
                      message: 'Buat pengajuan untuk mengunggah berkas '
                          'kenaikan pangkat, sertifikasi, atau keperluan lain.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: ClayTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                        itemCount: _items.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: _SubmissionCard(
                            item: _items[i],
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BerkasDetailScreen(
                                    submissionId: _items[i].id,
                                  ),
                                ),
                              );
                              if (mounted) await _load();
                            },
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.item, required this.onTap});

  final Submission item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (item.status) {
      'disetujui' => (ClayTheme.success, ClayTheme.successSoft),
      'ditolak' => (ClayTheme.danger, ClayTheme.dangerSoft),
      'revisi' => (ClayTheme.warning, ClayTheme.warningSoft),
      'diajukan' || 'diperiksa' => (ClayTheme.info, ClayTheme.infoSoft),
      _ => (ClayTheme.textMuted, ClayTheme.background),
    };

    return ClaySurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayIcon(
                icon: Icons.description_rounded,
                color: color,
                background: background,
                size: 19,
                padding: 11,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ClayTheme.textStrong,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        Submission.purposeLabel(item.purpose),
                        if (item.period != null) item.period!,
                      ].join(' · '),
                      style: const TextStyle(
                        color: ClayTheme.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ClayBadge(
                label: item.statusLabel,
                color: color,
                background: background,
              ),
              const Spacer(),
              Text(
                '${item.fileCount} berkas',
                style: const TextStyle(
                  color: ClayTheme.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.rejectedFileCount > 0) ...[
                const SizedBox(width: 9),
                ClayBadge(
                  label: '${item.rejectedFileCount} ditolak',
                  color: ClayTheme.danger,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Formulir pengajuan baru.
class _NewSubmissionSheet extends StatefulWidget {
  const _NewSubmissionSheet();

  @override
  State<_NewSubmissionSheet> createState() => _NewSubmissionSheetState();
}

class _NewSubmissionSheetState extends State<_NewSubmissionSheet> {
  final _title = TextEditingController();
  final _period = TextEditingController();
  String _purpose = 'kenaikan_pangkat';

  @override
  void dispose() {
    _title.dispose();
    _period.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pengajuan Baru',
            style: TextStyle(
              color: ClayTheme.textStrong,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 11),
            child: Text(
              'Keperluan',
              style: TextStyle(
                color: ClayTheme.textBody,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _BerkasScreenState._purposes.entries.map((e) {
              final selected = _purpose == e.key;
              return ClaySurface(
                radius: ClayTheme.radiusPill,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                color: selected ? ClayTheme.primary : ClayTheme.surface,
                depth: 0.6,
                onTap: () => setState(() => _purpose = e.key),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: selected ? Colors.white : ClayTheme.textBody,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          ClayField(
            controller: _title,
            label: 'Judul Pengajuan',
            hint: 'mis. Kenaikan Pangkat IV/a periode April 2027',
            maxLength: 150,
          ),
          const SizedBox(height: 16),
          ClayField(
            controller: _period,
            label: 'Periode (opsional)',
            hint: 'mis. April 2027',
            maxLength: 40,
          ),
          const SizedBox(height: 24),
          ClayButton(
            label: 'Buat Pengajuan',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              if (_title.text.trim().length < 5) {
                showClaySnack(context, 'Judul pengajuan minimal 5 karakter.');
                return;
              }
              Navigator.pop(context, (
                purpose: _purpose,
                title: _title.text.trim(),
                period: _period.text.trim().isEmpty
                    ? null
                    : _period.text.trim(),
              ));
            },
          ),
        ],
      ),
    );
  }
}
