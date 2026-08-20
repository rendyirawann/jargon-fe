import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/authed_image.dart';
import '../../core/failure.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../data/jargon_models.dart';
import '../../providers.dart';
import 'panic_compose_screen.dart';
import 'panic_detail_screen.dart';

/// Panic Button — beranda pengaduan bergaya media sosial.
///
/// Feed bersifat **lintas provinsi dengan nama sekolah disamarkan** oleh
/// server. Ini keputusan yang disengaja: feed per sekolah terasa lebih alami,
/// tetapi pada sekolah kecil satu laporan yang muncul di layar seluruh sekolah
/// akan langsung memicu pencarian siapa penulisnya. Dengan penyamaran, siswa
/// tetap melihat bahwa ia tidak sendirian tanpa menyerahkan daftar keluhan
/// kepada sekolah yang dilaporkan.
class PanicFeedScreen extends ConsumerStatefulWidget {
  const PanicFeedScreen({super.key});

  @override
  ConsumerState<PanicFeedScreen> createState() => _PanicFeedScreenState();
}

class _PanicFeedScreenState extends ConsumerState<PanicFeedScreen> {
  List<PanicReport> _reports = const [];
  bool _loading = true;
  bool _mineOnly = false;
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
      final reports = await ref
          .read(repositoryProvider)
          .panicFeed(mineOnly: _mineOnly);
      if (!mounted) return;
      setState(() {
        _reports = reports;
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

  Future<void> _openCompose() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PanicComposeScreen()),
    );
    if (created == true) {
      setState(() => _mineOnly = true);
      await _load();
    }
  }

  Future<void> _toggleSupport(PanicReport report) async {
    try {
      await ref.read(repositoryProvider).togglePanicSupport(report.id);
      await _load();
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
          color: ClayTheme.danger,
          depth: 1.1,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          onTap: _openCompose,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
              SizedBox(width: 9),
              Text(
                'Buat Laporan',
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
      body: Column(
        children: [
          // --- Penjelasan anonimitas, selalu terlihat ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ClaySurface(
              color: ClayTheme.primarySoft,
              radius: ClayTheme.radiusSmall,
              depth: 0.6,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded,
                      size: 19, color: ClayTheme.primary),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Laporan Anda tampil anonim. Identitas pelapor tidak '
                      'pernah ditampilkan kepada pihak sekolah.',
                      style: TextStyle(
                        color: ClayTheme.primary,
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Saringan ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                _FilterPill(
                  label: 'Semua Laporan',
                  selected: !_mineOnly,
                  onTap: () {
                    setState(() => _mineOnly = false);
                    _load();
                  },
                ),
                const SizedBox(width: 10),
                _FilterPill(
                  label: 'Laporan Saya',
                  selected: _mineOnly,
                  onTap: () {
                    setState(() => _mineOnly = true);
                    _load();
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ClayEmpty(
                        icon: Icons.cloud_off_rounded,
                        title: 'Gagal memuat laporan',
                        message: _error,
                        action: ClayButton(
                          label: 'Coba Lagi',
                          icon: Icons.refresh_rounded,
                          expanded: false,
                          onPressed: _load,
                        ),
                      )
                    : _reports.isEmpty
                        ? ClayEmpty(
                            icon: _mineOnly
                                ? Icons.drafts_outlined
                                : Icons.forum_outlined,
                            title: _mineOnly
                                ? 'Anda belum membuat laporan'
                                : 'Belum ada laporan',
                            message: _mineOnly
                                ? 'Laporan yang Anda kirim akan muncul di sini '
                                    'beserta perkembangan penanganannya.'
                                : 'Laporan yang sudah diperiksa petugas akan '
                                    'tampil di sini.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: ClayTheme.primary,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 110),
                              itemCount: _reports.length,
                              itemBuilder: (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: PanicReportCard(
                                  report: _reports[i],
                                  onSupport: () => _toggleSupport(_reports[i]),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PanicDetailScreen(
                                          reportId: _reports[i].id,
                                        ),
                                      ),
                                    );
                                    if (mounted) await _load();
                                  },
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClaySurface(
        radius: ClayTheme.radiusPill,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        color: selected ? ClayTheme.primary : ClayTheme.surface,
        depth: 0.6,
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : ClayTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Kartu laporan di feed.
class PanicReportCard extends StatelessWidget {
  const PanicReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.onSupport,
  });

  final PanicReport report;
  final VoidCallback onTap;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    final severityColor = ClayTheme.severityColor(report.severity);

    return ClaySurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Kepala: handle anonim + kategori ---
          Row(
            children: [
              ClaySurface(
                radius: ClayTheme.radiusPill,
                padding: const EdgeInsets.all(9),
                depth: 0.5,
                color: severityColor.withValues(alpha: 0.13),
                child: Icon(
                  Icons.person_off_rounded,
                  size: 17,
                  color: severityColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          report.anonymousHandle,
                          style: const TextStyle(
                            color: ClayTheme.textStrong,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (report.isMine) ...[
                          const SizedBox(width: 7),
                          const ClayBadge(
                            label: 'Anda',
                            color: ClayTheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.schoolLabel} · ${_relativeTime(report.createdAt)}',
                      style: const TextStyle(
                        color: ClayTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (report.severity == 'darurat' || report.severity == 'tinggi')
                ClayBadge(
                  label: ClayTheme.severityLabel(report.severity),
                  color: severityColor,
                  icon: Icons.priority_high_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            report.title,
            style: const TextStyle(
              color: ClayTheme.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            report.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ClayTheme.textBody,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          if (report.media.isNotEmpty) ...[
            const SizedBox(height: 13),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: report.media.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(ClayTheme.radiusSmall),
                  child: AuthedImage(
                    report.media[i],
                    width: 92,
                    height: 92,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              ClayBadge(
                label: report.categoryName,
                color: ClayTheme.textBody,
                background: ClayTheme.background,
              ),
              const SizedBox(width: 8),
              ClayBadge(
                label: report.statusLabel,
                color: report.isResolved
                    ? ClayTheme.success
                    : report.isHandled
                        ? ClayTheme.info
                        : ClayTheme.textMuted,
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),

          Row(
            children: [
              // "Saya juga mengalami" — bukan "suka". Pada konteks pengaduan,
              // jumlah orang yang mengalami hal sama adalah sinyal prioritas
              // penanganan yang paling berguna.
              Expanded(
                child: _ActionButton(
                  icon: report.isSupported
                      ? Icons.front_hand_rounded
                      : Icons.front_hand_outlined,
                  label: report.supportCount > 0
                      ? '${report.supportCount} juga mengalami'
                      : 'Saya juga mengalami',
                  color: report.isSupported
                      ? ClayTheme.primary
                      : ClayTheme.textMuted,
                  onTap: onSupport,
                ),
              ),
              Expanded(
                child: _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: report.commentCount > 0
                      ? '${report.commentCount} komentar'
                      : 'Komentar',
                  color: ClayTheme.textMuted,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    if (d.inDays < 7) return '${d.inDays} hari lalu';
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClayTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
