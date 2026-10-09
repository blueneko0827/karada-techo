import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/entry.dart';
import '../models/settings.dart';

class Repository {
  Repository(this._db);

  final Database _db;

  Future<List<Entry>> loadEntries() async {
    final rows = await _db.query('entries', orderBy: 'at ASC');
    return rows.map(Entry.fromMap).toList();
  }

  Future<void> insertEntry(Entry e) async {
    await _db.insert('entries', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertEntries(List<Entry> entries) async {
    final batch = _db.batch();
    for (final e in entries) {
      batch.insert('entries', e.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteEntry(String id) async {
    await _db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearEntries() async {
    await _db.delete('entries');
  }

  Future<AppSettings> loadSettings() async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: ['app']);
    if (rows.isEmpty) return AppSettings.initial();
    try {
      final json = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings.initial();
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    await _db.insert(
      'settings',
      {'key': 'app', 'value': jsonEncode(s.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
