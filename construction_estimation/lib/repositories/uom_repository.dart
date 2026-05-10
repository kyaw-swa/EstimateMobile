import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/uom.dart';

/// CRUD layer for `construction_uom`.
///
/// Mirrors Odoo `_order = 'name'`.
class UomRepository {
  UomRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const String _table = 'construction_uom';

  Future<Database> get _db async => _helper.database;

  /// Fetch all UoMs. Set [activeOnly] to hide archived rows
  /// (Odoo's default ir.rule on `active`).
  /// [type] filters by [UomType.material] / [UomType.labour]; rows whose
  /// `uom_type == both` are also returned.
  Future<List<UnitOfMeasure>> findAll({
    bool activeOnly = true,
    UomType? type,
    String? search,
  }) async {
    final db = await _db;

    final where = <String>[];
    final args = <Object?>[];

    if (activeOnly) {
      where.add('active = 1');
    }

    if (type != null && type != UomType.both) {
      where.add('uom_type IN (?, ?)');
      args.addAll([type.value, UomType.both.value]);
    }

    if (search != null && search.trim().isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%${search.trim()}%');
    }

    final rows = await db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(UnitOfMeasure.fromMap).toList();
  }

  Future<UnitOfMeasure?> findById(int id) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UnitOfMeasure.fromMap(rows.first);
  }

  /// Returns the saved row's id. For inserts, [uom.id] must be null.
  Future<int> save(UnitOfMeasure uom) async {
    final db = await _db;
    if (uom.id == null) {
      return db.insert(
        _table,
        uom.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    final updated = uom.copyWith(updatedAt: DateTime.now());
    await db.update(
      _table,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [uom.id],
    );
    return uom.id!;
  }

  /// Soft archive (Odoo `active = False`). Use when the UoM is referenced
  /// by other records — preserves FK integrity.
  Future<void> archive(int id) async {
    final db = await _db;
    await db.update(
      _table,
      {
        'active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> unarchive(int id) async {
    final db = await _db;
    await db.update(
      _table,
      {
        'active': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete. Will fail if any FK references this row (RESTRICT).
  /// Prefer [archive] when the UoM has been used.
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Count of FK references across tables that point at `construction_uom`.
  /// Used to decide between hard-delete and archive.
  Future<int> countReferences(int id) async {
    final db = await _db;
    const tables = [
      'construction_material',
      'construction_labour',
      'construction_ac',
      'construction_estimate_line',
    ];
    var total = 0;
    for (final t in tables) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $t WHERE uom_id = ?',
        [id],
      );
      total += (rows.first['c'] as int?) ?? 0;
    }
    return total;
  }
}
