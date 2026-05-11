import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// Backup / restore for the local SQLite database.
///
/// Three export shapes:
/// - **DB file** — raw `.db` copy. Fastest and includes everything verbatim.
/// - **JSON** — every table dumped to one `.json` document. Human-readable
///   and portable across schema-compatible builds.
/// - **CSV** — one `.csv` per table, zipped-style sharing (multi-file share).
///
/// Restore accepts either a `.db` file or the JSON shape. Both wipe existing
/// data first.
///
/// The "last backup at" timestamp is stored in a sidecar text file under app
/// docs so we can show a 7-day reminder.
class BackupService {
  BackupService({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  /// Schema version baked into JSON exports. Matches `DatabaseHelper._dbVersion`
  /// at the time the export was written; restore refuses higher versions.
  static const int jsonSchemaVersion = 6;

  /// Table list in FK-dependency order (parents first).
  /// Restore inserts in this order; export iterates in this order.
  static const List<String> _tables = [
    'construction_uom',
    'construction_material',
    'construction_labour',
    'construction_ac',
    'construction_ac_material',
    'construction_ac_labour',
    'construction_project_estimate',
    'construction_estimate_line',
    'construction_estimate_line_material',
    'construction_estimate_line_labour',
  ];

  /// File name used for the "last backup at" sidecar.
  static const String _lastBackupFile = 'last_backup_at.txt';

  // ─────────────────────────── Export: DB file ───────────────────────────

  /// Copy the SQLite file to a timestamped path and return it.
  Future<File> exportDatabaseFile() async {
    await _helper.close();
    final src = await _helper.databasePath;
    final dst = await _stagedPath('backup', 'db');
    await File(src).copy(dst);
    // Re-open the connection for the rest of the app.
    await _helper.database;
    await _writeLastBackupAt(DateTime.now());
    return File(dst);
  }

  /// Export DB file + open the system share sheet.
  Future<void> shareDatabaseFile() async {
    final file = await exportDatabaseFile();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/x-sqlite3')],
      text: 'Construction Estimation backup',
    );
  }

  // ─────────────────────────── Export: JSON ──────────────────────────────

  /// Dump every table to a JSON document and return the file.
  Future<File> exportJson() async {
    final db = await _helper.database;
    final payload = <String, Object?>{
      'schema_version': jsonSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': <String, List<Map<String, Object?>>>{
        for (final t in _tables)
          t: await db.query(t, orderBy: 'id ASC'),
      },
    };
    final dst = await _stagedPath('backup', 'json');
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    await File(dst).writeAsString(encoded);
    await _writeLastBackupAt(DateTime.now());
    return File(dst);
  }

  Future<void> shareJson() async {
    final file = await exportJson();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'Construction Estimation backup (JSON)',
    );
  }

  // ─────────────────────────── Export: CSV ───────────────────────────────

  /// Write one CSV per table and return the list of files.
  Future<List<File>> exportCsv() async {
    final db = await _helper.database;
    final files = <File>[];
    final stamp = _timestamp();
    final dir = await _stageDir(stamp);
    const converter = ListToCsvConverter();

    for (final t in _tables) {
      final rows = await db.query(t, orderBy: 'id ASC');
      if (rows.isEmpty) continue;
      final headers = rows.first.keys.toList();
      final data = <List<Object?>>[
        headers,
        for (final r in rows) [for (final k in headers) r[k]],
      ];
      final csv = converter.convert(data);
      final f = File(p.join(dir, '$t.csv'));
      await f.writeAsString(csv);
      files.add(f);
    }
    await _writeLastBackupAt(DateTime.now());
    return files;
  }

  Future<void> shareCsv() async {
    final files = await exportCsv();
    if (files.isEmpty) {
      throw const BackupException('Nothing to export — all tables are empty.');
    }
    await Share.shareXFiles(
      [for (final f in files) XFile(f.path, mimeType: 'text/csv')],
      text: 'Construction Estimation backup (CSV)',
    );
  }

  // ─────────────────────────── Restore ───────────────────────────────────

  /// Auto-detect format from the source path's extension and restore.
  /// Wipes existing data first.
  Future<void> restoreFrom(String sourcePath) async {
    final ext = p.extension(sourcePath).toLowerCase();
    switch (ext) {
      case '.db':
      case '.sqlite':
      case '.sqlite3':
        await _restoreFromDbFile(sourcePath);
      case '.json':
        await _restoreFromJsonFile(sourcePath);
      default:
        throw BackupException(
          'Unsupported file type "$ext". Use .db or .json.',
        );
    }
  }

  /// Replace the live DB file with [sourcePath]'s contents.
  Future<void> _restoreFromDbFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const BackupException('Backup file not found.');
    }
    await _helper.close();
    final dst = await _helper.databasePath;
    await source.copy(dst);
    // Re-open — sqflite will run migrations if the file's user_version is lower.
    await _helper.database;
  }

  /// Wipe + re-insert from a JSON dump.
  Future<void> _restoreFromJsonFile(String sourcePath) async {
    final raw = await File(sourcePath).readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final version = decoded['schema_version'];
    if (version is! int) {
      throw const BackupException('Invalid backup: missing schema_version.');
    }
    if (version > jsonSchemaVersion) {
      throw BackupException(
        'Backup schema_version=$version is newer than app '
        '($jsonSchemaVersion). Update the app first.',
      );
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      throw const BackupException('Invalid backup: missing tables block.');
    }

    // Drop + recreate gives a clean schema with default seed in place; we
    // wipe the seed rows next so the imported data takes their place.
    await _helper.deleteAndRecreate();
    final db = await _helper.database;

    await db.transaction((txn) async {
      // Children first, parents last so FK constraints are satisfied.
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
      for (final t in _tables) {
        final rows = tables[t];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is! Map) continue;
          await txn.insert(
            t,
            row.cast<String, Object?>(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  // ─────────────────────────── Reminder ──────────────────────────────────

  /// Returns the last successful backup time, or null if never backed up.
  Future<DateTime?> lastBackupAt() async {
    final f = File(await _lastBackupPath());
    if (!await f.exists()) return null;
    final raw = (await f.readAsString()).trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// True if no backup has been taken in the last 7 days.
  Future<bool> needsBackupReminder({Duration window = const Duration(days: 7)}) async {
    final last = await lastBackupAt();
    if (last == null) return true;
    return DateTime.now().difference(last) >= window;
  }

  Future<void> _writeLastBackupAt(DateTime when) async {
    final f = File(await _lastBackupPath());
    await f.writeAsString(when.toIso8601String());
  }

  Future<String> _lastBackupPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _lastBackupFile);
  }

  // ─────────────────────────── Helpers ───────────────────────────────────

  /// Build a path under a fresh staging dir, e.g.
  /// `<docs>/backups/2026-05-11_140530/backup.json`.
  Future<String> _stagedPath(String basename, String ext) async {
    final stamp = _timestamp();
    final dir = await _stageDir(stamp);
    return p.join(dir, '${basename}_$stamp.$ext');
  }

  Future<String> _stageDir(String stamp) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups', stamp));
    await dir.create(recursive: true);
    return dir.path;
  }

  String _timestamp() {
    return DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
  }
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}
