import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/failure.dart';
import '../../core/theme/clay_theme.dart';
import '../../core/theme/clay_widgets.dart';
import '../../data/models.dart';
import '../../providers.dart';

/// Menu Absensi — **monitoring saja**.
///
/// Pencatatan absensi terjadi di tablet sekolah lewat pengenalan wajah; di
/// aplikasi tidak ada tombol "absen". Ini disengaja: bila siswa bisa menekan
/// absen dari ponselnya, seluruh sistem pengenalan wajah kehilangan artinya.
///
/// Yang dilihat pengguna berbeda menurut akunnya, dan pembatasannya
/// ditegakkan server:
///   * siswa      -> hanya dirinya sendiri
///   * orang tua  -> hanya anak-anaknya
///   * guru/staff -> siswa di sekolahnya
class AbsensiScreen extends ConsumerStatefulWidget {
  const AbsensiScreen({super.key});

  @override
  ConsumerState<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends ConsumerState<AbsensiScreen> {
  List<AttendanceRow> _rows = const [];
  Map<String, dynamic>? _recap;
  bool _loading = true;
  String? _error;
  String? _selectedStudentId;
  int _rangeDays = 30;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    // Orang tua dengan beberapa anak: pilih anak pertama sebagai tampilan awal
    // agar layar tidak menyajikan campuran data yang membingungkan.
    if ((user?.students.length ?? 0) > 1) {
      _selectedStudentId = user!.students.first.id;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final from = DateTime.now().subtract(Duration(days: _rangeDays - 1));

      final rows = await repo.myAttendance(
        studentId: _selectedStudentId,
        from: from,
      );

      Map<String, dynamic>? recap;
      final targetId = _selectedStudentId ??
          ref.read(currentUserProvider)?.students.firstOrNull?.id;
      if (targetId != null) {
        recap = await repo.myRecap(studentId: targetId, from: from);
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _recap = recap;
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final students = user?.students ?? const [];

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ClayEmpty(
        icon: Icons.cloud_off_rounded,
        title: 'Gagal memuat absensi',
        message: _error,
        action: ClayButton(
          label: 'Coba Lagi',
          icon: Icons.refresh_rounded,
          expanded: false,
          onPressed: _load,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: ClayTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // --- Pemilih anak (orang tua dengan >1 anak) ---
          if (students.length > 1) ...[
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: students.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final s = students[i];
                  final selected = s.id == _selectedStudentId;
                  return ClaySurface(
                    radius: ClayTheme.radiusPill,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    color: selected ? ClayTheme.primary : ClayTheme.surface,
                    depth: 0.7,
                    onTap: () {
                      setState(() => _selectedStudentId = s.id);
                      _load();
                    },
                    child: Text(
                      s.fullName.split(' ').first,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : ClayTheme.textBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // --- Rentang waktu ---
          Row(
            children: [7, 30, 90].map((days) {
              final selected = _rangeDays == days;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClaySurface(
                  radius: ClayTheme.radiusPill,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  color: selected ? ClayTheme.primarySoft : ClayTheme.surface,
                  depth: 0.6,
                  onTap: () {
                    setState(() => _rangeDays = days);
                    _load();
                  },
                  child: Text(
                    '$days hari',
                    style: TextStyle(
                      color:
                          selected ? ClayTheme.primary : ClayTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // --- Rekap ---
          if (_recap != null) _RecapCard(recap: _recap!),

          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 12),
            child: Text(
              'RIWAYAT',
              style: TextStyle(
                color: ClayTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),

          if (_rows.isEmpty)
            const ClayEmpty(
              icon: Icons.event_busy_rounded,
              title: 'Belum ada data absensi',
              message: 'Data akan muncul setelah absensi tercatat di sekolah.',
            )
          else
            ..._rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _AttendanceRowCard(
                    row: row,
                    showName: students.length != 1,
                  ),
                )),
        ],
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.recap});

  final Map<String, dynamic> recap;

  @override
  Widget build(BuildContext context) {
    final persen = (recap['persentase_kehadiran'] as num?)?.toDouble() ?? 0;
    final color = persen >= 90
        ? ClayTheme.success
        : persen >= 75
            ? ClayTheme.warning
            : ClayTheme.danger;

    int v(String k) => (recap[k] as num?)?.toInt() ?? 0;

    return ClaySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Persentase Kehadiran',
                      style: TextStyle(
                        color: ClayTheme.textBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'dari ${v('hari_tercatat')} hari tercatat',
                      style: const TextStyle(
                        color: ClayTheme.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${persen.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip('Hadir', v('hadir'), ClayTheme.success),
              _Chip('Terlambat', v('terlambat'), ClayTheme.warning),
              _Chip('Izin', v('izin'), ClayTheme.info),
              _Chip('Sakit', v('sakit'), ClayTheme.secondary),
              _Chip('Alfa', v('alfa'), ClayTheme.danger),
            ],
          ),
          if (v('total_menit_terlambat') > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Total keterlambatan ${v('total_menit_terlambat')} menit '
              'pada periode ini.',
              style: const TextStyle(
                color: ClayTheme.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(ClayTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _AttendanceRowCard extends StatelessWidget {
  const _AttendanceRowCard({required this.row, required this.showName});

  final AttendanceRow row;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final color = ClayTheme.statusColor(row.status);

    return ClaySurface(
      padding: const EdgeInsets.all(15),
      depth: 0.7,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showName ? row.studentName : row.statusLabel,
                  style: const TextStyle(
                    color: ClayTheme.textStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (row.checkIn != null) 'masuk ${row.checkIn}',
                    if (row.checkOut != null) 'pulang ${row.checkOut}',
                    if (row.lateMinutes > 0) 'telat ${row.lateMinutes}m',
                    if (row.checkIn == null && row.checkOut == null)
                      'tidak ada pemindaian',
                  ].join(' · '),
                  style: const TextStyle(
                    color: ClayTheme.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          ClayBadge(
            label: showName ? row.statusLabel : ClayTheme.statusLabel(row.status),
            color: color,
            background: ClayTheme.statusSoft(row.status),
          ),
        ],
      ),
    );
  }
}
