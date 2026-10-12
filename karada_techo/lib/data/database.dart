import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the on-device SQLite database. Data never leaves the phone.
///
/// To encrypt the file at rest, swap `sqflite` for `sqflite_sqlcipher` and pass
/// a key kept in `flutter_secure_storage` to `openDatabase(password: ...)`.
/// Nothing else in the app needs to change.
class AppDatabase {
  static const _name = 'karada_techo.db';
  static const _version = 1;

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _name),
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries(
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            at INTEGER NOT NULL,
            value REAL,
            sys INTEGER,
            dia INTEGER,
            pulse INTEGER,
            timing TEXT,
            source TEXT NOT NULL,
            note TEXT,
            external_id TEXT
          )''');
        await db.execute('CREATE INDEX idx_entries_type_at ON entries(type, at)');
        await db.execute('CREATE UNIQUE INDEX idx_entries_external ON entries(external_id)');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
  }
}
