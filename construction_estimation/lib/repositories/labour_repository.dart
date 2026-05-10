import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/labour.dart';

/// CRUD layer for `construction_labour`.
///
/// Reads include the linked UoM name via LEFT JOIN.
class LabourRepository {
  LabourRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const String _table = 'construction_labour';

  Future<Database> get _db async => _helper.database;

  static const String _selectWithUom = '''
    SELECT l.*, u.name AS uom_name
    FROM construction_labour l
    LEFT JOIN construction_uom u ON u.id = l.uom_id
  ''';

  Future<List<Labour>> findAll({
    bool activeOnly = true,
    int? uomId,
    String? search,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (activeOnly) where.add('l.active = 1');
    if (uomId != null) {
      where.add('l.uom_id = ?');
      args.add(uomId);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('l.name LIKE ?');
      args.add('%${search.trim()}%');
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
      '$_selectWithUom $whereSql ORDER BY l.name COLLATE NOCASE ASC',
      args,
    );
    return rows.map(Labour.fromMap).toList();
  }

  Future<Labour?> findById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_selectWithUom WHERE l.id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return Labour.fromMap(rows.first);
  }

  Future<int> save(Labour labour) async {
    final db = await _db;
    if (labour.id == null) {
      return db.insert(
        _table,
        labour.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    final updated = labour.copyWith(updatedAt: DateTime.now());
    await db.update(
      _table,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [labour.id],
    );
    return labour.id!;
  }

  Future<void> archive(int id) async {
    final db = await _db;
    await db.update(
      _table,
      {'active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> unarchive(int id) async {
    final db = await _db;
    await db.update(
      _table,
      {'active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete. Will fail if referenced by AC or estimate lines (RESTRICT FK).
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countReferences(int id) async {
    final db = await _db;
    const tables = [
      'construction_ac_labour',
      'construction_estimate_line_labour',
    ];
    var total = 0;
    for (final t in tables) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $t WHERE labour_id = ?',
        [id],
      );
      total += (rows.first['c'] as int?) ?? 0;
    }
    return total;
  }
}
