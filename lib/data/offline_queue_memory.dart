import 'offline_queue.dart';

/// Antrean absensi dalam memori — implementasi untuk web (debug di browser).
///
/// `sqflite` tidak berjalan di web. Alih-alih membuat aplikasi gagal dijalankan
/// di browser, antreannya disimpan di memori dan hilang ketika halaman dimuat
/// ulang.
///
/// Itu bukan penurunan mutu yang berarti, karena absensi wajah memang tidak
/// pernah dijalankan dari browser: mode kios membutuhkan kamera, TFLite, dan
/// ML Kit yang hanya ada di perangkat. Debug web dipakai untuk menu Jargon GO,
/// yang tidak menyentuh antrean ini sama sekali.
///
/// Yang TIDAK dilakukan di sini: menyimpan ke `localStorage`. Isi antrean
/// adalah vektor biometrik, dan menaruhnya di penyimpanan browser yang bisa
/// dibaca skrip mana pun di origin yang sama adalah pertukaran yang buruk demi
/// kenyamanan debug.
Future<OfflineQueue> openOfflineQueue() async => MemoryOfflineQueue();

class MemoryOfflineQueue implements OfflineQueue {
  final List<_Row> _rows = [];
  int _nextId = 1;

  @override
  Future<void> close() async => _rows.clear();

  @override
  Future<void> enqueue(Map<String, dynamic> payload) async {
    _rows.add(_Row(
      id: _nextId++,
      payload: payload,
      capturedAt: DateTime.now(),
    ));

    if (_rows.length > OfflineQueue.maxRows) {
      _rows.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
      _rows.removeRange(0, _rows.length - OfflineQueue.maxRows);
    }
  }

  @override
  Future<List<PendingScan>> take({int limit = 20}) async {
    final sorted = [..._rows]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    return sorted
        .take(limit)
        .map((r) => PendingScan(
              id: r.id,
              payload: r.payload,
              capturedAt: r.capturedAt,
              attempts: r.attempts,
            ))
        .toList();
  }

  @override
  Future<void> remove(int id) async {
    _rows.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> markFailed(int id, String error) async {
    for (final row in _rows) {
      if (row.id == id) row.attempts++;
    }
  }

  @override
  Future<int> count() async => _rows.length;

  @override
  Future<int> purgeStale() async {
    final cutoff = DateTime.now().subtract(OfflineQueue.maxAge);
    final before = _rows.length;
    _rows.removeWhere((r) => r.capturedAt.isBefore(cutoff));
    return before - _rows.length;
  }
}

class _Row {
  _Row({
    required this.id,
    required this.payload,
    required this.capturedAt,
  });

  final int id;
  final Map<String, dynamic> payload;
  final DateTime capturedAt;
  int attempts = 0;
}
