import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/abstract_of_cost.dart';

/// CRUD layer for `construction_ac` and its line tables.
///
/// Save/delete are cascade-aware — line tables are written in the same
/// transaction as the parent. A delete on the parent relies on
/// `ON DELETE CASCADE` for line rows.
class AbstractOfCostRepository {
  AbstractOfCostRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const String _table = 'construction_ac';
  static const String _matLineTable = 'construction_ac_material';
  static const String _labLineTable = 'construction_ac_labour';

  Future<Database> get _db async => _helper.database;

  /// Parent SELECT with base UoM name joined for list display.
  static const String _selectParent = '''
    SELECT a.*, u.name AS base_uom_name
    FROM construction_ac a
    LEFT JOIN construction_uom u ON u.id = a.base_uom_id
  ''';

  /// Material line SELECT with material + UoM names joined.
  static const String _selectMatLine = '''
    SELECT l.*, m.name AS material_name, u.name AS uom_name
    FROM construction_ac_material l
    LEFT JOIN construction_material m ON m.id = l.material_id
    LEFT JOIN construction_uom u ON u.id = m.uom_id
  ''';

  /// Labour line SELECT with labour + UoM names joined.
  static const String _selectLabLine = '''
    SELECT l.*, lab.name AS labour_name, u.name AS uom_name
    FROM construction_ac_labour l
    LEFT JOIN construction_labour lab ON lab.id = l.labour_id
    LEFT JOIN construction_uom u ON u.id = lab.uom_id
  ''';

  // ───────────── Read ─────────────

  /// List view — parent rows only, no lines (lazy-load when needed).
  Future<List<AbstractOfCost>> findAll({
    bool activeOnly = true,
    String? search,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (activeOnly) where.add('a.active = 1');
    if (search != null && search.trim().isNotEmpty) {
      where.add('a.name LIKE ?');
      args.add('%${search.trim()}%');
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
      '$_selectParent $whereSql ORDER BY a.name COLLATE NOCASE ASC',
      args,
    );
    return rows.map((r) => AbstractOfCost.fromMap(r)).toList();
  }

  /// Full load — parent + both line collections, ordered by sequence.
  Future<AbstractOfCost?> findById(int id) async {
    final db = await _db;
    final parentRows = await db.rawQuery(
      '$_selectParent WHERE a.id = ? LIMIT 1',
      [id],
    );
    if (parentRows.isEmpty) return null;

    final matRows = await db.rawQuery(
      '$_selectMatLine WHERE l.ac_id = ? ORDER BY l.sequence, l.id',
      [id],
    );
    final labRows = await db.rawQuery(
      '$_selectLabLine WHERE l.ac_id = ? ORDER BY l.sequence, l.id',
      [id],
    );

    return AbstractOfCost.fromMap(
      parentRows.first,
      materialLines: matRows.map(AcMaterialLine.fromMap).toList(),
      labourLines: labRows.map(AcLabourLine.fromMap).toList(),
    );
  }

  /// Counts (material/labour line totals) keyed by ac id — used by list view
  /// to show "5 materials, 3 labour" badges without loading every row.
  Future<Map<int, ({int materials, int labour})>> countLinesByAc() async {
    final db = await _db;
    final matRows = await db.rawQuery(
      'SELECT ac_id, COUNT(*) AS c FROM $_matLineTable GROUP BY ac_id',
    );
    final labRows = await db.rawQuery(
      'SELECT ac_id, COUNT(*) AS c FROM $_labLineTable GROUP BY ac_id',
    );

    final result = <int, ({int materials, int labour})>{};
    for (final r in matRows) {
      final acId = r['ac_id'] as int;
      result[acId] = (materials: r['c'] as int, labour: 0);
    }
    for (final r in labRows) {
      final acId = r['ac_id'] as int;
      final existing = result[acId];
      result[acId] = (
        materials: existing?.materials ?? 0,
        labour: r['c'] as int,
      );
    }
    return result;
  }

  // ───────────── Write ─────────────

  /// Save parent + cascade lines. Returns saved parent id.
  ///
  /// Strategy: open a transaction; insert/update parent; replace ALL lines
  /// (delete-then-insert). Simple and safe — line ids are not preserved
  /// across saves, but UI doesn't depend on them.
  Future<int> save(AbstractOfCost ac) async {
    final db = await _db;
    return db.transaction<int>((txn) async {
      final parentMap = ac
          .copyWith(updatedAt: DateTime.now())
          .toMap();

      final int acId;
      if (ac.id == null) {
        acId = await txn.insert(_table, parentMap);
      } else {
        acId = ac.id!;
        await txn.update(
          _table,
          parentMap,
          where: 'id = ?',
          whereArgs: [acId],
        );
        // Wipe existing lines — we'll re-insert from the model.
        await txn.delete(_matLineTable, where: 'ac_id = ?', whereArgs: [acId]);
        await txn.delete(_labLineTable, where: 'ac_id = ?', whereArgs: [acId]);
      }

      for (final line in ac.materialLines) {
        await txn.insert(
          _matLineTable,
          line.copyWith(acId: acId).toMap(),
        );
      }
      for (final line in ac.labourLines) {
        await txn.insert(
          _labLineTable,
          line.copyWith(acId: acId).toMap(),
        );
      }
      return acId;
    });
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

  /// Hard delete. Lines cascade automatically. Will fail if referenced by
  /// estimate lines (FK SET NULL on estimate_line.ac_id, but those still
  /// hold the reference until updated).
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Count of estimate lines that reference this AC. Used to decide
  /// between hard-delete and archive.
  Future<int> countReferences(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM construction_estimate_line WHERE ac_id = ?',
      [id],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
