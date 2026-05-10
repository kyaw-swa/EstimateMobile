import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/material.dart';

/// CRUD layer for `construction_material`.
///
/// Reads include the linked UoM name via LEFT JOIN — saves an extra round-trip
/// for list rendering.
class MaterialRepository {
  MaterialRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const String _table = 'construction_material';

  Future<Database> get _db async => _helper.database;

  /// Standard SELECT with UoM name joined.
  static const String _selectWithUom = '''
    SELECT m.*, u.name AS uom_name
    FROM construction_material m
    LEFT JOIN construction_uom u ON u.id = m.uom_id
  ''';

  Future<List<Material>> findAll({
    bool activeOnly = true,
    int? uomId,
    String? search,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (activeOnly) where.add('m.active = 1');
    if (uomId != null) {
      where.add('m.uom_id = ?');
      args.add(uomId);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('m.name LIKE ?');
      args.add('%${search.trim()}%');
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
      '$_selectWithUom $whereSql ORDER BY m.name COLLATE NOCASE ASC',
      args,
    );
    return rows.map(Material.fromMap).toList();
  }

  Future<Material?> findById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_selectWithUom WHERE m.id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return Material.fromMap(rows.first);
  }

  /// Returns the saved row's id. For inserts, [material.id] must be null.
  Future<int> save(Material material) async {
    final db = await _db;
    if (material.id == null) {
      return db.insert(
        _table,
        material.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    final updated = material.copyWith(updatedAt: DateTime.now());
    await db.update(
      _table,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
    return material.id!;
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
  /// Use [archive] when references exist.
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Count of FK references across child tables (AC + estimate lines).
  Future<int> countReferences(int id) async {
    final db = await _db;
    const tables = [
      'construction_ac_material',
      'construction_estimate_line_material',
    ];
    var total = 0;
    for (final t in tables) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $t WHERE material_id = ?',
        [id],
      );
      total += (rows.first['c'] as int?) ?? 0;
    }
    return total;
  }
}
