import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/project_estimate.dart';

/// 3-level cascade CRUD for `construction_project_estimate`:
/// estimate → lines → material/labour details.
///
/// Save uses `db.transaction` + delete-then-insert for child rows. Reads
/// JOIN to populate display labels (ac.name, material.name, uom.name) so
/// the UI doesn't fan out per-row queries.
class ProjectEstimateRepository {
  ProjectEstimateRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  static const String _table = 'construction_project_estimate';
  static const String _lineTable = 'construction_estimate_line';
  static const String _matTable = 'construction_estimate_line_material';
  static const String _labTable = 'construction_estimate_line_labour';

  Future<Database> get _db async => _helper.database;

  // SELECT helpers — produce the joined columns models expect via fromMap.

  static const String _selectEstimate = '''
    SELECT * FROM construction_project_estimate
  ''';

  static const String _selectLine = '''
    SELECT l.*, a.name AS ac_name, bu.name AS base_uom_name,
           u.name AS uom_name
    FROM construction_estimate_line l
    LEFT JOIN construction_ac a ON a.id = l.ac_id
    LEFT JOIN construction_uom bu ON bu.id = a.base_uom_id
    LEFT JOIN construction_uom u ON u.id = l.uom_id
  ''';

  static const String _selectMatDetail = '''
    SELECT d.*, m.name AS material_name, u.name AS uom_name
    FROM construction_estimate_line_material d
    LEFT JOIN construction_material m ON m.id = d.material_id
    LEFT JOIN construction_uom u ON u.id = m.uom_id
  ''';

  static const String _selectLabDetail = '''
    SELECT d.*, lab.name AS labour_name, u.name AS uom_name
    FROM construction_estimate_line_labour d
    LEFT JOIN construction_labour lab ON lab.id = d.labour_id
    LEFT JOIN construction_uom u ON u.id = lab.uom_id
  ''';

  // ───────────── Read ─────────────

  /// List view — parents only. Totals are computed by [findTotalsByEstimate].
  Future<List<ProjectEstimate>> findAll({
    EstimateState? state,
    String? search,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];

    if (state != null) {
      where.add('state = ?');
      args.add(state.value);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR customer_name LIKE ?)');
      final like = '%${search.trim()}%';
      args.addAll([like, like]);
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
      $_selectEstimate
      $whereSql
      ORDER BY date DESC, name COLLATE NOCASE ASC
      ''',
      args,
    );
    return rows.map((r) => ProjectEstimate.fromMap(r)).toList();
  }

  /// Full load — parent + lines + each line's material/labour details.
  Future<ProjectEstimate?> findById(int id) async {
    final db = await _db;
    final parentRows = await db.rawQuery(
      '$_selectEstimate WHERE id = ? LIMIT 1',
      [id],
    );
    if (parentRows.isEmpty) return null;

    final lineRows = await db.rawQuery(
      '$_selectLine WHERE l.estimate_id = ? ORDER BY l.sequence, l.id',
      [id],
    );

    final lines = <EstimateLine>[];
    for (final lr in lineRows) {
      final lineId = lr['id'] as int;
      final line = EstimateLine.fromMap(lr);
      final matRows = await db.rawQuery(
        '$_selectMatDetail WHERE d.line_id = ? ORDER BY d.sequence, d.id',
        [lineId],
      );
      final labRows = await db.rawQuery(
        '$_selectLabDetail WHERE d.line_id = ? ORDER BY d.sequence, d.id',
        [lineId],
      );
      // Pass parent baseQty so detail.suggestedQty resolves correctly.
      final matDetails = matRows
          .map((r) =>
              EstimateLineMaterial.fromMap(r, parentBaseQty: line.baseQty))
          .toList();
      final labDetails = labRows
          .map((r) =>
              EstimateLineLabour.fromMap(r, parentBaseQty: line.baseQty))
          .toList();
      lines.add(line.copyWith(
        materialDetails: matDetails,
        labourDetails: labDetails,
      ));
    }

    return ProjectEstimate.fromMap(parentRows.first, lines: lines);
  }

  /// Computes totals (material/labour/grand) for each estimate via SQL —
  /// avoids loading every line into Dart for list rendering.
  Future<Map<int, ({double material, double labour, double total, int lines})>>
      findTotalsByEstimate() async {
    final db = await _db;

    // Per-estimate line counts.
    final lineCountRows = await db.rawQuery(
      'SELECT estimate_id, COUNT(*) AS c FROM $_lineTable GROUP BY estimate_id',
    );

    // Per-estimate material amount (sum across all lines + details).
    final matRows = await db.rawQuery('''
      SELECT l.estimate_id AS eid,
             COALESCE(SUM(
               CASE WHEN d.per = 0 THEN d.quantity * d.rate
                    ELSE (d.quantity * d.rate) / d.per END
             ), 0) AS amt
      FROM construction_estimate_line l
      LEFT JOIN construction_estimate_line_material d ON d.line_id = l.id
      GROUP BY l.estimate_id
    ''');

    final labRows = await db.rawQuery('''
      SELECT l.estimate_id AS eid,
             COALESCE(SUM(
               CASE WHEN d.per = 0 THEN d.quantity * d.rate
                    ELSE (d.quantity * d.rate) / d.per END
             ), 0) AS amt
      FROM construction_estimate_line l
      LEFT JOIN construction_estimate_line_labour d ON d.line_id = l.id
      GROUP BY l.estimate_id
    ''');

    final result =
        <int, ({double material, double labour, double total, int lines})>{};

    for (final r in lineCountRows) {
      final eid = r['estimate_id'] as int;
      result[eid] = (
        material: 0,
        labour: 0,
        total: 0,
        lines: r['c'] as int,
      );
    }
    for (final r in matRows) {
      final eid = r['eid'] as int;
      final amt = (r['amt'] as num?)?.toDouble() ?? 0;
      final ex = result[eid] ?? (material: 0, labour: 0, total: 0, lines: 0);
      result[eid] = (
        material: amt,
        labour: ex.labour,
        total: amt + ex.labour,
        lines: ex.lines,
      );
    }
    for (final r in labRows) {
      final eid = r['eid'] as int;
      final amt = (r['amt'] as num?)?.toDouble() ?? 0;
      final ex = result[eid] ?? (material: 0, labour: 0, total: 0, lines: 0);
      result[eid] = (
        material: ex.material,
        labour: amt,
        total: ex.material + amt,
        lines: ex.lines,
      );
    }
    return result;
  }

  // ───────────── Write ─────────────

  /// Save parent + cascade lines + cascade details. Returns parent id.
  ///
  /// Strategy: transactional delete-then-insert for child collections.
  /// On insert path, line ids are not known up-front so details are written
  /// after each line insert.
  Future<int> save(ProjectEstimate estimate) async {
    final db = await _db;
    return db.transaction<int>((txn) async {
      final parentMap = estimate.copyWith(updatedAt: DateTime.now()).toMap();

      final int estimateId;
      if (estimate.id == null) {
        estimateId = await txn.insert(_table, parentMap);
      } else {
        estimateId = estimate.id!;
        await txn.update(
          _table,
          parentMap,
          where: 'id = ?',
          whereArgs: [estimateId],
        );
        // Wipe entire subtree under this estimate. CASCADE will sweep
        // material/labour details in a single pass when lines are deleted.
        await txn.delete(
          _lineTable,
          where: 'estimate_id = ?',
          whereArgs: [estimateId],
        );
      }

      for (final line in estimate.lines) {
        final lineMap = line.copyWith(estimateId: estimateId).toMap();
        // strip id so insert generates a fresh one even on update path.
        lineMap.remove('id');
        final lineId = await txn.insert(_lineTable, lineMap);

        // Sync non-manual quantities to suggestedQty before write.
        for (final d in line.materialDetails) {
          final effective = d.copyWith(
            lineId: lineId,
            parentBaseQty: line.baseQty,
            quantity: d.isManual ? d.quantity : d.suggestedQty,
          );
          final m = effective.toMap()..remove('id');
          await txn.insert(_matTable, m);
        }
        for (final d in line.labourDetails) {
          final effective = d.copyWith(
            lineId: lineId,
            parentBaseQty: line.baseQty,
            quantity: d.isManual ? d.quantity : d.suggestedQty,
          );
          final m = effective.toMap()..remove('id');
          await txn.insert(_labTable, m);
        }
      }
      return estimateId;
    });
  }

  Future<void> setState(int id, EstimateState state) async {
    final db = await _db;
    await db.update(
      _table,
      {
        'state': state.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete — child tables cascade.
  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
