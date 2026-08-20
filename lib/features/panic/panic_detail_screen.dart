import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/authed_image.dart';
import '../../core/failure.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../data/jargon_models.dart';
import '../../providers.dart';

/// Detail laporan: isi, lini masa penanganan, dan komentar.
///
/// Lini masa adalah bagian terpenting layar ini. Pelapor yang tidak pernah
/// tahu laporannya diapakan akan berhenti melapor — dan kanal pengaduan yang
/// tidak dipakai sama saja dengan tidak ada.
class PanicDetailScreen extends ConsumerStatefulWidget {
  const PanicDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<PanicDetailScreen> createState() => _PanicDetailScreenState();
}

class _PanicDetailScreenState extends ConsumerState<PanicDetailScreen> {
  final _comment = TextEditingController();
  PanicReportDetail? _detail;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail =
          await ref.read(repositoryProvider).panicDetail(widget.reportId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.length < 2) return;

    setState(() => _sending = true);
    try {
      await ref.read(repositoryProvider).addPanicComment(
            reportId: widget.reportId,
            body: text,
          );
      _comment.clear();
      await _load();
    } on ApiFailure catch (e) {
      if (mounted) showClaySnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Laporan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? ClayEmpty(
                  icon: Icons.search_off_rounded,
                  title: 'Laporan tidak tersedia',
                  message: _error ??
                      'Laporan ini tidak ada atau berada di luar cakupan akun Anda.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        children: [
                          if (detail.isPendingModeration)
                            _Notice(
                              icon: Icons.hourglass_top_rounded,
                              color: ClayTheme.warning,
                              background: ClayTheme.warningSoft,
                              text: 'Laporan Anda sedang diperiksa petugas '
                                  'sebelum tampil di beranda. Penanganannya '
                                  'tetap berjalan.',
                            ),

                          _ReportBody(report: detail.report),

                          if (detail.resolution != null) ...[
                            const SizedBox(height: 16),
                            _Notice(
                              icon: Icons.task_alt_rounded,
                              color: ClayTheme.success,
                              background: ClayTheme.successSoft,
                              text: detail.resolution!,
                              title: 'Hasil Penanganan',
                            ),
                          ],

                          const SizedBox(height: 22),
                          const _SectionTitle('Lini Masa Penanganan'),
                          _Timeline(entries: detail.timeline),

                          const SizedBox(height: 22),
                          _SectionTitle(
                            'Komentar (${detail.comments.length})',
                          ),
                          if (detail.comments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Belum ada komentar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ClayTheme.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            )
                          else
                            ...detail.comments.map((c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 11),
                                  child: _CommentCard(comment: c),
                                )),
                        ],
                      ),
                    ),

                    // --- Kotak komentar ---
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      color: ClayTheme.background,
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClayField(
                                controller: _comment,
                                hint: 'Tulis komentar anonim...',
                                enabled: !_sending,
                                maxLength: 2000,
                                onSubmitted: (_) => _sendComment(),
                              ),
                            ),
                            const SizedBox(width: 11),
                            ClaySurface(
                              radius: ClayTheme.radiusPill,
                              color: ClayTheme.primary,
                              padding: const EdgeInsets.all(15),
                              onTap: _sending ? null : _sendComment,
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded,
                                      size: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final PanicReport report;

  @override
  Widget build(BuildContext context) {
    final color = ClayTheme.severityColor(report.severity);

    return ClaySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayBadge(label: report.categoryName, color: ClayTheme.textBody),
              const SizedBox(width: 8),
              ClayBadge(
                label: ClayTheme.severityLabel(report.severity),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.title,
            style: const TextStyle(
              color: ClayTheme.textStrong,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.anonymousHandle} · ${report.schoolLabel}',
            style: const TextStyle(color: ClayTheme.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Text(
            report.body,
            style: const TextStyle(
              color: ClayTheme.textBody,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (report.media.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...report.media.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ClayTheme.radiusSmall),
                    child: AuthedImage(url),
                  ),
                )),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.front_hand_rounded,
                  size: 16, color: ClayTheme.primary),
              const SizedBox(width: 7),
              Text(
                '${report.supportCount} orang menyatakan mengalami hal serupa',
                style: const TextStyle(
                  color: ClayTheme.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<PanicTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Belum ada tindak lanjut yang dicatat.',
          style: TextStyle(color: ClayTheme.textMuted, fontSize: 12.5),
        ),
      );
    }

    return ClaySurface(
      child: Column(
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          final last = i == entries.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: last ? ClayTheme.primary : ClayTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: ClayTheme.textMuted.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: last ? 0 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(e.status),
                          style: const TextStyle(
                            color: ClayTheme.textStrong,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (e.note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.note!,
                            style: const TextStyle(
                              color: ClayTheme.textBody,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          [
                            if (e.actorLabel != null) e.actorLabel!,
                            '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
                          ].join(' · '),
                          style: const TextStyle(
                            color: ClayTheme.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'baru' => 'Laporan Diterima',
        'diverifikasi' => 'Diverifikasi Petugas',
        'ditindaklanjuti' => 'Sedang Ditindaklanjuti',
        'selesai' => 'Selesai Ditangani',
        'ditolak' => 'Laporan Ditolak',
        _ => s,
      };
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final PanicComment comment;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      padding: const EdgeInsets.all(15),
      depth: 0.6,
      // Komentar resmi diberi latar berbeda: pelapor harus bisa membedakan
      // sekilas antara sesama warga dan jawaban pihak berwenang.
      color: comment.isOfficial ? ClayTheme.infoSoft : ClayTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                comment.isOfficial
                    ? Icons.verified_rounded
                    : Icons.person_off_rounded,
                size: 15,
                color:
                    comment.isOfficial ? ClayTheme.info : ClayTheme.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                comment.displayName,
                style: TextStyle(
                  color: comment.isOfficial
                      ? ClayTheme.info
                      : ClayTheme.textStrong,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (comment.officialTitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  '· ${comment.officialTitle}',
                  style: const TextStyle(
                    color: ClayTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
              if (comment.isMine) ...[
                const SizedBox(width: 7),
                const ClayBadge(label: 'Anda', color: ClayTheme.primary),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.body,
            style: const TextStyle(
              color: ClayTheme.textBody,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: ClayTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
    this.title,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) => ClaySurface(
        color: background,
        depth: 0.6,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
