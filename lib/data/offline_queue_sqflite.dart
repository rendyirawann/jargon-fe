import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'offline_queue.dart';

/// Antrean absensi di SQLite — implementasi untuk Android dan iOS.
///
/// Dipilih otomatis lewat conditional import di `offline_queue.dart` ketika
/// `dart:io` tersedia. Penjelasan mengapa ada dua implementasi ada di sana.
Future<OfflineQueue> openOfflineQueue() => SqfliteOfflineQueue.open();

class SqfliteOfflineQueue implements OfflineQueue {
  SqfliteOfflineQueue._(this._db);

  final Database _db;

  static Future<OfflineQueue> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'absensi_queue.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pending_scans (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            payload      TEXT    NOT NULL,
            captured_at  INTEGER NOT NULL,
            attempts     INTEGER NOT NULL DEFAULT 0,
            last_error   TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_pending_captured ON pending_scans (captured_at)',
        );
      },
    );
    return SqfliteOfflineQueue._(db);
  }

  @override
  Future<void> close() => _db.close();

  @override
  Future<void> enqueue(Map<String, dynamic> payload) async {
    await _db.insert('pending_scans', {
      'payload': jsonEncode(payload),
      'captured_at': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
    });

    await _trim();
  }

  @override
  Future<List<PendingScan>> take({int limit = 20}) async {
    final rows = await _db.query(
      'pending_scans',
      orderBy: 'captured_at ASC',
      limit: limit,
    );

    return rows
        .map((r) => PendingScan(
              id: r['id'] as int,
              payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
              capturedAt: DateTime.fromMillisecondsSinceEpoch(
                r['captured_at'] as int,
              ),
              attempts: r['attempts'] as int,
            ))
        .toList();
  }

  @override
  Future<void> remove(int id) async {
    await _db.delete('pending_scans', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> markFailed(int id, String error) async {
    await _db.rawUpdate(
      'UPDATE pending_scans SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error.length > 300 ? error.substring(0, 300) : error, id],
    );
  }

  @override
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM pending_scans');
    return (rows.first['n'] as int?) ?? 0;
  }

  @override
  Future<int> purgeStale() async {
    final cutoff =
        DateTime.now().subtract(OfflineQueue.maxAge).millisecondsSinceEpoch;
    return _db.delete(
      'pending_scans',
      where: 'captured_at < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> _trim() async {
    final total = await count();
    if (total <= OfflineQueue.maxRows) return;

    // Buang yang tertua: absensi lama sudah kehilangan makna sebagai jam
    // kedatangan, sedangkan yang baru masih relevan.
    final excess = total - OfflineQueue.maxRows;
    await _db.rawDelete('''
      DELETE FROM pending_scans WHERE id IN (
        SELECT id FROM pending_scans ORDER BY captured_at ASC LIMIT ?
      )
    ''', [excess]);
  }
}
