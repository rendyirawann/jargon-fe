import 'package:flutter/material.dart';

import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../data/jargon_models.dart';

/// Beranda: satu layar yang menjawab pertanyaan paling sering ditanya
/// pengguna hari itu.
///
/// Bagi siswa dan orang tua: "sudah absen belum?" Bagi guru dan kepala
/// sekolah: "berapa yang hadir hari ini?" Karena itu isi beranda berubah
/// mengikuti akun, bukan menampilkan semua kartu untuk semua orang.
class BerandaTab extends StatelessWidget {
  const BerandaTab({super.key, required this.summary, required this.onRefresh});

  final HomeSummary? summary;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: ClayTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // --- Kartu absensi per siswa yang tertaut ---
          if (s.students.isNotEmpty) ...[
            const _SectionLabel('Absensi Hari Ini'),
            ...s.students.map((student) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _StudentCard(student: student),
                )),
          ],

          // --- Kartu sekolah untuk guru / kepala sekolah ---
          if (s.school != null) ...[
            const _SectionLabel('Sekolah Anda'),
            _SchoolCard(school: s.school!),
            const SizedBox(height: 14),
          ],

          // --- Pintasan tindakan ---
          if (s.panicUpdates > 0 || s.documentActions > 0) ...[
            const _SectionLabel('Perlu Perhatian'),
            if (s.panicUpdates > 0)
              _AlertRow(
                icon: Icons.campaign_rounded,
                color: ClayTheme.info,
                background: ClayTheme.infoSoft,
                title: '${s.panicUpdates} laporan Anda diperbarui',
                subtitle: 'Buka menu Lapor untuk melihat tindak lanjutnya.',
              ),
            if (s.documentActions > 0)
              _AlertRow(
                icon: Icons.folder_open_rounded,
                color: ClayTheme.warning,
                background: ClayTheme.warningSoft,
                title: '${s.documentActions} pengajuan berkas menunggu',
                subtitle: 'Ada berkas yang perlu dilengkapi atau diperiksa.',
              ),
            const SizedBox(height: 6),
          ],

          // --- Menu yang tersedia ---
          const _SectionLabel('Layanan'),
          _MenuGrid(menus: s.availableMenus),

          const SizedBox(height: 20),
          ClaySurface(
            sunken: true,
            radius: ClayTheme.radiusSmall,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: ClayTheme.textMuted),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Layanan lain dari lingkungan Pemerintah Provinsi Sumatera '
                    'Utara akan ditambahkan ke Jargon GO secara bertahap.',
                    style: TextStyle(
                      color: ClayTheme.textMuted,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, top: 14, bottom: 12),
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

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});

  final StudentTodayCard student;

  @override
  Widget build(BuildContext context) {
    final color = ClayTheme.statusColor(student.todayStatus);
    final label = ClayTheme.statusLabel(student.todayStatus);

    return ClaySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClayIcon(
                icon: student.isSelf
                    ? Icons.person_rounded
                    : Icons.escalator_warning_rounded,
                color: color,
                background: ClayTheme.statusSoft(student.todayStatus),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.isSelf ? 'Saya' : student.fullName,
                      style: const TextStyle(
                        color: ClayTheme.textStrong,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        student.classroomName ?? 'Belum ada kelas',
                        student.schoolName,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ClayTheme.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              ClayBadge(
                label: label,
                color: color,
                background: ClayTheme.statusSoft(student.todayStatus),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Jam masuk/pulang ditampilkan besar: inilah satu-satunya angka yang
          // benar-benar dicari orang tua saat membuka aplikasi pagi hari.
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: 'Jam Masuk',
                  value: student.checkInTime ?? '--:--',
                  icon: Icons.login_rounded,
                  highlight: student.checkInTime != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeBox(
                  label: 'Jam Pulang',
                  value: student.checkOutTime ?? '--:--',
                  icon: Icons.logout_rounded,
                  highlight: student.checkOutTime != null,
                ),
              ),
            ],
          ),

          if (student.lateMinutes > 0) ...[
            const SizedBox(height: 12),
            ClayBadge(
              label: 'Terlambat ${student.lateMinutes} menit',
              color: ClayTheme.warning,
              icon: Icons.schedule_rounded,
            ),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(
                value: student.monthPresent,
                label: 'Hadir',
                color: ClayTheme.success,
              ),
              _MiniStat(
                value: student.monthLate,
                label: 'Telat',
                color: ClayTheme.warning,
              ),
              _MiniStat(
                value: student.monthAbsent,
                label: 'Alfa',
                color: ClayTheme.danger,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'rekap bulan berjalan',
              style: TextStyle(color: ClayTheme.textMuted, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.highlight,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      sunken: true,
      radius: ClayTheme.radiusSmall,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: ClayTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: ClayTheme.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: highlight ? ClayTheme.textStrong : ClayTheme.textMuted,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: ClayTheme.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school});

  final SchoolTodayCard school;

  @override
  Widget build(BuildContext context) {
    final rateColor = school.rate >= 90
        ? ClayTheme.success
        : school.rate >= 75
            ? ClayTheme.warning
            : ClayTheme.danger;

    return ClaySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  school.schoolName,
                  style: const TextStyle(
                    color: ClayTheme.textStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${school.rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: rateColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'tingkat kehadiran dari ${school.totalStudents} siswa aktif',
            style: const TextStyle(color: ClayTheme.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (school.rate / 100).clamp(0, 1),
              minHeight: 9,
              color: rateColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(
                value: school.hadir,
                label: 'Hadir',
                color: ClayTheme.success,
              ),
              _MiniStat(
                value: school.terlambat,
                label: 'Terlambat',
                color: ClayTheme.warning,
              ),
              _MiniStat(
                value: school.belumAbsen,
                label: 'Belum Absen',
                color: ClayTheme.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      depth: 0.75,
      child: Row(
        children: [
          ClayIcon(icon: icon, color: color, background: background, size: 19, padding: 11),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ClayTheme.textStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ClayTheme.textMuted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.menus});

  final List<String> menus;

  static const _meta = {
    'absensi': (
      Icons.fact_check_rounded,
      'Absensi',
      'Pantau kehadiran',
      ClayTheme.primary,
      ClayTheme.primarySoft,
    ),
    'panic_button': (
      Icons.campaign_rounded,
      'Panic Button',
      'Lapor anonim',
      ClayTheme.danger,
      ClayTheme.dangerSoft,
    ),
    'pemberkasan': (
      Icons.folder_rounded,
      'Pemberkasan',
      'Unggah berkas',
      ClayTheme.warning,
      ClayTheme.warningSoft,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final available = menus.where(_meta.containsKey).toList();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.28,
      children: available.map((key) {
        final (icon, title, subtitle, color, background) = _meta[key]!;
        return ClaySurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ClayIcon(icon: icon, color: color, background: background),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ClayTheme.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ClayTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
