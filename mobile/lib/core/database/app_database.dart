import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Single SQLite database for the whole app (offline-first source of truth).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'field_notes.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // SQLite ignores foreign keys unless this is switched on.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id                TEXT PRIMARY KEY,
        user_id           INTEGER NOT NULL,
        name              TEXT NOT NULL,
        contact_info      TEXT,
        client_updated_at TEXT NOT NULL,
        updated_at        TEXT,
        deleted_at        TEXT,
        sync_status       TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE sites (
        id                TEXT PRIMARY KEY,
        user_id           INTEGER NOT NULL,
        customer_id       TEXT NOT NULL,
        site_name         TEXT NOT NULL,
        address           TEXT,
        client_updated_at TEXT NOT NULL,
        updated_at        TEXT,
        deleted_at        TEXT,
        sync_status       TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE field_notes (
        id                TEXT PRIMARY KEY,
        user_id           INTEGER NOT NULL,
        site_id           TEXT NOT NULL,
        title             TEXT NOT NULL,
        description       TEXT,
        latitude          REAL,
        longitude         REAL,
        noted_at          TEXT NOT NULL,
        status            TEXT NOT NULL DEFAULT 'OPEN',
        photo_path        TEXT,
        local_photo_path  TEXT,
        photo_pending     INTEGER NOT NULL DEFAULT 0,
        client_updated_at TEXT NOT NULL,
        updated_at        TEXT,
        deleted_at        TEXT,
        sync_status       TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (site_id) REFERENCES sites(id)
      )
    ''');

    // Lists, joins and the sync "what is pending" query all use these.
    await db.execute('CREATE INDEX idx_customers_user ON customers(user_id, deleted_at)');
    await db.execute('CREATE INDEX idx_sites_customer ON sites(customer_id)');
    await db.execute('CREATE INDEX idx_sites_user ON sites(user_id, deleted_at)');
    await db.execute('CREATE INDEX idx_notes_site ON field_notes(site_id)');
    await db.execute('CREATE INDEX idx_notes_user ON field_notes(user_id, deleted_at)');
    await db.execute('CREATE INDEX idx_customers_sync ON customers(sync_status)');
    await db.execute('CREATE INDEX idx_sites_sync ON sites(sync_status)');
    await db.execute('CREATE INDEX idx_notes_sync ON field_notes(sync_status)');
  }

  /// Wipes everything (used on logout / account switch).
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('field_notes');
      await txn.delete('sites');
      await txn.delete('customers');
    });
  }
}