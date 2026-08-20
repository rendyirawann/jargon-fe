import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/failure.dart';
import '../../data/models.dart';
import '../../providers.dart';
import 'enroll_screen.dart';

/// Pilih siswa yang akan didaftarkan wajahnya.
///
/// Default menampilkan yang BELUM terdaftar: itulah pekerjaan yang tersisa,
/// dan operator seharusnya tidak perlu mencari sendiri di antara ratusan nama.
class EnrollPickerScreen extends ConsumerStatefulWidget {
  const EnrollPickerScreen({super.key});

  @override
  ConsumerState<EnrollPickerScreen> createState() => _EnrollPickerScreenState();
}

class _EnrollPickerScreenState extends ConsumerState<EnrollPickerScreen> {
  List<RosterEntry> _all = const [];
  bool _loading = true;
  bool _onlyPending = true;
  String _query = '';
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
      final roster = await ref.read(repositoryProvider).roster();
      if (!mounted) return;
      setState(() {
        _all = roster;
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

  List<RosterEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((s) {
      if (_onlyPending && s.faceEnrolled) return false;
      if (q.isEmpty) return true;
      return s.fullName.toLowerCase().contains(q) ||
          (s.nis?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final pending = _all.where((s) => !s.faceEnrolled).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Wajah'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                        const SizedBox(height: 14),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Cari nama atau NIS',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$pending dari ${_all.length} siswa belum '
                                  'terdaftar wajahnya',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Switch(
                                value: _onlyPending,
                                onChanged: (v) =>
                                    setState(() => _onlyPending = v),
                              ),
                              const Text(
                                'Hanya belum',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  _onlyPending
                                      ? 'Semua siswa sudah terdaftar wajahnya.'
                                      : 'Tidak ada siswa yang cocok.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final s = items[i];
                                return ListTile(
                                  leading: Icon(
                                    s.faceEnrolled
                                        ? Icons.verified_user
                                        : Icons.person_outline,
                                    color: s.faceEnrolled
                                        ? const Color(0xFF50CD89)
                                        : Colors.grey,
                                  ),
                                  title: Text(
                                    s.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      s.classroomName ?? 'Tanpa kelas',
                                      s.nis ?? '-',
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EnrollScreen(student: s),
                                      ),
                                    );
                                    // Status terdaftar berubah setelah
                                    // pendaftaran; muat ulang agar daftar
                                    // "belum" tetap akurat.
                                    if (mounted) await _load();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
